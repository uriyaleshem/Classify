import sys
import socket
import json
import hashlib
import threading
import os
import base64
import urllib.request
from pathlib import Path
from PySide6.QtGui import QIcon
from PySide6.QtCore import QObject, Signal, Slot, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from tcp_by_size import send_with_size, recv_by_size
from DH import DH_client
from AES_e import encrypt_message, decrypt_message
import resources_rc


APP_DIR = Path(__file__).resolve().parent
DEFAULT_CLASSIFY_HOST = "127.0.0.1"
DEFAULT_CLASSIFY_PORT = 5555
DEFAULT_DISCOVERY_TIMEOUT_SECONDS = 3


def client_config_path() -> Path:
    return Path(os.getenv("CLASSIFY_CLIENT_CONFIG", str(APP_DIR / "client_config.json")))


def load_client_config() -> dict:
    path = client_config_path()
    if not path.exists() or not path.is_file():
        return {}
    try:
        with path.open("r", encoding="utf-8") as file:
            data = json.load(file)
        return data if isinstance(data, dict) else {}
    except Exception as exc:
        print(f"[DISCOVERY] Could not read {path}: {exc}")
        return {}


def safe_port(value, default_port=DEFAULT_CLASSIFY_PORT) -> int:
    try:
        port = int(value)
    except (TypeError, ValueError):
        return int(default_port)
    return port if 1 <= port <= 65535 else int(default_port)


def server_address_from_payload(payload: dict, default_host: str, default_port: int):
    if not isinstance(payload, dict):
        return default_host, default_port

    source = payload
    for key in ("classify_server", "server"):
        nested = payload.get(key)
        if isinstance(nested, dict):
            source = nested
            break

    host = (
        source.get("host")
        or source.get("ip")
        or source.get("domain")
        or source.get("server_host")
        or default_host
    )
    port = source.get("port", source.get("server_port", default_port))
    return str(host).strip() or default_host, safe_port(port, default_port)


