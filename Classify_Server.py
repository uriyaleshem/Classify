import socket
import threading
import json
import os
import re
import base64
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional
from tcp_by_size import send_with_size, recv_by_size
from DH import DH_server
from AES_e import encrypt_message, decrypt_message
import db
from AI_Grader import run_ai_grading_worker


HOST = "0.0.0.0"
PORT = 5555
STORAGE_ROOT = Path(__file__).resolve().parent / "server_storage"
MAX_FILE_SIZE = 25 * 1024 * 1024  # 25MB
LOG_FILE = Path(__file__).resolve().parent / "server_data/server_log.txt"

PUBLIC_PATH_PREFIX = "storage://"


def resolve_storage_path(file_ref: str) -> Optional[Path]:
    file_ref = str(file_ref or "").strip()
    if not file_ref:
        return None

    storage_root = STORAGE_ROOT.resolve()

    if file_ref.startswith(PUBLIC_PATH_PREFIX):
        relative_value = file_ref[len(PUBLIC_PATH_PREFIX):].strip().lstrip("/\\")
        target = (storage_root / relative_value).resolve()
    else:
        target = Path(file_ref).expanduser()
        if not target.is_absolute():
            target = (storage_root / file_ref.lstrip("/\\")).resolve()
        else:
            target = target.resolve()

    if target != storage_root and storage_root not in target.parents:
        return None
    return target


def to_public_file_ref(file_path: str) -> str:
    path_text = str(file_path or "").strip()
    if not path_text:
        return ""

    resolved = resolve_storage_path(path_text)
    if resolved is None:
        return ""

    try:
        relative_value = resolved.relative_to(STORAGE_ROOT.resolve()).as_posix()
    except Exception:
        return ""

    return PUBLIC_PATH_PREFIX + relative_value


def normalize_public_file_refs(value):
    if isinstance(value, list):
        return [normalize_public_file_refs(item) for item in value]
    if isinstance(value, dict):
        fixed = {}
        for key, item in value.items():
            if key in {"attachment_path", "file_path", "submissionPath", "attachmentPath", "filePath", "submission_path"}:
                fixed[key] = to_public_file_ref(item)
            else:
                fixed[key] = normalize_public_file_refs(item)
        return fixed
    return value


# -----------------------------
# Helpers: validate + responses
# -----------------------------

def log_action(req_type, req_data, resp_data, client_ip="UNKNOWN", user_id=None, user_name=None):
    try:
        timestamp = datetime.now().strftime("%d/%m/%Y %H:%M:%S")

        log_entry = (
            f"\n{'='*60}\n"
            f"TIME: {timestamp}\n"
            f"IP: {client_ip}\n"
            f"USER_ID: {user_id}\n"
            f"USER_NAME: {user_name}\n"
            f"ACTION: {req_type}\n"
            f"REQUEST:\n{json.dumps(req_data, indent=2, ensure_ascii=False)}\n"
            f"RESPONSE:\n{json.dumps(resp_data, indent=2, ensure_ascii=False)}\n"
        )

        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(log_entry)

    except Exception as e:
        print("[LOG ERROR]", e)


def ok(**kwargs):
    resp = {"status": "OK"}
    resp.update(kwargs)
    return resp


def err(message: str, **kwargs):
    resp = {"status": "ERROR", "message": message}
    resp.update(kwargs)
    return resp


def require_fields(req: dict, fields: list[str]):
    missing = [f for f in fields if f not in req]
    if missing:
        return False, err("MISSING_FIELDS", missing=missing)
    return True, None


def sanitize_filename(filename: str) -> str:
    if not filename:
        return "file.bin"
    clean = os.path.basename(filename)
    clean = re.sub(r"[^A-Za-z0-9._ -]", "_", clean)
    return clean[:180] if clean else "file.bin"


def decode_file_content(file_content_b64: str):
    try:
        file_bytes = base64.b64decode(file_content_b64.encode("utf-8"), validate=True)
        return True, file_bytes
    except Exception:
        return False, b""


def save_base64_file(file_content_b64: str, original_name: str, relative_dir: Path):
    ok_decode, file_bytes = decode_file_content(file_content_b64)
    if not ok_decode:
        return False, "BAD_FILE_CONTENT"

    if len(file_bytes) == 0:
        return False, "EMPTY_FILE"

    if len(file_bytes) > MAX_FILE_SIZE:
        return False, "FILE_TOO_LARGE"

    safe_name = sanitize_filename(original_name)
    target_dir = STORAGE_ROOT / relative_dir
    target_dir.mkdir(parents=True, exist_ok=True)

    target_path = target_dir / safe_name
    stem = target_path.stem
    suffix = target_path.suffix
    counter = 1
    while target_path.exists():
        target_path = target_dir / f"{stem}_{counter}{suffix}"
        counter += 1

    with open(target_path, "wb") as f:
        f.write(file_bytes)

    return True, str(target_path)

def delete_stored_file(file_path: str):
    try:
        if not file_path:
            return True
        target = Path(file_path).resolve()
        storage_root = STORAGE_ROOT.resolve()
        if storage_root not in target.parents and target != storage_root:
            return False
        if target.exists() and target.is_file():
            target.unlink()
        return True
    except Exception:
        return False


def is_safe_storage_path(file_path: str):
    try:
        return resolve_storage_path(file_path) is not None
    except Exception:
        return False


def delete_stored_tree(path_value: str):
    try:
        if not path_value:
            return True
        target = Path(path_value).resolve()
        storage_root = STORAGE_ROOT.resolve()
        if target != storage_root and storage_root not in target.parents:
            return False
        if target.exists() and target.is_dir():
            shutil.rmtree(target, ignore_errors=True)
        return True
    except Exception:
        return False


# -----------------------------
# Authorization helpers
# -----------------------------

UNAUTHENTICATED_REQUESTS = {"LOGIN_REQUEST", "SIGNUP_REQUEST"}


def session_matches_user(session: dict, user_id: int) -> bool:
    return bool(session) and int(session.get("user_id", -1)) == int(user_id)


def build_session_from_login_response(resp: dict) -> dict:
    return {
        "user_id": int(resp.get("user_id", -1)),
        "role": str(resp.get("role", "")).upper(),
        "school_id": int(resp.get("school_id", -1)),
        "name": resp.get("name", ""),
    }


def authorize_request(req: dict, session: dict):
    req_type = req.get("type", "")
    if req_type in UNAUTHENTICATED_REQUESTS:
        return True, None

    if not session or int(session.get("user_id", -1)) < 0:
        return False, err("AUTH_REQUIRED")

    role = str(session.get("role", "")).upper()
    user_id = int(session.get("user_id", -1))
    school_id = int(session.get("school_id", -1))

    if role == "ADMIN":
        return True, None

    def deny(msg="FORBIDDEN"):
        return False, err(msg)

    if req_type == "GET_TEACHER_COURSES_REQUEST":
        return (True, None) if role in {"TEACHER", "ADMIN"} and int(req.get("teacher_id", -999)) == user_id else deny()

    if req_type in {"GET_STUDENT_DASHBOARD_REQUEST", "JOIN_COURSE_BY_CODE_REQUEST", "LEAVE_COURSE_REQUEST", "DELETE_STUDENT_SUBMISSION_REQUEST", "MARK_MESSAGE_READ_REQUEST", "MARK_ALL_MESSAGES_READ_REQUEST", "MARK_GRADE_READ_REQUEST"}:
        if role not in {"STUDENT", "ADMIN"}:
            return deny()
        target_id = int(req.get("student_id", user_id))
        return (True, None) if role == "ADMIN" or target_id == user_id else deny()

    if req_type == "UPLOAD_SUBMISSION_REQUEST":
        if role not in {"STUDENT", "ADMIN"}:
            return deny()
        return (True, None) if role == "ADMIN" or int(req.get("student_id", -1)) == user_id else deny()

    if req_type in {"APPROVE_USER_REQUEST", "BLOCK_USER_REQUEST", "UNBLOCK_USER_REQUEST", "GET_USERS_REQUEST", "GET_SCHOOL_COURSES_REQUEST", "GET_SCHOOL_ASSIGNMENTS_REQUEST", "UPDATE_SCHOOL_REQUEST"}:
        if role not in {"MANAGER", "ADMIN"}:
            return deny()
        target_school = int(req.get("school_id", school_id)) if req_type != "APPROVE_USER_REQUEST" and req_type != "BLOCK_USER_REQUEST" and req_type != "UNBLOCK_USER_REQUEST" else school_id
        if role != "ADMIN" and target_school != school_id:
            return deny()
        if req_type in {"APPROVE_USER_REQUEST", "BLOCK_USER_REQUEST", "UNBLOCK_USER_REQUEST"}:
            ok_user, user_ctx = db.get_user_context(int(req.get("user_id", -1)))
            if not ok_user:
                return False, err(user_ctx)
            if role != "ADMIN" and int(user_ctx.get("school_id", -1)) != school_id:
                return deny()
        return True, None

    if req_type in {"CREATE_COURSE_REQUEST"}:
        if role not in {"TEACHER", "ADMIN"}:
            return deny()
        if role != "ADMIN" and (int(req.get("teacher_id", -1)) != user_id or int(req.get("school_id", -1)) != school_id):
            return deny()
        return True, None

    if req_type in {"GET_COURSE_ASSIGNMENTS_REQUEST", "GET_COURSE_STUDENTS_REQUEST", "GET_COURSE_MATERIALS_REQUEST", "GET_COURSE_MESSAGES_REQUEST"}:
        course_id = int(req.get("course_id", -1))
        if course_id < 0:
            return deny("MISSING_COURSE_ID")
        return (True, None) if db.can_user_access_course(user_id, role, school_id, course_id) else deny()

    if req_type in {"DELETE_COURSE_REQUEST", "CREATE_ASSIGNMENT_REQUEST", "CREATE_MATERIAL_REQUEST", "SAVE_COURSE_MESSAGE_REQUEST", "UPDATE_COURSE_MEMBER_STATUS_REQUEST", "DELETE_COURSE_MEMBER_REQUEST"}:
        if role not in {"TEACHER", "ADMIN"}:
            return deny()
        course_id = int(req.get("course_id", -1))
        if course_id < 0:
            return deny("MISSING_COURSE_ID")
        if not db.can_user_access_course(user_id, role, school_id, course_id):
            return deny()
        if req_type == "CREATE_MATERIAL_REQUEST" and role == "TEACHER" and int(req.get("created_by", user_id) or user_id) != user_id:
            return deny()
        if req_type == "SAVE_COURSE_MESSAGE_REQUEST" and role == "TEACHER" and int(req.get("sender_id", user_id) or user_id) != user_id:
            return deny()
        return True, None

    if req_type in {"SET_ASSIGNMENT_CLOSED_REQUEST", "DELETE_ASSIGNMENT_REQUEST", "GET_SUBMISSIONS_FOR_ASSIGNMENT_REQUEST"}:
        ok_course, course_id = db.get_assignment_course_id(int(req.get("assignment_id", -1)))
        if not ok_course:
            return False, err(course_id)
        return (True, None) if db.can_user_access_course(user_id, role, school_id, course_id) and role in {"TEACHER", "ADMIN"} else deny()

    if req_type == "UPDATE_SUBMISSION_REVIEW_REQUEST":
        ok_course, course_id = db.get_submission_course_id(int(req.get("submission_id", -1)))
        if not ok_course:
            return False, err(course_id)
        if role == "ADMIN":
            return True, None
        if role != "TEACHER" or int(req.get("updated_by", -1)) != user_id:
            return deny()
        return (True, None) if db.can_user_access_course(user_id, role, school_id, course_id) else deny()

    if req_type in {"DELETE_MATERIAL_REQUEST"}:
        ok_course, course_id = db.get_material_course_id(int(req.get("material_id", -1)))
        if not ok_course:
            return False, err(course_id)
        return (True, None) if db.can_user_access_course(user_id, role, school_id, course_id) and role in {"TEACHER", "ADMIN"} else deny()

    if req_type in {"DELETE_MESSAGE_REQUEST"}:
        ok_course, course_id = db.get_message_course_id(int(req.get("message_id", -1)))
        if not ok_course:
            return False, err(course_id)
        return (True, None) if db.can_user_access_course(user_id, role, school_id, course_id) and role in {"TEACHER", "ADMIN"} else deny()

    if req_type == "DOWNLOAD_FILE_REQUEST":
        resolved = resolve_storage_path(req.get("file_path", ""))
        if resolved is None:
            return False, err("INVALID_FILE_PATH")
        allowed = db.can_user_access_file(user_id, role, school_id, str(resolved))
        return (True, None) if allowed else deny()

    return True, None