def fetch_discovery_server_address(discovery_url: str, timeout_seconds: int, default_host: str, default_port: int):
    request = urllib.request.Request(discovery_url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        raw = response.read(64 * 1024)
    payload = json.loads(raw.decode("utf-8"))
    return server_address_from_payload(payload, default_host, default_port)


def resolve_configured_server_address(default_host=DEFAULT_CLASSIFY_HOST, default_port=DEFAULT_CLASSIFY_PORT):
    config = load_client_config()
    fallback_host = str(config.get("fallback_host") or config.get("host") or default_host).strip() or default_host
    fallback_port = safe_port(config.get("fallback_port", config.get("port", default_port)), default_port)
    discovery_url = str(config.get("discovery_url", "")).strip()
    timeout_seconds = safe_port(config.get("discovery_timeout_seconds", DEFAULT_DISCOVERY_TIMEOUT_SECONDS), DEFAULT_DISCOVERY_TIMEOUT_SECONDS)

    if discovery_url:
        try:
            return fetch_discovery_server_address(discovery_url, timeout_seconds, fallback_host, fallback_port)
        except Exception as exc:
            print(f"[DISCOVERY] Discovery failed ({discovery_url}): {exc}. Using fallback {fallback_host}:{fallback_port}")

    return fallback_host, fallback_port



def prettify_message(message: str) -> str:
    raw = (message or '').strip()
    if not raw:
        return 'An unexpected error occurred. Please try again.'

    mapping = {
        'OK': 'Done successfully.',
        'DOWNLOAD_OK': 'File downloaded successfully.',
        'UNKNOWN_ERROR': 'An unexpected error occurred. Please try again.',
        'INVALID_CREDENTIALS': 'The email or password is incorrect.',
        'WAITING_APPROVAL': 'Your account is waiting for approval from your school manager.',
        'USER_BLOCKED': 'This account has been blocked. Please contact your school manager.',
        'USER_ALREADY_EXISTS': 'An account with this email already exists.',
        'USER_CREATED': 'Your account was created successfully.',
        'USER_APPROVED': 'The user was approved successfully.',
        'USER_UNBLOCKED': 'The user was unblocked successfully.',
        'USER_DELETED': 'The user was deleted successfully.',
        'MISSING_FIELDS': 'Some required fields are missing.',
        'SCHOOL_ID_REQUIRED': 'Please enter your school ID before continuing.',
        'INVALID_SCHOOL_ID': 'Please enter a valid school ID.',
        'SCHOOL_NOT_FOUND': 'We could not find a school with that ID.',
        'SCHOOL_CREATED': 'The school was created successfully.',
        'SCHOOL_UPDATED': 'School details were updated successfully.',
        'SCHOOL_DELETED': 'The school was deleted successfully.',
        'NO_FIELDS_TO_UPDATE': 'There is nothing to update.',
        'INVALID_ROLE': 'Please choose a valid role.',
        'INVALID_STATUS': 'Please choose a valid status.',
        'TEACHER_NOT_FOUND': 'Please choose a valid teacher.',
        'COURSE_NOT_FOUND': 'The class could not be found.',
        'COURSE_DELETED': 'The class was deleted successfully.',
        'CLASS_NOT_FOUND': 'The class code was not found.',
        'INVALID_CLASS_CODE': 'Please enter a valid class code.',
        'STUDENT_ADDED': 'The student was added successfully.',
        'STUDENT_REMOVED': 'The student was removed successfully.',
        'MEMBER_STATUS_UPDATED': 'The student status was updated successfully.',
        'ASSIGNMENT_NOT_FOUND': 'The assignment could not be found.',
        'ASSIGNMENT_CLOSED': 'This assignment is closed and can no longer be submitted.',
        'ASSIGNMENT_UPDATED': 'The assignment was updated successfully.',
        'ASSIGNMENT_DELETED': 'The assignment was deleted successfully.',
        'ASSIGNMENT_ALREADY_PAST_DUE': 'This due date has already passed. Please choose a future date.',
        'RUBRIC_ATTACHMENT_REQUIRED': 'Please attach instructions file before publishing an AI-checked assignment.',
        'RUBRIC_ATTACHMENT_MISSING': 'This AI assignment is missing its rubric file.',
        'MATERIAL_NOT_FOUND': 'The study material could not be found.',
        'MATERIAL_DELETED': 'The material was deleted successfully.',
        'MESSAGE_NOT_FOUND': 'The message could not be found.',
        'MESSAGE_DELETED': 'The message was deleted successfully.',
        'MESSAGE_MARKED_READ': 'The message was marked as read.',
        'ALL_MESSAGES_MARKED_READ': 'All messages were marked as read.',
        'SUBMISSION_NOT_FOUND': 'The submission could not be found.',
        'SUBMISSION_DELETED': 'Your submission was deleted successfully.',
        'REVIEW_UPDATED': 'The review was updated successfully.',
        'STATUS_UPDATED': 'The status was updated successfully.',
        'GRADE_SAVED': 'The grade was saved successfully.',
        'GRADE_UPDATED': 'The grade was updated successfully.',
        'GRADE_MARKED_READ': 'The grade was marked as read.',
        'AI_RESULTS_DELETED': 'The AI results were deleted successfully.',
        'NO_PENDING_SUBMISSIONS': 'There are no pending submissions right now.',
        'CLAIM_CONFLICT': 'This submission is already being processed. Please try again in a moment.',
        'NO_PERMISSION': 'You do not have permission to perform this action.',
        'NOT_AUTHENTICATED': 'Please sign in before continuing.',
        'AUTH_REQUIRED': 'Please sign in before continuing.',
        'FORBIDDEN': 'You do not have permission to perform this action.',
        'UNKNOWN_REQUEST': 'The app sent an unsupported request to the server.',
        'FILE_NOT_FOUND': 'The selected file could not be found.',
        'EMPTY_FILE': 'The selected file is empty.',
        'EMPTY_FILE_CONTENT': 'The downloaded file is empty.',
        'FILE_TOO_LARGE': 'File is too large. Maximum allowed size is 25MB.',
        'BAD_FILE_CONTENT': 'The file content is invalid.',
        'DOWNLOAD_NOT_ALLOWED': 'You do not have permission to download this file.',
        'INVALID_FILE_REFERENCE': 'The file reference is invalid.',
        'INVALID_FILE_PATH': 'The selected file could not be accessed.',
        'NETWORK_ERROR': 'Could not connect to the server. Please try again.',
        'NETWORK_TIMEOUT': 'The server took too long to respond. Please try again.',
        'SERVER_UNAVAILABLE': 'The server is currently unavailable. Please try again later.',
    }

    if raw in mapping:
        return mapping[raw]

    if raw.startswith('VALIDATION_ERROR'):
        return 'The selected file could not be validated.'
    if raw.startswith('enter FULL name'):
        return 'Please enter your full name.'
    if raw.startswith('enter valid email'):
        return 'Please enter a valid email address.'
    if raw.startswith('UNIQUE constraint failed'):
        return 'This item already exists.'
    if raw.startswith('FOREIGN KEY constraint failed'):
        return 'The requested action could not be completed because related data is missing.'
    if raw in {'Server closed connection', 'Connection reset by peer'}:
        return 'The connection to the server was lost. Please try again.'

    return raw.replace('_', ' ')


# -----------------------------
# TCP Auth Client (persistent connection)
# -----------------------------
class AuthClient:
    def __init__(self, host=DEFAULT_CLASSIFY_HOST, port=DEFAULT_CLASSIFY_PORT):
        self.fallback_host = host or DEFAULT_CLASSIFY_HOST
        self.fallback_port = safe_port(port, DEFAULT_CLASSIFY_PORT)
        self.host, self.port = resolve_configured_server_address(self.fallback_host, self.fallback_port)
        self.timeout_seconds = 30

        self.sock = None
        self.aes_key = None
        self.current_user = {}
        self._lock = threading.Lock()

    def refresh_server_address(self):
        host, port = resolve_configured_server_address(self.fallback_host, self.fallback_port)
        if host != self.host or port != self.port:
            print(f"[DISCOVERY] Classify server changed to {host}:{port}")
        self.host = host
        self.port = port

    def connect(self):
        if self.sock is not None and self.aes_key is not None:
            return

        self.refresh_server_address()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.settimeout(self.timeout_seconds)
            sock.connect((self.host, self.port))
            aes_key = DH_client(sock)
        except Exception:
            try:
                sock.close()
            except Exception:
                pass
            raise

        self.sock = sock
        self.aes_key = aes_key

    def close(self):
        if self.sock is not None:
            try:
                self.sock.close()
            except Exception:
                pass
        self.sock = None
        self.aes_key = None

    def _send_request_once(self, req: dict) -> dict:
        with self._lock:
            if self.sock is None or self.aes_key is None:
                self.connect()

            outgoing = dict(req)
            if self.current_user and outgoing.get("type") not in {"LOGIN_REQUEST", "SIGNUP_REQUEST"}:
                outgoing["_auth_user_id"] = int(self.current_user.get("user_id", -1))
                outgoing["_auth_token"] = str(self.current_user.get("auth_token", ""))

            plain = json.dumps(outgoing).encode("utf-8")
            encrypted = encrypt_message(self.aes_key, plain)
            send_with_size(self.sock, encrypted)

            encrypted_resp = recv_by_size(self.sock)
            if not encrypted_resp:
                raise ConnectionError("Server closed connection")

            plain_resp = decrypt_message(self.aes_key, encrypted_resp).decode("utf-8")
            return json.loads(plain_resp)

    def send_request(self, req: dict) -> dict:
        try:
            return self._send_request_once(req)
        except Exception:
            self.close()
            self.connect()
            return self._send_request_once(req)

    def clear_user(self):
        with self._lock:
            self.current_user = {}

    def _load_file_payload(self, local_path: str):
        path = (local_path or "").replace("file:///", "")
        path = os.path.normpath(path)
        with open(path, "rb") as f:
            file_bytes = f.read()
        return os.path.basename(path), base64.b64encode(file_bytes).decode("utf-8")

    # ---------- APIs ----------
    def login(self, email: str, password: str) -> dict:
        email = email.strip().lower()
        password_hash = hashlib.sha256(password.encode("utf-8")).hexdigest()
        req = {"type": "LOGIN_REQUEST", "email": email, "password": password_hash}
        resp = self.send_request(req)
        if resp.get("status") == "OK":
            self.current_user = {
                "user_id": int(resp.get("user_id", -1)),
                "role": str(resp.get("role", "")).upper(),
                "school_id": int(resp.get("school_id", -1)),
                "auth_token": str(resp.get("auth_token", "")),
            }
        else:
            self.current_user = {}
        return resp

    def signup(self, name, email: str, password: str, role: str, school_id) -> dict:
        email = email.strip().lower()
        password_hash = hashlib.sha256(password.encode("utf-8")).hexdigest()
        req = {"type": "SIGNUP_REQUEST", "name": name, "email": email, "password": password_hash, "role": role, "school_id": school_id}
        return self.send_request(req)

    def approve_user(self, user_id: int) -> dict:
        req = {"type": "APPROVE_USER_REQUEST", "user_id": int(user_id)}
        return self.send_request(req)

    def get_teacher_courses(self, teacher_id: int) -> dict:
        return self.send_request({"type": "GET_TEACHER_COURSES_REQUEST", "teacher_id": int(teacher_id)})

    def create_course(self, name: str, description: str, teacher_id: int, school_id: int) -> dict:
        req = {
            "type": "CREATE_COURSE_REQUEST",
            "name": name,
            "description": description,
            "teacher_id": int(teacher_id),
            "school_id": int(school_id)
        }
        return self.send_request(req)

    def delete_course(self, course_id: int) -> dict:
        return self.send_request({"type": "DELETE_COURSE_REQUEST", "course_id": int(course_id)})

    def get_course_assignments(self, course_id: int) -> dict:
        return self.send_request({"type": "GET_COURSE_ASSIGNMENTS_REQUEST", "course_id": int(course_id)})

    def create_assignment(self, course_id: int, title: str, description: str, due_date: str, ai_enabled: bool = True, attachment_path: str = "") -> dict:
        req = {
            "type": "CREATE_ASSIGNMENT_REQUEST",
            "course_id": int(course_id),
            "title": title,
            "description": description,
            "due_date": due_date,
            "ai_enabled": bool(ai_enabled),
            "attachment_path": ""
        }
        if attachment_path:
            attachment_name, attachment_b64 = self._load_file_payload(attachment_path)
            req["attachment_name"] = attachment_name
            req["attachment_content_b64"] = attachment_b64
        return self.send_request(req)

    def set_assignment_closed(self, assignment_id: int, is_closed: bool) -> dict:
        return self.send_request({"type": "SET_ASSIGNMENT_CLOSED_REQUEST", "assignment_id": int(assignment_id), "is_closed": bool(is_closed)})

    def delete_assignment(self, assignment_id: int) -> dict:
        return self.send_request({"type": "DELETE_ASSIGNMENT_REQUEST", "assignment_id": int(assignment_id)})

    def get_course_students(self, course_id: int) -> dict:
        return self.send_request({"type": "GET_COURSE_STUDENTS_REQUEST", "course_id": int(course_id)})

    def get_submissions_for_assignment(self, assignment_id: int) -> dict:
        return self.send_request({"type": "GET_SUBMISSIONS_FOR_ASSIGNMENT_REQUEST", "assignment_id": int(assignment_id)})

    def update_submission_review(self, submission_id: int, final_score: float, teacher_feedback: str, updated_by: int) -> dict:
        req = {
            "type": "UPDATE_SUBMISSION_REVIEW_REQUEST",
            "submission_id": int(submission_id),
            "final_score": float(final_score),
            "teacher_feedback": teacher_feedback,
            "updated_by": int(updated_by)
        }
        return self.send_request(req)

    def get_course_materials(self, course_id: int) -> dict:
        return self.send_request({"type": "GET_COURSE_MATERIALS_REQUEST", "course_id": int(course_id)})

    def create_material(self, course_id: int, title: str, description: str, material_type: str, created_by: int, file_path: str = "") -> dict:
        req = {
            "type": "CREATE_MATERIAL_REQUEST",
            "course_id": int(course_id),
            "title": title,
            "description": description,
            "material_type": material_type,
            "created_by": int(created_by),
            "file_path": ""
        }
        if file_path:
            file_name, file_b64 = self._load_file_payload(file_path)
            req["file_name"] = file_name
            req["file_content_b64"] = file_b64
        return self.send_request(req)

    def delete_material(self, material_id: int) -> dict:
        return self.send_request({"type": "DELETE_MATERIAL_REQUEST", "material_id": int(material_id)})

    def save_course_message(self, course_id: int, sender_id: int, subject: str, body: str, state: str) -> dict:
        req = {
            "type": "SAVE_COURSE_MESSAGE_REQUEST",
            "course_id": int(course_id),
            "sender_id": int(sender_id),
            "subject": subject,
            "body": body,
            "state": state
        }
        return self.send_request(req)

    def get_course_messages(self, course_id: int) -> dict:
        return self.send_request({"type": "GET_COURSE_MESSAGES_REQUEST", "course_id": int(course_id)})

    def delete_message(self, message_id: int) -> dict:
        return self.send_request({"type": "DELETE_MESSAGE_REQUEST", "message_id": int(message_id)})

    def upload_submission(self, assignment_id: int, student_id: int, file_path: str) -> dict:
        file_name, file_b64 = self._load_file_payload(file_path)
        req = {
            "type": "UPLOAD_SUBMISSION_REQUEST",
            "assignment_id": int(assignment_id),
            "student_id": int(student_id),
            "file_name": file_name,
            "file_content_b64": file_b64
        }
        return self.send_request(req)


    def update_course_member_status(self, course_id: int, student_id: int, member_status: str) -> dict:
        return self.send_request({
            "type": "UPDATE_COURSE_MEMBER_STATUS_REQUEST",
            "course_id": int(course_id),
            "student_id": int(student_id),
            "member_status": member_status
        })

    def delete_course_member(self, course_id: int, student_id: int) -> dict:
        return self.send_request({
            "type": "DELETE_COURSE_MEMBER_REQUEST",
            "course_id": int(course_id),
            "student_id": int(student_id)
        })

    # --- Added: student-home APIs ---
    def get_student_dashboard(self, student_id: int) -> dict:
        return self.send_request({"type": "GET_STUDENT_DASHBOARD_REQUEST", "student_id": int(student_id)})

    def join_course_by_code(self, student_id: int, class_code: str) -> dict:
        return self.send_request({"type": "JOIN_COURSE_BY_CODE_REQUEST", "student_id": int(student_id), "class_code": class_code})

    def leave_course(self, student_id: int, course_id: int) -> dict:
        return self.send_request({"type": "LEAVE_COURSE_REQUEST", "student_id": int(student_id), "course_id": int(course_id)})

    def delete_student_submission(self, assignment_id: int, student_id: int) -> dict:
        return self.send_request({"type": "DELETE_STUDENT_SUBMISSION_REQUEST", "assignment_id": int(assignment_id), "student_id": int(student_id)})

    def mark_message_read(self, student_id: int, message_id: int) -> dict:
        return self.send_request({"type": "MARK_MESSAGE_READ_REQUEST", "student_id": int(student_id), "message_id": int(message_id)})

    def mark_all_messages_read(self, student_id: int) -> dict:
        return self.send_request({"type": "MARK_ALL_MESSAGES_READ_REQUEST", "student_id": int(student_id)})

    def mark_grade_read(self, student_id: int, submission_id: int) -> dict:
        return self.send_request({"type": "MARK_GRADE_READ_REQUEST", "student_id": int(student_id), "submission_id": int(submission_id)})

    def upload_submission_text(self, assignment_id: int, student_id: int, submission_text: str) -> dict:
        file_name = f"submission_{int(assignment_id)}_{int(student_id)}.txt"
        file_b64 = base64.b64encode((submission_text or "").encode("utf-8")).decode("utf-8")
        req = {
            "type": "UPLOAD_SUBMISSION_REQUEST",
            "assignment_id": int(assignment_id),
            "student_id": int(student_id),
            "file_name": file_name,
            "file_content_b64": file_b64
        }
        return self.send_request(req)

    def download_file(self, file_path: str, save_dir: str = "") -> tuple[dict, str]:
        resp = self.send_request({"type": "DOWNLOAD_FILE_REQUEST", "file_path": file_path})
        if resp.get("status") != "OK":
            return resp, ""

        file_name = resp.get("file_name", "downloaded_file")
        file_b64 = resp.get("file_content_b64", "")
        if not file_b64:
            return {"status": "ERROR", "message": "EMPTY_FILE_CONTENT"}, ""

        target_dir = save_dir.strip() if save_dir else os.path.join(os.path.expanduser("~"), "Downloads", "ClassifyDownloads")
        os.makedirs(target_dir, exist_ok=True)

        file_bytes = base64.b64decode(file_b64.encode("utf-8"))
        target_path = os.path.join(target_dir, file_name)
        base_name, ext = os.path.splitext(target_path)
        counter = 1
        while os.path.exists(target_path):
            target_path = f"{base_name}_{counter}{ext}"
            counter += 1

        with open(target_path, "wb") as f:
            f.write(file_bytes)

        return resp, target_path


# ------------------------------------
# QML-facing object (exposed as "auth")
# ------------------------------------
class Auth(QObject):
    loginResult = Signal(bool, str, str, int, str, int, str, str, str)
    signupResult = Signal(bool, str)

    schoolUpdateResult = Signal(bool, str)
    approveResult = Signal(bool, str)
    getUsersResult = Signal(bool, str, list)
    getCoursesResult = Signal(bool, str, list)
    getAssignmentsResult = Signal(bool, str, list)

    teacherCoursesResult = Signal(bool, str, list)
    courseAssignmentsResult = Signal(bool, str, int, list)
    courseStudentsResult = Signal(bool, str, int, list)
    submissionsResult = Signal(bool, str, int, list)
    createCourseResult = Signal(bool, str, int)
    createAssignmentResult = Signal(bool, str, int, int)
    setAssignmentClosedResult = Signal(bool, str, int, bool)
    deleteAssignmentResult = Signal(bool, str, int, int)
    updateSubmissionReviewResult = Signal(bool, str, int)
    courseMaterialsResult = Signal(bool, str, int, list)
    createMaterialResult = Signal(bool, str, int, int)
    deleteMaterialResult = Signal(bool, str, int, int)
    courseMessagesResult = Signal(bool, str, int, list)
    saveCourseMessageResult = Signal(bool, str, int, int)
    deleteMessageResult = Signal(bool, str, int, int)
    uploadSubmissionResult = Signal(bool, str, int, int)
    updateCourseMemberStatusResult = Signal(bool, str, int, int, str)
    deleteCourseMemberResult = Signal(bool, str, int, int)
    deleteCourseResult = Signal(bool, str, int)
    downloadFileResult = Signal(bool, str, str, str)
    localFileValidationResult = Signal(bool, str, str, str, int)
    studentDashboardResult = Signal(bool, str, int, list, list, list, list)
    joinCourseResult = Signal(bool, str, int, str)
    leaveCourseResult = Signal(bool, str, int, int)
    deleteSubmissionResult = Signal(bool, str, int, int)
    markMessageReadResult = Signal(bool, str, int, int)
    markAllMessagesReadResult = Signal(bool, str, int)
    markGradeReadResult = Signal(bool, str, int, int)
    adminOverviewResult = Signal(bool, str, dict)
    adminActionResult = Signal(bool, str, str)

    def __init__(self, host="127.0.0.1", port=5555):
        super().__init__()
        self._client = AuthClient(host, port)

        try:
            self._client.connect()
        except Exception as e:
            print(" Initial connect failed:", e)

    @Slot()
    def logout(self):
        self._client.clear_user()

    @Slot(int, str, str, str, str)
    def updateSchool(self, school_id, name, address, contact_name, contact_email):
        try:
            payload = {
                "type": "UPDATE_SCHOOL_REQUEST",
                "school_id": int(school_id),
                "name": name,
                "address": address,
                "contact_name": contact_name,
                "contact_email": contact_email
            }
            resp = self._client.send_request(payload)
            if resp.get("status") == "OK":
                self.schoolUpdateResult.emit(True, prettify_message(resp.get("message", "OK")))
            else:
                self.schoolUpdateResult.emit(False, prettify_message(resp.get("message", "UNKNOWN_ERROR")))
        except Exception as e:
            self.schoolUpdateResult.emit(False, prettify_message(str(e)))

    @Slot(int)
    def get_school_assignments(self, school_id):
        threading.Thread(target=self._worker_get_school_assignments, args=(school_id,), daemon=True).start()

    def _worker_get_school_assignments(self, school_id):
        try:
            req = {"type": "GET_SCHOOL_ASSIGNMENTS_REQUEST", "school_id": school_id}
            resp = self._client.send_request(req)
            if resp.get("status") == "OK":
                self.getAssignmentsResult.emit(True, "OK", resp.get("assignments", []))
            else:
                self.getAssignmentsResult.emit(False, prettify_message(resp.get("message", "ERROR")), [])
        except Exception as e:
            self.getAssignmentsResult.emit(False, f"NETWORK_ERROR: {e}", [])

    @Slot(int)
    def get_school_courses(self, school_id):
        threading.Thread(target=self._worker_get_school_courses, args=(school_id,), daemon=True).start()

    def _worker_get_school_courses(self, school_id):
        try:
            req = {"type": "GET_SCHOOL_COURSES_REQUEST", "school_id": school_id}
            resp = self._client.send_request(req)
            if resp.get("status") == "OK":
                self.getCoursesResult.emit(True, "OK", resp.get("courses", []))
            else:
                self.getCoursesResult.emit(False, prettify_message(resp.get("message", "ERROR")), [])
        except Exception as e:
            self.getCoursesResult.emit(False, f"NETWORK_ERROR: {e}", [])

    @Slot(int)
    def approveUser(self, uid):
        threading.Thread(target=self._worker_approve_user, args=(uid,), daemon=True).start()

    def _worker_approve_user(self, uid):
        try:
            req = {"type": "APPROVE_USER_REQUEST", "user_id": uid}
            self._client.send_request(req)
        except Exception as e:
            print("ERROR:", e)

    @Slot(int)
    def blockUser(self, uid):
        threading.Thread(target=self._worker_block_user, args=(uid,), daemon=True).start()

    def _worker_block_user(self, uid):
        try:
            req = {"type": "BLOCK_USER_REQUEST", "user_id": uid}
            self._client.send_request(req)
        except Exception as e:
            print("ERROR:", e)

    @Slot(int)
    def unblockUser(self, uid):
        threading.Thread(target=self._worker_unblock_user, args=(uid,), daemon=True).start()

    def _worker_unblock_user(self, uid):
        try:
            req = {"type": "UNBLOCK_USER_REQUEST", "user_id": uid}
            self._client.send_request(req)
        except Exception as e:
            print("ERROR:", e)

    @Slot(int)
    def getUsers(self, school_id):
        threading.Thread(target=self._worker_get_users, args=(school_id,), daemon=True).start()

    def _worker_get_users(self, school_id):
        try:
            req = {"type": "GET_USERS_REQUEST", "school_id": school_id}
            resp = self._client.send_request(req)
            if resp.get("status") == "OK":
                self.getUsersResult.emit(True, "OK", resp.get("users", []))
            else:
                self.getUsersResult.emit(False, prettify_message(resp.get("message", "ERROR")), [])
        except Exception as e:
            self.getUsersResult.emit(False, f"NETWORK_ERROR: {e}", [])

    @Slot(int)
    def get_teacher_courses(self, teacher_id):
        threading.Thread(target=self._worker_get_teacher_courses, args=(teacher_id,), daemon=True).start()

    def _worker_get_teacher_courses(self, teacher_id):
        try:
            resp = self._client.get_teacher_courses(teacher_id)
            if resp.get("status") == "OK":
                self.teacherCoursesResult.emit(True, "OK", resp.get("courses", []))
            else:
                self.teacherCoursesResult.emit(False, prettify_message(resp.get("message", "ERROR")), [])
        except Exception as e:
            self.teacherCoursesResult.emit(False, f"NETWORK_ERROR: {e}", [])

    @Slot(str, str, int, int)
    def create_course(self, name, description, teacher_id, school_id):
        threading.Thread(target=self._worker_create_course, args=(name, description, teacher_id, school_id), daemon=True).start()

    def _worker_create_course(self, name, description, teacher_id, school_id):
        try:
            resp = self._client.create_course(name, description, teacher_id, school_id)
            if resp.get("status") == "OK":
                self.createCourseResult.emit(True, "OK", int(resp.get("course_id", -1)))
            else:
                self.createCourseResult.emit(False, prettify_message(resp.get("message", "ERROR")), -1)
        except Exception as e:
            self.createCourseResult.emit(False, f"NETWORK_ERROR: {e}", -1)

    @Slot(int, int)
    def delete_course_member(self, course_id, student_id):
        threading.Thread(target=self._worker_delete_course_member, args=(course_id, student_id), daemon=True).start()

    def _worker_delete_course_member(self, course_id, student_id):
        try:
            resp = self._client.delete_course_member(course_id, student_id)
            if resp.get("status") == "OK":
                self.deleteCourseMemberResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("course_id", course_id)), int(resp.get("student_id", student_id)))
            else:
                self.deleteCourseMemberResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), int(student_id))
        except Exception as e:
            self.deleteCourseMemberResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), int(student_id))

    @Slot(int)
    def delete_course(self, course_id):
        threading.Thread(target=self._worker_delete_course, args=(course_id,), daemon=True).start()

    def _worker_delete_course(self, course_id):
        try:
            resp = self._client.delete_course(course_id)
            if resp.get("status") == "OK":
                self.deleteCourseResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("course_id", course_id)))
            else:
                self.deleteCourseResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id))
        except Exception as e:
            self.deleteCourseResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id))

    @Slot(str, str)
    def validate_local_file(self, file_path, target):
        try:
            path = (file_path or "").replace("file:///", "")
            path = os.path.normpath(path)
            if not path or not os.path.exists(path):
                self.localFileValidationResult.emit(False, target, file_path, prettify_message("FILE_NOT_FOUND"), 0)
                return
            size_bytes = os.path.getsize(path)
            max_size = 25 * 1024 * 1024
            if size_bytes <= 0:
                self.localFileValidationResult.emit(False, target, file_path, prettify_message("EMPTY_FILE"), size_bytes)
                return
            if size_bytes > max_size:
                self.localFileValidationResult.emit(False, target, file_path, prettify_message("FILE_TOO_LARGE"), size_bytes)
                return
            self.localFileValidationResult.emit(True, target, file_path, prettify_message("OK"), size_bytes)
        except Exception as e:
            self.localFileValidationResult.emit(False, target, file_path, prettify_message(f"VALIDATION_ERROR: {e}"), 0)

    @Slot(int)
    def get_course_assignments(self, course_id):
        threading.Thread(target=self._worker_get_course_assignments, args=(course_id,), daemon=True).start()

    def _worker_get_course_assignments(self, course_id):
        try:
            resp = self._client.get_course_assignments(course_id)
            if resp.get("status") == "OK":
                self.courseAssignmentsResult.emit(True, "OK", int(resp.get("course_id", course_id)), resp.get("assignments", []))
            else:
                self.courseAssignmentsResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), [])
        except Exception as e:
            self.courseAssignmentsResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), [])

    @Slot(int, str, str, str, bool, str)
    def create_assignment(self, course_id, title, description, due_date, ai_enabled=True, attachment_path=""):
        threading.Thread(target=self._worker_create_assignment, args=(course_id, title, description, due_date, ai_enabled, attachment_path), daemon=True).start()

    def _worker_create_assignment(self, course_id, title, description, due_date, ai_enabled, attachment_path):
        try:
            if attachment_path:
                path = os.path.normpath((attachment_path or "").replace("file:///", ""))
                if os.path.exists(path) and os.path.getsize(path) > 25 * 1024 * 1024:
                    self.createAssignmentResult.emit(False, prettify_message("FILE_TOO_LARGE"), int(course_id), -1)
                    return
            resp = self._client.create_assignment(course_id, title, description, due_date, ai_enabled, attachment_path)
            if resp.get("status") == "OK":
                self.createAssignmentResult.emit(True, "OK", int(resp.get("course_id", course_id)), int(resp.get("assignment_id", -1)))
            else:
                self.createAssignmentResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), -1)
        except Exception as e:
            self.createAssignmentResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), -1)

    @Slot(int, bool)
    def set_assignment_closed(self, assignment_id, is_closed):
        threading.Thread(target=self._worker_set_assignment_closed, args=(assignment_id, is_closed), daemon=True).start()

    def _worker_set_assignment_closed(self, assignment_id, is_closed):
        try:
            resp = self._client.set_assignment_closed(assignment_id, is_closed)
            if resp.get("status") == "OK":
                self.setAssignmentClosedResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("assignment_id", assignment_id)), bool(resp.get("is_closed", is_closed)))
            else:
                self.setAssignmentClosedResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(assignment_id), bool(is_closed))
        except Exception as e:
            self.setAssignmentClosedResult.emit(False, f"NETWORK_ERROR: {e}", int(assignment_id), bool(is_closed))

    @Slot(int)
    def delete_assignment(self, assignment_id):
        threading.Thread(target=self._worker_delete_assignment, args=(assignment_id,), daemon=True).start()

    def _worker_delete_assignment(self, assignment_id):
        try:
            resp = self._client.delete_assignment(assignment_id)
            if resp.get("status") == "OK":
                self.deleteAssignmentResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("assignment_id", assignment_id)), int(resp.get("course_id", -1)))
            else:
                self.deleteAssignmentResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(assignment_id), -1)
        except Exception as e:
            self.deleteAssignmentResult.emit(False, f"NETWORK_ERROR: {e}", int(assignment_id), -1)

    @Slot(int)
    def get_course_students(self, course_id):
        threading.Thread(target=self._worker_get_course_students, args=(course_id,), daemon=True).start()

    def _worker_get_course_students(self, course_id):
        try:
            resp = self._client.get_course_students(course_id)
            if resp.get("status") == "OK":
                self.courseStudentsResult.emit(True, "OK", int(resp.get("course_id", course_id)), resp.get("students", []))
            else:
                self.courseStudentsResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), [])
        except Exception as e:
            self.courseStudentsResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), [])

    @Slot(int)
    def get_submissions_for_assignment(self, assignment_id):
        threading.Thread(target=self._worker_get_submissions_for_assignment, args=(assignment_id,), daemon=True).start()

    def _worker_get_submissions_for_assignment(self, assignment_id):
        try:
            resp = self._client.get_submissions_for_assignment(assignment_id)
            if resp.get("status") == "OK":
                self.submissionsResult.emit(True, "OK", int(resp.get("assignment_id", assignment_id)), resp.get("submissions", []))
            else:
                self.submissionsResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(assignment_id), [])
        except Exception as e:
            self.submissionsResult.emit(False, f"NETWORK_ERROR: {e}", int(assignment_id), [])

    @Slot(int, str, str, int)
    def update_submission_review(self, submission_id, final_score, teacher_feedback, updated_by):
        threading.Thread(target=self._worker_update_submission_review, args=(submission_id, final_score, teacher_feedback, updated_by), daemon=True).start()

    def _worker_update_submission_review(self, submission_id, final_score, teacher_feedback, updated_by):
        try:
            resp = self._client.update_submission_review(submission_id, final_score, teacher_feedback, updated_by)
            if resp.get("status") == "OK":
                self.updateSubmissionReviewResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("submission_id", submission_id)))
            else:
                self.updateSubmissionReviewResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(submission_id))
        except Exception as e:
            self.updateSubmissionReviewResult.emit(False, f"NETWORK_ERROR: {e}", int(submission_id))

    @Slot(int)
    def get_course_materials(self, course_id):
        threading.Thread(target=self._worker_get_course_materials, args=(course_id,), daemon=True).start()

    def _worker_get_course_materials(self, course_id):
        try:
            resp = self._client.get_course_materials(course_id)
            if resp.get("status") == "OK":
                self.courseMaterialsResult.emit(True, "OK", int(resp.get("course_id", course_id)), resp.get("materials", []))
            else:
                self.courseMaterialsResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), [])
        except Exception as e:
            self.courseMaterialsResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), [])

    @Slot(int, str, str, str, int, str)
    def create_material(self, course_id, title, description, material_type, created_by, file_path=""):
        threading.Thread(target=self._worker_create_material, args=(course_id, title, description, material_type, created_by, file_path), daemon=True).start()

    def _worker_create_material(self, course_id, title, description, material_type, created_by, file_path):
        try:
            if file_path:
                path = os.path.normpath((file_path or "").replace("file:///", ""))
                if os.path.exists(path) and os.path.getsize(path) > 25 * 1024 * 1024:
                    self.createMaterialResult.emit(False, prettify_message("FILE_TOO_LARGE"), int(course_id), -1)
                    return
            resp = self._client.create_material(course_id, title, description, material_type, created_by, file_path)
            if resp.get("status") == "OK":
                self.createMaterialResult.emit(True, "OK", int(resp.get("course_id", course_id)), int(resp.get("material_id", -1)))
            else:
                self.createMaterialResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), -1)
        except Exception as e:
            self.createMaterialResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), -1)

    @Slot(int)
    def delete_material(self, material_id):
        threading.Thread(target=self._worker_delete_material, args=(material_id,), daemon=True).start()

    def _worker_delete_material(self, material_id):
        try:
            resp = self._client.delete_material(material_id)
            if resp.get("status") == "OK":
                self.deleteMaterialResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("material_id", material_id)), int(resp.get("course_id", -1)))
            else:
                self.deleteMaterialResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(material_id), -1)
        except Exception as e:
            self.deleteMaterialResult.emit(False, f"NETWORK_ERROR: {e}", int(material_id), -1)

    @Slot(int, int, str, str, str)
    def save_course_message(self, course_id, sender_id, subject, body, state):
        threading.Thread(target=self._worker_save_course_message, args=(course_id, sender_id, subject, body, state), daemon=True).start()

    def _worker_save_course_message(self, course_id, sender_id, subject, body, state):
        try:
            resp = self._client.save_course_message(course_id, sender_id, subject, body, state)
            if resp.get("status") == "OK":
                self.saveCourseMessageResult.emit(True, "OK", int(resp.get("course_id", course_id)), int(resp.get("message_id", -1)))
            else:
                self.saveCourseMessageResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), -1)
        except Exception as e:
            self.saveCourseMessageResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), -1)

    @Slot(int)
    def get_course_messages(self, course_id):
        threading.Thread(target=self._worker_get_course_messages, args=(course_id,), daemon=True).start()

    def _worker_get_course_messages(self, course_id):
        try:
            resp = self._client.get_course_messages(course_id)
            if resp.get("status") == "OK":
                self.courseMessagesResult.emit(True, "OK", int(resp.get("course_id", course_id)), resp.get("messages", []))
            else:
                self.courseMessagesResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), [])
        except Exception as e:
            self.courseMessagesResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), [])

    @Slot(int)
    def delete_message(self, message_id):
        threading.Thread(target=self._worker_delete_message, args=(message_id,), daemon=True).start()

    def _worker_delete_message(self, message_id):
        try:
            resp = self._client.delete_message(message_id)
            if resp.get("status") == "OK":
                self.deleteMessageResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("message_id", message_id)), int(resp.get("course_id", -1)))
            else:
                self.deleteMessageResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(message_id), -1)
        except Exception as e:
            self.deleteMessageResult.emit(False, f"NETWORK_ERROR: {e}", int(message_id), -1)

    @Slot(int, int, str)
    def upload_submission(self, assignment_id, student_id, file_path):
        threading.Thread(target=self._worker_upload_submission, args=(assignment_id, student_id, file_path), daemon=True).start()

    @Slot(int, int, str)
    def upload_submission_text(self, assignment_id, student_id, submission_text):
        threading.Thread(target=self._worker_upload_submission_text, args=(assignment_id, student_id, submission_text), daemon=True).start()

    def _worker_upload_submission(self, assignment_id, student_id, file_path):
        try:
            if file_path:
                path = os.path.normpath((file_path or "").replace("file:///", ""))
                if os.path.exists(path) and os.path.getsize(path) > 25 * 1024 * 1024:
                    self.uploadSubmissionResult.emit(False, prettify_message("FILE_TOO_LARGE"), int(assignment_id), -1)
                    return
            resp = self._client.upload_submission(assignment_id, student_id, file_path)
            if resp.get("status") == "OK":
                self.uploadSubmissionResult.emit(True, "OK", int(resp.get("assignment_id", assignment_id)), int(resp.get("submission_id", -1)))
            else:
                self.uploadSubmissionResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(assignment_id), -1)
        except Exception as e:
            self.uploadSubmissionResult.emit(False, f"NETWORK_ERROR: {e}", int(assignment_id), -1)

    def _worker_upload_submission_text(self, assignment_id, student_id, submission_text):
        try:
            resp = self._client.upload_submission_text(assignment_id, student_id, submission_text)
            if resp.get("status") == "OK":
                self.uploadSubmissionResult.emit(True, "OK", int(resp.get("assignment_id", assignment_id)), int(resp.get("submission_id", -1)))
            else:
                self.uploadSubmissionResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(assignment_id), -1)
        except Exception as e:
            self.uploadSubmissionResult.emit(False, f"NETWORK_ERROR: {e}", int(assignment_id), -1)

    @Slot(int, int, str)
    def update_course_member_status(self, course_id, student_id, member_status):
        threading.Thread(target=self._worker_update_course_member_status, args=(course_id, student_id, member_status), daemon=True).start()

    def _worker_update_course_member_status(self, course_id, student_id, member_status):
        try:
            resp = self._client.update_course_member_status(course_id, student_id, member_status)
            if resp.get("status") == "OK":
                self.updateCourseMemberStatusResult.emit(True, prettify_message(resp.get("message", "OK")), int(resp.get("course_id", course_id)), int(resp.get("student_id", student_id)), resp.get("member_status", member_status))
            else:
                self.updateCourseMemberStatusResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(course_id), int(student_id), member_status)
        except Exception as e:
            self.updateCourseMemberStatusResult.emit(False, f"NETWORK_ERROR: {e}", int(course_id), int(student_id), member_status)

    # --- Added: student-home signals/slots ---
    @Slot(int)
    def get_student_dashboard(self, student_id):
        threading.Thread(target=self._worker_get_student_dashboard, args=(student_id,), daemon=True).start()

    def _worker_get_student_dashboard(self, student_id):
        try:
            resp = self._client.get_student_dashboard(student_id)
            if resp.get("status") == "OK":
                self.studentDashboardResult.emit(True, "OK", int(resp.get("student_id", student_id)), resp.get("classes", []), resp.get("assignments", []), resp.get("materials", []), resp.get("messages", []))
            else:
                self.studentDashboardResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(student_id), [], [], [], [])
        except Exception as e:
            self.studentDashboardResult.emit(False, f"NETWORK_ERROR: {e}", int(student_id), [], [], [], [])

    @Slot(int, str)
    def join_course_by_code(self, student_id, class_code):
        threading.Thread(target=self._worker_join_course_by_code, args=(student_id, class_code), daemon=True).start()

    def _worker_join_course_by_code(self, student_id, class_code):
        try:
            resp = self._client.join_course_by_code(student_id, class_code)
            if resp.get("status") == "OK":
                self.joinCourseResult.emit(True, prettify_message(resp.get("message", "OK")), int(student_id), class_code)
            else:
                self.joinCourseResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(student_id), class_code)
        except Exception as e:
            self.joinCourseResult.emit(False, f"NETWORK_ERROR: {e}", int(student_id), class_code)

    @Slot(int, int)
    def leave_course(self, student_id, course_id):
        threading.Thread(target=self._worker_leave_course, args=(student_id, course_id), daemon=True).start()

    def _worker_leave_course(self, student_id, course_id):
        try:
            resp = self._client.leave_course(student_id, course_id)
            if resp.get("status") == "OK":
                self.leaveCourseResult.emit(True, prettify_message(resp.get("message", "OK")), int(student_id), int(course_id))
            else:
                self.leaveCourseResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(student_id), int(course_id))
        except Exception as e:
            self.leaveCourseResult.emit(False, f"NETWORK_ERROR: {e}", int(student_id), int(course_id))

    @Slot(int, int)
    def delete_student_submission(self, assignment_id, student_id):
        threading.Thread(target=self._worker_delete_student_submission, args=(assignment_id, student_id), daemon=True).start()

    def _worker_delete_student_submission(self, assignment_id, student_id):
        try:
            resp = self._client.delete_student_submission(assignment_id, student_id)
            if resp.get("status") == "OK":
                self.deleteSubmissionResult.emit(True, prettify_message(resp.get("message", "OK")), int(assignment_id), int(student_id))
            else:
                self.deleteSubmissionResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(assignment_id), int(student_id))
        except Exception as e:
            self.deleteSubmissionResult.emit(False, f"NETWORK_ERROR: {e}", int(assignment_id), int(student_id))

    @Slot(int, int)
    def mark_message_read(self, student_id, message_id):
        threading.Thread(target=self._worker_mark_message_read, args=(student_id, message_id), daemon=True).start()

    def _worker_mark_message_read(self, student_id, message_id):
        try:
            resp = self._client.mark_message_read(student_id, message_id)
            if resp.get("status") == "OK":
                self.markMessageReadResult.emit(True, prettify_message(resp.get("message", "OK")), int(student_id), int(message_id))
            else:
                self.markMessageReadResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(student_id), int(message_id))
        except Exception as e:
            self.markMessageReadResult.emit(False, f"NETWORK_ERROR: {e}", int(student_id), int(message_id))

    @Slot(int)
    def mark_all_messages_read(self, student_id):
        threading.Thread(target=self._worker_mark_all_messages_read, args=(student_id,), daemon=True).start()

    def _worker_mark_all_messages_read(self, student_id):
        try:
            resp = self._client.mark_all_messages_read(student_id)
            if resp.get("status") == "OK":
                self.markAllMessagesReadResult.emit(True, prettify_message(resp.get("message", "OK")), int(student_id))
            else:
                self.markAllMessagesReadResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(student_id))
        except Exception as e:
            self.markAllMessagesReadResult.emit(False, f"NETWORK_ERROR: {e}", int(student_id))

    @Slot(int, int)
    def mark_grade_read(self, student_id, submission_id):
        threading.Thread(target=self._worker_mark_grade_read, args=(student_id, submission_id), daemon=True).start()

    def _worker_mark_grade_read(self, student_id, submission_id):
        try:
            resp = self._client.mark_grade_read(student_id, submission_id)
            if resp.get("status") == "OK":
                self.markGradeReadResult.emit(True, prettify_message(resp.get("message", "OK")), int(student_id), int(submission_id))
            else:
                self.markGradeReadResult.emit(False, prettify_message(resp.get("message", "ERROR")), int(student_id), int(submission_id))
        except Exception as e:
            self.markGradeReadResult.emit(False, f"NETWORK_ERROR: {e}", int(student_id), int(submission_id))


    # --- Added: admin APIs ---
    @Slot()
    def get_admin_overview(self):
        threading.Thread(target=self._worker_get_admin_overview, daemon=True).start()

    def _worker_get_admin_overview(self):
        try:
            resp = self._client.send_request({"type": "GET_ADMIN_OVERVIEW_REQUEST"})
            if resp.get("status") == "OK":
                payload = {
                    "schools": resp.get("schools", []),
                    "users": resp.get("users", []),
                    "courses": resp.get("courses", []),
                    "members": resp.get("members", []),
                    "assignments": resp.get("assignments", []),
                    "submissions": resp.get("submissions", []),
                    "ai_results": resp.get("ai_results", []),
                    "grades": resp.get("grades", []),
                    "feedback": resp.get("feedback", []),
                    "materials": resp.get("materials", []),
                    "messages": resp.get("messages", []),
                    "message_reads": resp.get("message_reads", []),
                    "grade_reads": resp.get("grade_reads", []),
                    "activity": resp.get("activity", []),
                    "system": resp.get("system", []),
                    "stats": resp.get("stats", {})
                }
                self.adminOverviewResult.emit(True, "OK", payload)
            else:
                self.adminOverviewResult.emit(False, prettify_message(resp.get("message", "ERROR")), {})
        except Exception as e:
            self.adminOverviewResult.emit(False, f"NETWORK_ERROR: {e}", {})

    @Slot(str, str, str, str)
    def admin_create_school(self, name, address, contact_name, contact_email):
        threading.Thread(target=self._worker_admin_create_school, args=(name, address, contact_name, contact_email), daemon=True).start()

    def _worker_admin_create_school(self, name, address, contact_name, contact_email):
        self._admin_action("create_school", {"type": "ADMIN_CREATE_SCHOOL_REQUEST", "name": name, "address": address, "contact_name": contact_name, "contact_email": contact_email})

    @Slot(int, str, str, str, str)
    def admin_update_school(self, school_id, name, address, contact_name, contact_email):
        threading.Thread(target=self._worker_admin_update_school, args=(school_id, name, address, contact_name, contact_email), daemon=True).start()

    def _worker_admin_update_school(self, school_id, name, address, contact_name, contact_email):
        self._admin_action("update_school", {"type": "ADMIN_UPDATE_SCHOOL_REQUEST", "school_id": int(school_id), "name": name, "address": address, "contact_name": contact_name, "contact_email": contact_email})

    @Slot(int)
    def admin_delete_school(self, school_id):
        threading.Thread(target=self._worker_admin_delete_school, args=(school_id,), daemon=True).start()

    def _worker_admin_delete_school(self, school_id):
        self._admin_action("delete_school", {"type": "ADMIN_DELETE_SCHOOL_REQUEST", "school_id": int(school_id)})

    @Slot(str, str, str, str, int, str)
    def admin_create_user(self, name, email, password, role, school_id, status):
        threading.Thread(target=self._worker_admin_create_user, args=(name, email, password, role, school_id, status), daemon=True).start()

    def _worker_admin_create_user(self, name, email, password, role, school_id, status):
        password_hash = hashlib.sha256(password.encode("utf-8")).hexdigest()
        self._admin_action("create_user", {"type": "ADMIN_CREATE_USER_REQUEST", "name": name, "email": email.strip().lower(), "password": password_hash, "role": role, "school_id": int(school_id), "status": status})

    @Slot(int, str, str, str, int, str)
    def admin_update_user(self, user_id, name, email, role, school_id, status):
        threading.Thread(target=self._worker_admin_update_user, args=(user_id, name, email, role, school_id, status), daemon=True).start()

    def _worker_admin_update_user(self, user_id, name, email, role, school_id, status):
        self._admin_action("update_user", {"type": "ADMIN_UPDATE_USER_REQUEST", "user_id": int(user_id), "name": name, "email": email.strip().lower(), "role": role, "school_id": int(school_id), "status": status})

    @Slot(int)
    def admin_delete_user(self, user_id):
        threading.Thread(target=self._worker_admin_delete_user, args=(user_id,), daemon=True).start()

    def _worker_admin_delete_user(self, user_id):
        self._admin_action("delete_user", {"type": "ADMIN_DELETE_USER_REQUEST", "user_id": int(user_id)})

    @Slot(int, str, str, int, int)
    def admin_update_course(self, course_id, name, description, teacher_id, school_id):
        threading.Thread(target=self._worker_admin_update_course, args=(course_id, name, description, teacher_id, school_id), daemon=True).start()

    def _worker_admin_update_course(self, course_id, name, description, teacher_id, school_id):
        self._admin_action("update_course", {"type": "ADMIN_UPDATE_COURSE_REQUEST", "course_id": int(course_id), "name": name, "description": description, "teacher_id": int(teacher_id), "school_id": int(school_id)})

    @Slot(int, str, str, str, bool, bool)
    def admin_update_assignment(self, assignment_id, title, description, due_date, ai_enabled, is_closed):
        threading.Thread(target=self._worker_admin_update_assignment, args=(assignment_id, title, description, due_date, ai_enabled, is_closed), daemon=True).start()

    def _worker_admin_update_assignment(self, assignment_id, title, description, due_date, ai_enabled, is_closed):
        self._admin_action("update_assignment", {"type": "ADMIN_UPDATE_ASSIGNMENT_REQUEST", "assignment_id": int(assignment_id), "title": title, "description": description, "due_date": due_date, "ai_enabled": bool(ai_enabled), "is_closed": bool(is_closed)})

    def _admin_action(self, action_name, req):
        try:
            resp = self._client.send_request(req)
            if resp.get("status") == "OK":
                self.adminActionResult.emit(True, prettify_message(resp.get("message", "OK")), action_name)
            else:
                self.adminActionResult.emit(False, prettify_message(resp.get("message", "ERROR")), action_name)
        except Exception as e:
            self.adminActionResult.emit(False, f"NETWORK_ERROR: {e}", action_name)

    @Slot(str)
    def download_file(self, file_path):
        threading.Thread(target=self._worker_download_file, args=(file_path,), daemon=True).start()

    def _worker_download_file(self, file_path):
        try:
            resp, saved_path = self._client.download_file(file_path)
            if resp.get("status") == "OK":
                self.downloadFileResult.emit(True, prettify_message("DOWNLOAD_OK"), file_path, saved_path)
            else:
                self.downloadFileResult.emit(False, prettify_message(resp.get("message", "ERROR")), file_path, "")
        except Exception as e:
            self.downloadFileResult.emit(False, f"NETWORK_ERROR: {e}", file_path, "")

    @Slot(str, str, bool)
    def login(self, email, password, keepsign):
        threading.Thread(target=self._worker_login, args=(email, password, keepsign), daemon=True).start()

    def _worker_login(self, email, password, keepsign):
        try:
            resp = self._client.login(email, password)
            if resp.get("status") == "OK":
                role = resp.get("role", "")
                user_id = int(resp.get("user_id", -1))
                name = resp.get("name", "unknown")
                school_id = int(resp.get("school_id", -1))
                school_name = resp.get("school_name", "")
                school_address = resp.get("school_address", "")
                school_contact_email = resp.get("school_contact_email", "")
                self.loginResult.emit(True, "OK", role, user_id, name, school_id, school_name, school_address, school_contact_email)
            else:
                self.loginResult.emit(False, prettify_message(resp.get("message", "ERROR")), "", -1, "", -1, "", "", "")
        except Exception as e:
            self.loginResult.emit(False, f"NETWORK_ERROR: {e}", "", -1, "", -1, "", "", "")

    @Slot(str, str, str, str, str)
    def signup(self, name, email, password, role, school_id):
        threading.Thread(target=self._worker_signup, args=(name, email, password, role, school_id), daemon=True).start()

    def _worker_signup(self, name, email, password, role, school_id):
        try:
            resp = self._client.signup(name, email, password, role, school_id)
            if resp.get("status") == "OK":
                self.signupResult.emit(True, prettify_message(resp.get("message", "OK")))
            else:
                self.signupResult.emit(False, prettify_message(resp.get("message", "ERROR")))
        except Exception as e:
            self.signupResult.emit(False, f"NETWORK_ERROR: {e}")

    @Slot(int)
    def approve(self, user_id):
        threading.Thread(target=self._worker_approve, args=(user_id,), daemon=True).start()

    def _worker_approve(self, user_id):
        try:
            resp = self._client.approve_user(user_id)
            if resp.get("status") == "OK":
                self.approveResult.emit(True, prettify_message(resp.get("message", "OK")))
            else:
                self.approveResult.emit(False, prettify_message(resp.get("message", "ERROR")))
        except Exception as e:
            self.approveResult.emit(False, f"NETWORK_ERROR: {e}")


def main():
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(":/data/screens/png/AppIcon.png"))
    engine = QQmlApplicationEngine()

    auth = Auth(host="127.0.0.1", port=5555)
    engine.rootContext().setContextProperty("auth", auth)
    engine.load(QUrl("qrc:/main.qml"))

    if not engine.rootObjects():
        print("Failed to load QML (no root objects)")
        return 1

    return app.exec()


if __name__ == "__main__":
    main()