# -----------------------------
# Handlers (one per request type)
# -----------------------------
def handle_signup(req: dict) -> dict:
    valid, e = require_fields(req, ["name", "email", "password", "role", "school_id"])
    if not valid:
        return e
    # checks
    if len(req["name"].split(" ")) < 2:
        return err("enter FULL name")
    if "@" not in req["email"]:
        return err("enter valid email")

    ok_db, msg = db.signup_user(req["name"], req["email"], req["password"], req["role"], req["school_id"])
    if ok_db:
        return ok(message=msg)
    return err(msg)


def handle_login(req: dict) -> dict:
    valid, e = require_fields(req, ["email", "password"])
    if not valid:
        return e

    ok_db, role, user_id, uname, school_id, school_name, school_address, school_contact_email = db.login_user(req["email"], req["password"])
    if ok_db:
        return ok(role=role, user_id=user_id, name=uname, school_id=school_id, school_name=school_name,
                  school_address=school_address, school_contact_email=school_contact_email)
    return err(role)


def handle_approve(req: dict) -> dict:
    valid, e = require_fields(req, ["user_id"])
    if not valid:
        return e

    ok_db, msg = db.approve_user(req["user_id"])
    if ok_db:
        return ok(message=msg)
    return err(msg)


def handle_block(req: dict) -> dict:
    valid, e = require_fields(req, ["user_id"])
    if not valid:
        return e

    ok_db, msg = db.block_user(req["user_id"])
    if ok_db:
        return ok(message=msg)
    return err(msg)


def handle_unblock(req: dict) -> dict:
    valid, e = require_fields(req, ["user_id"])
    if not valid:
        return e

    ok_db, msg = db.unblock_user(req["user_id"])
    if ok_db:
        return ok(message=msg)
    return err(msg)


def handle_school_update(req: dict) -> dict:
    valid, e = require_fields(req, ["school_id"])
    if not valid:
        return e

    ok_db, msg = db.update_school(
        req["school_id"],
        req.get("name"),
        req.get("address"),
        req.get("contact_name"),
        req.get("contact_email")
    )

    if ok_db:
        return ok(message=msg)

    return err(msg)


def handle_get_users(req: dict) -> dict:
    valid, e = require_fields(req, ["school_id"])
    if not valid:
        return e

    ok_db, result = db.get_school_users(req["school_id"])
    if ok_db:
        return ok(users=result)
    return err(result)


def handle_school_courses(req: dict) -> dict:
    valid, e = require_fields(req, ["school_id"])
    if not valid:
        return e

    ok_db, result = db.get_courses_for_school(req["school_id"])
    if ok_db:
        return ok(courses=result)
    return err(result)


def handle_school_assignments(req: dict) -> dict:
    valid, e = require_fields(req, ["school_id"])
    if not valid:
        return e

    ok_db, result = db.get_assignments_for_school(req["school_id"])
    if ok_db:
        return ok(assignments=result)
    return err(result)


def handle_get_teacher_courses(req: dict) -> dict:
    valid, e = require_fields(req, ["teacher_id"])
    if not valid:
        return e

    ok_db, result = db.get_courses_for_teacher(req["teacher_id"])
    if ok_db:
        return ok(courses=result)
    return err(result)


def handle_create_course(req: dict) -> dict:
    valid, e = require_fields(req, ["name", "description", "teacher_id", "school_id"])
    if not valid:
        return e

    ok_db, result = db.create_course(req["name"], req.get("description", ""), req["teacher_id"], req["school_id"])
    if ok_db:
        return ok(course_id=result)
    return err(result)


def handle_delete_course(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id"])
    if not valid:
        return e

    course_id = int(req["course_id"])
    ok_paths, file_paths = db.get_course_file_paths(course_id)
    if not ok_paths:
        return err(file_paths)

    ok_db, result = db.delete_course(course_id)
    if not ok_db:
        return err(result)

    for file_path in file_paths:
        delete_stored_file(file_path)

    delete_stored_tree(str(STORAGE_ROOT / "assignments" / f"course_{course_id}"))
    delete_stored_tree(str(STORAGE_ROOT / "materials" / f"course_{course_id}"))
    delete_stored_tree(str(STORAGE_ROOT / "submissions" / f"course_{course_id}"))

    return ok(message=result, course_id=course_id)


def handle_get_course_assignments(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id"])
    if not valid:
        return e

    ok_db, result = db.get_assignments_for_course(req["course_id"])
    if ok_db:
        return ok(course_id=req["course_id"], assignments=normalize_public_file_refs(result))
    return err(result)


def handle_create_assignment(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id", "title", "description", "due_date"])
    if not valid:
        return e

    ai_enabled = bool(req.get("ai_enabled", True))
    attachment_path = req.get("attachment_path")
    attachment_name = req.get("attachment_name", "")
    attachment_b64 = req.get("attachment_content_b64", "")

    if attachment_b64:
        ok_file, file_result = save_base64_file(
            attachment_b64,
            attachment_name,
            Path("assignments") / f"course_{int(req['course_id'])}" / "attachments"
        )
        if not ok_file:
            return err(file_result)
        attachment_path = file_result

    if ai_enabled and not attachment_path:
        return err("RUBRIC_ATTACHMENT_REQUIRED")

    ok_db, result = db.create_assignment(
        req["course_id"],
        req["title"],
        req.get("description", ""),
        req.get("due_date", ""),
        attachment_path,
        ai_enabled
    )
    if ok_db:
        return ok(assignment_id=result, course_id=req["course_id"], attachment_path=to_public_file_ref(attachment_path or ""))
    delete_stored_file(attachment_path or "")
    return err(result)


def handle_get_course_students(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id"])
    if not valid:
        return e

    ok_db, result = db.get_students_in_course(req["course_id"])
    if ok_db:
        return ok(course_id=req["course_id"], students=result)
    return err(result)


def handle_get_submissions_for_assignment(req: dict) -> dict:
    valid, e = require_fields(req, ["assignment_id"])
    if not valid:
        return e

    assignment_id = req["assignment_id"]
    ok_db, result = db.get_submissions_for_assignment(assignment_id)
    if not ok_db:
        return err(result)

    enriched = []
    for row in result:
        item = dict(row)
        ok_feedback, feedback = db.get_feedback(row["submission_id"])
        if ok_feedback:
            item["ai_feedback"] = feedback.get("ai_feedback")
            item["teacher_feedback"] = feedback.get("teacher_feedback")
        else:
            item["ai_feedback"] = ""
            item["teacher_feedback"] = ""
        enriched.append(item)

    return ok(assignment_id=assignment_id, submissions=normalize_public_file_refs(enriched))


def handle_update_submission_review(req: dict) -> dict:
    valid, e = require_fields(req, ["submission_id", "final_score", "teacher_feedback", "updated_by"])
    if not valid:
        return e

    submission_id = int(req["submission_id"])
    final_score = float(req["final_score"])
    teacher_feedback = req.get("teacher_feedback", "")
    updated_by = int(req["updated_by"])

    ok_grade, _grade = db.get_grade(submission_id)
    if ok_grade:
        ok_db, msg = db.update_final_grade(submission_id, final_score, updated_by)
    else:
        ok_db, msg = db.save_grade(submission_id, 0, final_score, updated_by)

    if not ok_db:
        return err(msg)

    ok_feedback, feedback_msg = db.save_feedback(submission_id, None, teacher_feedback)
    if not ok_feedback:
        return err(feedback_msg)

    return ok(message="REVIEW_UPDATED", submission_id=submission_id)


def handle_get_course_materials(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id"])
    if not valid:
        return e

    ok_db, result = db.get_materials_for_course(req["course_id"])
    if ok_db:
        return ok(course_id=req["course_id"], materials=normalize_public_file_refs(result))
    return err(result)


def handle_create_material(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id", "title"])
    if not valid:
        return e

    file_path = req.get("file_path")
    file_name = req.get("file_name", "")
    file_b64 = req.get("file_content_b64", "")
    course_id = int(req["course_id"])

    if file_b64:
        ok_file, file_result = save_base64_file(
            file_b64,
            file_name,
            Path("materials") / f"course_{course_id}"
        )
        if not ok_file:
            return err(file_result)
        file_path = file_result

    ok_db, result = db.create_material(
        course_id,
        req["title"],
        req.get("description", ""),
        req.get("material_type", "FILE"),
        req.get("created_by"),
        file_path
    )
    if ok_db:
        return ok(material_id=result, course_id=course_id, file_path=to_public_file_ref(file_path or ""))
    delete_stored_file(file_path or "")
    return err(result)


def handle_save_course_message(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id", "sender_id", "subject", "body", "state"])
    if not valid:
        return e

    ok_db, result = db.create_message(
        req["course_id"],
        req["sender_id"],
        req["subject"],
        req["body"],
        req.get("state", "sent")
    )
    if ok_db:
        return ok(message_id=result, course_id=req["course_id"])
    return err(result)


def handle_get_course_messages(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id"])
    if not valid:
        return e

    ok_db, result = db.get_messages_for_course(req["course_id"])
    if ok_db:
        return ok(course_id=req["course_id"], messages=result)
    return err(result)


def handle_update_course_member_status(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id", "student_id", "member_status"])
    if not valid:
        return e

    member_status = str(req["member_status"]).upper()
    if member_status not in ("ACTIVE", "INACTIVE", "PENDING"):
        return err("INVALID_MEMBER_STATUS")

    ok_db, result = db.update_course_member_status(int(req["course_id"]), int(req["student_id"]), member_status)
    if ok_db:
        return ok(message=result, course_id=int(req["course_id"]), student_id=int(req["student_id"]), member_status=member_status)
    return err(result)


def handle_delete_course_member(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id", "student_id"])
    if not valid:
        return e

    ok_db, result = db.delete_course_member(int(req["course_id"]), int(req["student_id"]))
    if ok_db:
        return ok(message=result, course_id=int(req["course_id"]), student_id=int(req["student_id"]))
    return err(result)


def handle_set_assignment_closed(req: dict) -> dict:
    valid, e = require_fields(req, ["assignment_id", "is_closed"])
    if not valid:
        return e

    assignment_id = int(req["assignment_id"])
    is_closed = bool(req["is_closed"])
    ok_db, result = db.set_assignment_closed(assignment_id, is_closed)
    if ok_db:
        return ok(message=result, assignment_id=assignment_id, is_closed=is_closed)
    return err(result)


def handle_delete_assignment(req: dict) -> dict:
    valid, e = require_fields(req, ["assignment_id"])
    if not valid:
        return e

    assignment_id = int(req["assignment_id"])
    ok_assignment, assignment = db.get_assignment(assignment_id)
    if not ok_assignment:
        return err(assignment)
    course_id = int(assignment["course_id"])

    ok_db, result = db.delete_assignment(assignment_id)
    if not ok_db:
        return err(result)

    delete_stored_file(result.get("attachment_path", ""))
    for file_path in result.get("submission_paths", []):
        delete_stored_file(file_path)
    delete_stored_tree(str(STORAGE_ROOT / "submissions" / f"course_{course_id}" / f"assignment_{assignment_id}"))

    return ok(message="ASSIGNMENT_DELETED", assignment_id=assignment_id, course_id=course_id)


def handle_delete_material(req: dict) -> dict:
    valid, e = require_fields(req, ["material_id"])
    if not valid:
        return e

    material_id = int(req["material_id"])
    ok_db, result = db.delete_material(material_id)
    if not ok_db:
        return err(result)
    delete_stored_file(result.get("file_path", ""))
    return ok(message="MATERIAL_DELETED", material_id=material_id, course_id=int(result.get("course_id", -1)))


def handle_delete_message(req: dict) -> dict:
    valid, e = require_fields(req, ["message_id"])
    if not valid:
        return e

    message_id = int(req["message_id"])
    ok_db, result = db.delete_message(message_id)
    if not ok_db:
        return err(result)
    return ok(message="MESSAGE_DELETED", message_id=message_id, course_id=int(result.get("course_id", -1)))


def handle_download_file(req: dict) -> dict:
    valid, e = require_fields(req, ["file_path"])
    if not valid:
        return e

    path_obj = resolve_storage_path(req.get("file_path", ""))
    if path_obj is None:
        return err("INVALID_FILE_PATH")
    if not path_obj.exists() or not path_obj.is_file():
        return err("FILE_NOT_FOUND")

    file_bytes = path_obj.read_bytes()
    if len(file_bytes) > MAX_FILE_SIZE:
        return err("FILE_TOO_LARGE")

    return ok(file_name=path_obj.name, file_content_b64=base64.b64encode(file_bytes).decode("utf-8"), file_path=to_public_file_ref(str(path_obj)))


def handle_upload_submission(req: dict) -> dict:
    valid, e = require_fields(req, ["assignment_id", "student_id", "file_name", "file_content_b64"])
    if not valid:
        return e

    assignment_id = int(req["assignment_id"])
    student_id = int(req["student_id"])

    ok_assignment, assignment = db.get_assignment(assignment_id)
    if not ok_assignment:
        return err(assignment)

    if bool(assignment.get("is_closed", 0)):
        return err("ASSIGNMENT_CLOSED")

    course_id = int(assignment["course_id"])

    if hasattr(db, "is_student_active_in_course") and not db.is_student_active_in_course(course_id, student_id):
        return err("STUDENT_INACTIVE_IN_CLASS")

    ok_file, file_result = save_base64_file(
        req["file_content_b64"],
        req["file_name"],
        Path("submissions") / f"course_{course_id}" / f"assignment_{assignment_id}" / f"student_{student_id}"
    )
    if not ok_file:
        return err(file_result)

    ai_enabled = bool(assignment.get("ai_enabled", 1))
    submission_status = "PENDING_AI" if ai_enabled else "AI_DONE"

    ok_db, result = db.save_submission(assignment_id, student_id, file_result, submission_status)
    if not ok_db:
        delete_stored_file(file_result)
        return err(result)

    submission_id = int(result.get("submission_id", -1))
    for old_path in result.get("replaced_file_paths", []):
        delete_stored_file(old_path)

    if not ai_enabled:
        ok_grade, grade_msg = db.save_grade(submission_id, 0.0, 0.0, None)
        if not ok_grade:
            db.delete_submission_for_student(assignment_id, student_id)
            delete_stored_file(file_result)
            return err(grade_msg)
        ok_feedback, feedback_msg = db.save_feedback(submission_id, "AI is disabled for this assignment.", None)
        if not ok_feedback:
            db.delete_submission_for_student(assignment_id, student_id)
            delete_stored_file(file_result)
            return err(feedback_msg)

    return ok(submission_id=submission_id, assignment_id=assignment_id, file_path=to_public_file_ref(file_result))


# --- Added: student-home request handlers ---
def handle_get_student_dashboard(req: dict) -> dict:
    valid, e = require_fields(req, ["student_id"])
    if not valid:
        return e

    ok_db, result = db.get_student_dashboard(int(req["student_id"]))
    if ok_db:
        return ok(student_id=int(req["student_id"]), classes=result.get("classes", []), assignments=normalize_public_file_refs(result.get("assignments", [])), materials=normalize_public_file_refs(result.get("materials", [])), messages=result.get("messages", []))
    return err(result)


def handle_join_course_by_code(req: dict) -> dict:
    valid, e = require_fields(req, ["student_id", "class_code"])
    if not valid:
        return e

    ok_db, result = db.join_course_by_code(int(req["student_id"]), req.get("class_code", ""))
    if ok_db:
        return ok(message=result, student_id=int(req["student_id"]), class_code=req.get("class_code", ""))
    return err(result)


def handle_leave_course(req: dict) -> dict:
    valid, e = require_fields(req, ["student_id", "course_id"])
    if not valid:
        return e

    ok_db, result = db.leave_course_for_student(int(req["course_id"]), int(req["student_id"]))
    if ok_db:
        return ok(message=result, student_id=int(req["student_id"]), course_id=int(req["course_id"]))
    return err(result)


def handle_delete_student_submission(req: dict) -> dict:
    valid, e = require_fields(req, ["assignment_id", "student_id"])
    if not valid:
        return e

    ok_db, result = db.delete_submission_for_student(int(req["assignment_id"]), int(req["student_id"]))
    if not ok_db:
        return err(result)

    for file_path in result.get("file_paths", []):
        delete_stored_file(file_path)
    return ok(message="SUBMISSION_DELETED", assignment_id=int(req["assignment_id"]), student_id=int(req["student_id"]), submission_id=int(result.get("submission_id", -1)))


def handle_mark_message_read(req: dict) -> dict:
    valid, e = require_fields(req, ["student_id", "message_id"])
    if not valid:
        return e

    ok_db, result = db.mark_message_read(int(req["student_id"]), int(req["message_id"]))
    if ok_db:
        return ok(message=result, student_id=int(req["student_id"]), message_id=int(req["message_id"]))
    return err(result)


def handle_mark_all_messages_read(req: dict) -> dict:
    valid, e = require_fields(req, ["student_id"])
    if not valid:
        return e

    ok_db, result = db.mark_all_messages_read(int(req["student_id"]))
    if ok_db:
        return ok(message=result, student_id=int(req["student_id"]))
    return err(result)


def handle_mark_grade_read(req: dict) -> dict:
    valid, e = require_fields(req, ["student_id", "submission_id"])
    if not valid:
        return e

    ok_db, result = db.mark_grade_read(int(req["student_id"]), int(req["submission_id"]))
    if ok_db:
        return ok(message=result, student_id=int(req["student_id"]), submission_id=int(req["submission_id"]))
    return err(result)



# -----------------------------
# Admin request handlers
# -----------------------------
def _admin_only(req: dict) -> bool:
    # Real authorization is enforced in authorize_request using the session role.
    return True


def handle_admin_overview(req: dict) -> dict:
    ok_db, result = db.admin_get_overview()
    if ok_db:
        return ok(**result)
    return err(result)


def handle_admin_create_school(req: dict) -> dict:
    valid, e = require_fields(req, ["name"])
    if not valid:
        return e
    ok_db, result = db.create_school(req.get("name", ""), req.get("address", ""), req.get("contact_name", ""), req.get("contact_email", ""))
    if ok_db:
        return ok(message="SCHOOL_CREATED", school_id=int(result))
    return err(result)


def handle_admin_update_school(req: dict) -> dict:
    valid, e = require_fields(req, ["school_id"])
    if not valid:
        return e
    ok_db, result = db.update_school(int(req["school_id"]), req.get("name"), req.get("address"), req.get("contact_name"), req.get("contact_email"))
    if ok_db:
        return ok(message=result)
    return err(result)


def handle_admin_delete_school(req: dict) -> dict:
    valid, e = require_fields(req, ["school_id"])
    if not valid:
        return e
    ok_db, result = db.admin_delete_school(int(req["school_id"]))
    if ok_db:
        return ok(message=result)
    return err(result)


def handle_admin_create_user(req: dict) -> dict:
    valid, e = require_fields(req, ["name", "email", "password", "role", "school_id", "status"])
    if not valid:
        return e
    ok_db, result = db.admin_create_user(req["name"], req["email"], req["password"], req["role"], int(req["school_id"]), req["status"])
    if ok_db:
        return ok(message=result)
    return err(result)


def handle_admin_update_user(req: dict) -> dict:
    valid, e = require_fields(req, ["user_id", "name", "email", "role", "school_id", "status"])
    if not valid:
        return e
    ok_db, result = db.admin_update_user(int(req["user_id"]), req["name"], req["email"], req["role"], int(req["school_id"]), req["status"])
    if ok_db:
        return ok(message=result)
    return err(result)


def handle_admin_delete_user(req: dict) -> dict:
    valid, e = require_fields(req, ["user_id"])
    if not valid:
        return e
    ok_db, result = db.delete_user(int(req["user_id"]))
    if ok_db:
        return ok(message=result)
    return err(result)


def handle_admin_update_course(req: dict) -> dict:
    valid, e = require_fields(req, ["course_id", "name", "description", "teacher_id", "school_id"])
    if not valid:
        return e
    ok_db, result = db.admin_update_course(int(req["course_id"]), req["name"], req.get("description", ""), int(req["teacher_id"]), int(req["school_id"]))
    if ok_db:
        return ok(message=result)
    return err(result)


def handle_admin_update_assignment(req: dict) -> dict:
    valid, e = require_fields(req, ["assignment_id", "title", "description", "due_date", "ai_enabled", "is_closed"])
    if not valid:
        return e
    ok_db, result = db.admin_update_assignment(int(req["assignment_id"]), req["title"], req.get("description", ""), req.get("due_date", ""), bool(req.get("ai_enabled")), bool(req.get("is_closed")))
    if ok_db:
        return ok(message=result)
    return err(result)

# -----------------------------
# Router: map type -> handler
# -----------------------------
ROUTES = {
    "GET_ADMIN_OVERVIEW_REQUEST": handle_admin_overview,
    "ADMIN_CREATE_SCHOOL_REQUEST": handle_admin_create_school,
    "ADMIN_UPDATE_SCHOOL_REQUEST": handle_admin_update_school,
    "ADMIN_DELETE_SCHOOL_REQUEST": handle_admin_delete_school,
    "ADMIN_CREATE_USER_REQUEST": handle_admin_create_user,
    "ADMIN_UPDATE_USER_REQUEST": handle_admin_update_user,
    "ADMIN_DELETE_USER_REQUEST": handle_admin_delete_user,
    "ADMIN_UPDATE_COURSE_REQUEST": handle_admin_update_course,
    "ADMIN_UPDATE_ASSIGNMENT_REQUEST": handle_admin_update_assignment,
    "SIGNUP_REQUEST": handle_signup,
    "LOGIN_REQUEST": handle_login,
    "APPROVE_USER_REQUEST": handle_approve,
    "UPDATE_SCHOOL_REQUEST": handle_school_update,
    "GET_USERS_REQUEST": handle_get_users,
    "BLOCK_USER_REQUEST": handle_block,
    "UNBLOCK_USER_REQUEST": handle_unblock,
    "GET_SCHOOL_COURSES_REQUEST": handle_school_courses,
    "GET_SCHOOL_ASSIGNMENTS_REQUEST": handle_school_assignments,
    "GET_TEACHER_COURSES_REQUEST": handle_get_teacher_courses,
    "CREATE_COURSE_REQUEST": handle_create_course,
    "DELETE_COURSE_REQUEST": handle_delete_course,
    "GET_COURSE_ASSIGNMENTS_REQUEST": handle_get_course_assignments,
    "CREATE_ASSIGNMENT_REQUEST": handle_create_assignment,
    "SET_ASSIGNMENT_CLOSED_REQUEST": handle_set_assignment_closed,
    "DELETE_ASSIGNMENT_REQUEST": handle_delete_assignment,
    "GET_COURSE_STUDENTS_REQUEST": handle_get_course_students,
    "UPDATE_COURSE_MEMBER_STATUS_REQUEST": handle_update_course_member_status,
    "DELETE_COURSE_MEMBER_REQUEST": handle_delete_course_member,
    "GET_SUBMISSIONS_FOR_ASSIGNMENT_REQUEST": handle_get_submissions_for_assignment,
    "UPDATE_SUBMISSION_REVIEW_REQUEST": handle_update_submission_review,
    "GET_COURSE_MATERIALS_REQUEST": handle_get_course_materials,
    "CREATE_MATERIAL_REQUEST": handle_create_material,
    "DELETE_MATERIAL_REQUEST": handle_delete_material,
    "SAVE_COURSE_MESSAGE_REQUEST": handle_save_course_message,
    "GET_COURSE_MESSAGES_REQUEST": handle_get_course_messages,
    "DELETE_MESSAGE_REQUEST": handle_delete_message,
    "UPLOAD_SUBMISSION_REQUEST": handle_upload_submission,
    "DOWNLOAD_FILE_REQUEST": handle_download_file,
    "GET_STUDENT_DASHBOARD_REQUEST": handle_get_student_dashboard,
    "JOIN_COURSE_BY_CODE_REQUEST": handle_join_course_by_code,
    "LEAVE_COURSE_REQUEST": handle_leave_course,
    "DELETE_STUDENT_SUBMISSION_REQUEST": handle_delete_student_submission,
    "MARK_MESSAGE_READ_REQUEST": handle_mark_message_read,
    "MARK_ALL_MESSAGES_READ_REQUEST": handle_mark_all_messages_read,
    "MARK_GRADE_READ_REQUEST": handle_mark_grade_read,
}


def handle_request(req: dict, client_ip="UNKNOWN", session: dict | None = None) -> dict:
    req_type = req.get("type")
    user_id = req.get("user_id") or req.get("sender_id") or req.get("updated_by") or (session or {}).get("user_id")
    user_name = req.get("name") or (session or {}).get("name")

    if not req_type:
        resp = err("MISSING_TYPE")
        log_action("UNKNOWN", req, resp, client_ip, user_id, user_name)
        return resp

    handler = ROUTES.get(req_type)
    if not handler:
        resp = err("UNKNOWN_REQUEST", type=req_type)
        log_action(req_type, req, resp, client_ip, user_id, user_name)
        return resp

    auth_ok, auth_resp = authorize_request(req, session or {})
    if not auth_ok:
        log_action(req_type, req, auth_resp, client_ip, user_id, user_name)
        return auth_resp

    try:
        resp = handler(req)
    except Exception as e:
        print("[!] Handler exception:", e)
        resp = err("SERVER_ERROR")

    log_action(req_type, req, resp, client_ip, user_id, user_name)

    return resp
# -----------------------------
# Client session: DH + AES + one request
# -----------------------------
def handle_client(client_sock, addr):
    print(f"[+] Connected: {addr}")
    session = {}
    try:
        aes_key = DH_server(client_sock)

        while True:
            encrypted_req = recv_by_size(client_sock)
            if not encrypted_req:
                break

            plain_req_bytes = decrypt_message(aes_key, encrypted_req)

            try:
                req = json.loads(plain_req_bytes.decode("utf-8"))
            except json.JSONDecodeError:
                resp = err("BAD_JSON")
            else:
                resp = handle_request(req, addr[0], session)
                if req.get("type") == "LOGIN_REQUEST" and resp.get("status") == "OK":
                    session = build_session_from_login_response(resp)

            plain_resp = json.dumps(resp).encode("utf-8")
            encrypted_resp = encrypt_message(aes_key, plain_resp)
            send_with_size(client_sock, encrypted_resp)

    except Exception as e:
        print(f"[!] Error {addr}: {e}")
    finally:
        client_sock.close()
        print(f"[-] Disconnected: {addr}")



def main():
    STORAGE_ROOT.mkdir(parents=True, exist_ok=True)

    threading.Thread(target=run_ai_grading_worker, daemon=True, name="AIGraderWorker").start()

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind((HOST, PORT))
    s.listen()
    print(f"[SERVER] Listening on {HOST}:{PORT}")

    while True:
        conn, addr = s.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    main()
