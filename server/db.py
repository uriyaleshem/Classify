import sqlite3
import random
import string
import re
from datetime import datetime
from pathlib import Path


# --- Added: course/class code helpers ---
def _generate_course_code(length: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return ''.join(random.choices(alphabet, k=length))


def _generate_unique_course_code(conn) -> str:
    cur = conn.cursor()
    while True:
        code = _generate_course_code(6)
        cur.execute("SELECT 1 FROM courses WHERE class_code = ? LIMIT 1", (code,))
        if cur.fetchone() is None:
            return code


def _ensure_course_codes(conn):
    cur = conn.cursor()
    cur.execute("PRAGMA table_info(courses)")
    course_cols = [row[1] for row in cur.fetchall()]
    if "class_code" not in course_cols:
        conn.execute("ALTER TABLE courses ADD COLUMN class_code TEXT")

    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_courses_class_code_unique ON courses(class_code)")

    cur.execute("SELECT course_id FROM courses WHERE class_code IS NULL OR TRIM(class_code) = ''")
    missing_rows = cur.fetchall()
    for (course_id,) in missing_rows:
        code = _generate_unique_course_code(conn)
        conn.execute("UPDATE courses SET class_code = ? WHERE course_id = ?", (code, course_id))

def _conn():
    conn = sqlite3.connect("server_data/classify.db")

    conn.execute("""
        CREATE TABLE IF NOT EXISTS schools (
            school_id     INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT NOT NULL,
            address       TEXT,
            contact_name  TEXT,
            contact_email TEXT,
            created_at    TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT NOT NULL,
            email         TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role          TEXT NOT NULL,
            schoolID      INTEGER NOT NULL,
            status        TEXT NOT NULL,
            created_at    TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS courses (
            course_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            description TEXT,
            teacher_id  INTEGER NOT NULL,
            schoolID    INTEGER NOT NULL,
            created_at  TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS course_members (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id     INTEGER NOT NULL,
            student_id    INTEGER NOT NULL,
            joined_at     TEXT NOT NULL,
            member_status TEXT NOT NULL DEFAULT 'ACTIVE',
            UNIQUE(course_id, student_id)
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS assignments (
            assignment_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id       INTEGER NOT NULL,
            title           TEXT NOT NULL,
            description     TEXT,
            due_date        TEXT,
            attachment_path TEXT,
            ai_enabled      INTEGER NOT NULL DEFAULT 1,
            is_closed       INTEGER NOT NULL DEFAULT 0,
            created_at      TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS submissions (
            submission_id INTEGER PRIMARY KEY AUTOINCREMENT,
            assignment_id INTEGER NOT NULL,
            student_id    INTEGER NOT NULL,
            file_path     TEXT NOT NULL,
            submitted_at  TEXT NOT NULL,
            status        TEXT NOT NULL DEFAULT 'PENDING_AI'
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS ai_results (
            ai_result_id  INTEGER PRIMARY KEY AUTOINCREMENT,
            submission_id INTEGER NOT NULL,
            engine_name   TEXT NOT NULL,
            score         REAL NOT NULL,
            feedback      TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS grades (
            grade_id      INTEGER PRIMARY KEY AUTOINCREMENT,
            submission_id INTEGER NOT NULL UNIQUE,
            ai_score      REAL,
            final_score   REAL,
            updated_by    INTEGER,
            updated_at    TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS feedback (
            feedback_id      INTEGER PRIMARY KEY AUTOINCREMENT,
            submission_id    INTEGER NOT NULL UNIQUE,
            ai_feedback      TEXT,
            teacher_feedback TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS materials (
            material_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id     INTEGER NOT NULL,
            title         TEXT NOT NULL,
            description   TEXT,
            type          TEXT,
            created_by    INTEGER,
            file_path     TEXT,
            created_at    TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            message_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id     INTEGER NOT NULL,
            sender_id     INTEGER,
            subject       TEXT NOT NULL,
            body          TEXT NOT NULL,
            state         TEXT NOT NULL,
            created_at    TEXT NOT NULL
        )
    """)

    # Lightweight migrations for older databases
    cur = conn.cursor()
    _ensure_course_codes(conn)
    cur.execute("PRAGMA table_info(course_members)")
    course_member_cols = [row[1] for row in cur.fetchall()]
    if "member_status" not in course_member_cols:
        conn.execute("ALTER TABLE course_members ADD COLUMN member_status TEXT NOT NULL DEFAULT 'ACTIVE'")
    cur.execute("PRAGMA table_info(assignments)")
    assignment_cols = [row[1] for row in cur.fetchall()]
    if "is_closed" not in assignment_cols:
        conn.execute("ALTER TABLE assignments ADD COLUMN is_closed INTEGER NOT NULL DEFAULT 0")
    if "ai_enabled" not in assignment_cols:
        conn.execute("ALTER TABLE assignments ADD COLUMN ai_enabled INTEGER NOT NULL DEFAULT 1")

    conn.execute("""
        CREATE TABLE IF NOT EXISTS message_reads (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            message_id  INTEGER NOT NULL,
            student_id  INTEGER NOT NULL,
            read_at     TEXT NOT NULL,
            UNIQUE(message_id, student_id)
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS grade_reads (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            submission_id  INTEGER NOT NULL,
            student_id     INTEGER NOT NULL,
            read_at        TEXT NOT NULL,
            UNIQUE(submission_id, student_id)
        )
    """)

    conn.commit()
    return conn


def _normalize_due_date_text(value):
    text = (value or "").strip()
    if not text:
        return ""

    text = text.replace("T", " ")
    text = re.sub(r"\s+", " ", text).strip()

    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", text)
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)} 00:00"

    m = re.match(r"^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})(?::\d{2})?$", text)
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)} {m.group(4)}:{m.group(5)}"

    return text


def _parse_due_datetime(value):
    normalized = _normalize_due_date_text(value)
    if not normalized:
        return None

    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(normalized, fmt)
        except ValueError:
            continue
    return None


def close_expired_assignments(course_id=None, assignment_id=None, conn=None):
    own_conn = conn is None
    conn = conn or _conn()
    try:
        cur = conn.cursor()
        sql = "SELECT assignment_id, due_date, is_closed FROM assignments WHERE 1=1"
        params = []
        if course_id is not None:
            sql += " AND course_id=?"
            params.append(int(course_id))
        if assignment_id is not None:
            sql += " AND assignment_id=?"
            params.append(int(assignment_id))

        cur.execute(sql, params)
        rows = cur.fetchall()
        now = datetime.now()
        changed = False

        for row in rows:
            current_assignment_id = int(row[0])
            due_dt = _parse_due_datetime(row[1])
            is_closed = int(row[2] or 0)
            if due_dt is not None and due_dt <= now and is_closed == 0:
                cur.execute("UPDATE assignments SET is_closed=1 WHERE assignment_id=?", (current_assignment_id,))
                changed = True

        if changed:
            conn.commit()

        return True
    finally:
        if own_conn:
            conn.close()


def _assignment_row_to_dict(row):
    return {
        "assignment_id": int(row[0]),
        "course_id": int(row[1]),
        "title": row[2],
        "description": row[3],
        "due_date": _normalize_due_date_text(row[4]),
        "attachment_path": row[5],
        "ai_enabled": row[6],
        "is_closed": row[7],
        "created_at": row[8]
    }


# ─────────────────────────────────────────────
#  SCHOOLS
# ─────────────────────────────────────────────

def create_school(name: str, address=None, contact_name=None, contact_email=None):
    """יצירת בית ספר חדש. מחזיר (True, school_id) או (False, שגיאה)."""
    conn = _conn()
    try:
        created_at = datetime.now().isoformat(timespec="seconds")
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO schools (name, address, contact_name, contact_email, created_at) VALUES (?, ?, ?, ?, ?)",
            (name, address, contact_name, contact_email, created_at)
        )
        conn.commit()
        return True, cur.lastrowid
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def update_school(school_id: int, name=None, address=None, contact_name=None, contact_email=None):
    """עדכון פרטי בית ספר. רק שדות שאינם None מתעדכנים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        fields, values = [], []
        if name is not None:
            fields.append("name = ?");          values.append(name)
        if address is not None:
            fields.append("address = ?");       values.append(address)
        if contact_name is not None:
            fields.append("contact_name = ?");  values.append(contact_name)
        if contact_email is not None:
            fields.append("contact_email = ?"); values.append(contact_email)
        if not fields:
            return False, "NO_FIELDS_TO_UPDATE"
        values.append(int(school_id))
        cur.execute(f"UPDATE schools SET {', '.join(fields)} WHERE school_id = ?", values)
        conn.commit()
        if cur.rowcount == 0:
            return False, "SCHOOL_NOT_FOUND"
        return True, "SCHOOL_UPDATED"
    finally:
        conn.close()


def get_school(school_id: int):
    """שליפת פרטי בית ספר לפי ID. מחזיר (True, dict) או (False, שגיאה)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT school_id, name, address, contact_name, contact_email FROM schools WHERE school_id = ?",
            (school_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "SCHOOL_NOT_FOUND"
        return True, {"school_id": row[0], "name": row[1], "address": row[2],
                      "contact_name": row[3], "contact_email": row[4]}
    finally:
        conn.close()


def school_exists(school_id: int):
    """בדיקה מהירה האם מזהה בית ספר קיים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM schools WHERE school_id = ? LIMIT 1", (int(school_id),))
        return cur.fetchone() is not None
    finally:
        conn.close()


def get_all_schools():
    """שליפת כל בתי הספר (לשימוש אדמין). מחזיר (True, list)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT school_id, name, address, contact_name, contact_email FROM schools")
        rows = cur.fetchall()
        schools = [{"school_id": r[0], "name": r[1], "address": r[2],
                    "contact_name": r[3], "contact_email": r[4]} for r in rows]
        return True, schools
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  USERS
# ─────────────────────────────────────────────

def signup_user(name, email: str, password_hash: str, role: str, school_id):
    """רישום משתמש חדש. מנהל יוצר בית ספר אוטומטית."""
    conn = _conn()
    email = email.strip().lower()
    created_at = datetime.now().isoformat(timespec="seconds")
    stat = "ACTIVE" if role == "MANAGER" else "PENDING"

    school_id_int = None
    if school_id is not None:
        s = str(school_id).strip()
        if s:
            try:
                school_id_int = int(s)
            except ValueError:
                return False, "INVALID_SCHOOL_ID"

    try:
        if role == "MANAGER":
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO schools (name, address, contact_name, contact_email, created_at) VALUES (?, ?, ?, ?, ?)",
                ("New School", None, name, email, created_at)
            )
            school_id_int = cur.lastrowid
            cur.execute("UPDATE schools SET name=? WHERE school_id=?",
                        (f"School #{school_id_int}", school_id_int))

        if school_id_int is None:
            return False, "SCHOOL_ID_REQUIRED"

        if not school_exists(school_id_int):
            return False, "SCHOOL_NOT_FOUND"

        conn.execute(
            "INSERT INTO users (name, email, password_hash, role, schoolID, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (name, email, password_hash, role, school_id_int, stat, created_at)
        )
        conn.commit()
        return True, "USER_CREATED"
    except sqlite3.IntegrityError:
        return False, "USER_ALREADY_EXISTS"
    finally:
        conn.close()


def login_user(email: str, password_hash: str):
    """התחברות. מחזיר (True, role, user_id, name, school_id, school_name, school_address, school_contact_email)."""
    conn = _conn()

    email = email.strip().lower()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, role, status, name, schoolID FROM users WHERE email=? AND password_hash=?",
            (email, password_hash)
        )
        row = cur.fetchone()
        if not row:
            return False, "INVALID_CREDENTIALS", -1, "", -1, "", "", ""

        user_id, role, status, name, school_id = row
        name = name.split(" ")[0]

        if status == "PENDING":
            return False, "WAITING_APPROVAL", -1, "", -1, "", "", ""
        if status == "BLOCKED":
            return False, "USER_BLOCKED", -1, "", -1, "", "", ""

        school_name = school_address = school_contact_email = ""
        cur.execute("SELECT name, address, contact_email FROM schools WHERE school_id = ?", (school_id,))
        srow = cur.fetchone()
        if srow:
            school_name          = srow[0] or ""
            school_address       = srow[1] or ""
            school_contact_email = srow[2] or ""

        return True, role, user_id, name, school_id, school_name, school_address, school_contact_email
    finally:
        conn.close()


def get_user_context(user_id: int):
    """מחזיר role, school_id, status ושם של משתמש לפי מזהה."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, role, schoolID, status, name, email FROM users WHERE id=?", (int(user_id),))
        row = cur.fetchone()
        if not row:
            return False, "USER_NOT_FOUND"
        return True, {
            "user_id": int(row[0]),
            "role": row[1] or "",
            "school_id": int(row[2]),
            "status": row[3] or "",
            "name": row[4] or "",
            "email": row[5] or "",
        }
    finally:
        conn.close()


def is_teacher_of_course(teacher_id: int, course_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM courses WHERE course_id=? AND teacher_id=?", (int(course_id), int(teacher_id)))
        return cur.fetchone() is not None
    finally:
        conn.close()


def is_course_in_school(course_id: int, school_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM courses WHERE course_id=? AND schoolID=?", (int(course_id), int(school_id)))
        return cur.fetchone() is not None
    finally:
        conn.close()


def get_assignment_course_id(assignment_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM assignments WHERE assignment_id=?", (int(assignment_id),))
        row = cur.fetchone()
        if not row:
            return False, "ASSIGNMENT_NOT_FOUND"
        return True, int(row[0])
    finally:
        conn.close()


def get_submission_course_id(submission_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT a.course_id
            FROM submissions s
            JOIN assignments a ON s.assignment_id = a.assignment_id
            WHERE s.submission_id=?
        """, (int(submission_id),))
        row = cur.fetchone()
        if not row:
            return False, "SUBMISSION_NOT_FOUND"
        return True, int(row[0])
    finally:
        conn.close()


def get_message_course_id(message_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM messages WHERE message_id=?", (int(message_id),))
        row = cur.fetchone()
        if not row:
            return False, "MESSAGE_NOT_FOUND"
        return True, int(row[0])
    finally:
        conn.close()


def get_material_course_id(material_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM materials WHERE material_id=?", (int(material_id),))
        row = cur.fetchone()
        if not row:
            return False, "MATERIAL_NOT_FOUND"
        return True, int(row[0])
    finally:
        conn.close()


def can_user_access_course(user_id: int, role: str, school_id: int, course_id: int):
    role = (role or "").upper()
    if role == "ADMIN":
        return True
    if role == "TEACHER":
        return is_teacher_of_course(user_id, course_id)
    if role == "MANAGER":
        return is_course_in_school(course_id, school_id)
    if role == "STUDENT":
        return is_student_active_in_course(course_id, user_id)
    return False


def can_user_access_file(user_id: int, role: str, school_id: int, file_path: str):
    """בדיקת הרשאה כללית לקובץ לפי הנתיב השמור בשרת."""
    path_text = str(file_path or "")
    course_id = None

    match = re.search(r"course_(\d+)", path_text)
    if match:
        course_id = int(match.group(1))

    if course_id is None:
        return False

    return can_user_access_course(user_id, role, school_id, course_id)


def get_school_users(school_id: int):
    """כל המשתמשים של בית ספר. מחזיר (True, list)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, name, email, role, status FROM users WHERE schoolID = ?",
            (school_id,)
        )
        users = [{"id": r[0], "name": r[1], "email": r[2], "role": r[3], "status": r[4]}
                 for r in cur.fetchall()]
        return True, users
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def approve_user(user_id: int):
    """אישור משתמש ממתין (PENDING → ACTIVE)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE users SET status=? WHERE id=? AND status=?",
                    ("ACTIVE", user_id, "PENDING"))
        conn.commit()
        if cur.rowcount == 0:
            return False, "USER_NOT_FOUND_OR_ALREADY_ACTIVE"
        return True, "USER_APPROVED"
    finally:
        conn.close()


def block_user(user_id: int):
    """חסימת משתמש פעיל (ACTIVE → BLOCKED)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE users SET status=? WHERE id=? AND status=?",
                    ("BLOCKED", user_id, "ACTIVE"))
        conn.commit()
        if cur.rowcount == 0:
            return False, "USER_NOT_FOUND_OR_ALREADY_BLOCKED"
        return True, "USER_BLOCKED"
    finally:
        conn.close()


def unblock_user(user_id: int):
    """ביטול חסימת משתמש (BLOCKED → ACTIVE)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE users SET status=? WHERE id=? AND status=?",
                    ("ACTIVE", user_id, "BLOCKED"))
        conn.commit()
        if cur.rowcount == 0:
            return False, "USER_NOT_FOUND_OR_ALREADY_UNBLOCKED"
        return True, "USER_UNBLOCKED"
    finally:
        conn.close()


def delete_user(user_id: int):
    """מחיקת משתמש לחלוטין מהמערכת."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM users WHERE id=?", (user_id,))
        conn.commit()
        if cur.rowcount == 0:
            return False, "USER_NOT_FOUND"
        return True, "USER_DELETED"
    finally:
        conn.close()


def get_pending_users():
    """כל המשתמשים הממתינים לאישור (id, email, role)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, email, role FROM users WHERE status=?", ("PENDING",))
        return cur.fetchall()
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  COURSES
# ─────────────────────────────────────────────

def create_course(name: str, description: str, teacher_id: int, school_id: int):
    """יצירת קורס חדש. מחזיר (True, course_id) או (False, שגיאה)."""
    conn = _conn()
    try:
        created_at = datetime.now().isoformat(timespec="seconds")
        class_code = _generate_unique_course_code(conn)  # --- Added: real 6-char join code ---
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO courses (name, description, teacher_id, schoolID, created_at, class_code) VALUES (?, ?, ?, ?, ?, ?)",
            (name, description, teacher_id, school_id, created_at, class_code)
        )
        conn.commit()
        return True, cur.lastrowid
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def get_courses_for_teacher(teacher_id: int):
    """כל הקורסים של מורה מסוים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT course_id, name, description, schoolID, created_at, class_code FROM courses WHERE teacher_id=?",
            (teacher_id,)
        )
        courses = [{"course_id": r[0], "name": r[1], "description": r[2],
                    "school_id": r[3], "created_at": r[4], "class_code": r[5] or ""} for r in cur.fetchall()]
        return True, courses
    finally:
        conn.close()


def get_courses_for_student(student_id: int):
    """כל הקורסים הפעילים שתלמיד שויך אליהם."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT c.course_id, c.name, c.description, c.teacher_id, c.created_at, c.class_code
            FROM courses c
            JOIN course_members cm ON c.course_id = cm.course_id
            WHERE cm.student_id = ? AND COALESCE(cm.member_status, 'ACTIVE') = 'ACTIVE'
        """, (student_id,))
        courses = [{"course_id": r[0], "name": r[1], "description": r[2],
                    "teacher_id": r[3], "created_at": r[4], "class_code": r[5] or ""} for r in cur.fetchall()]
        return True, courses
    finally:
        conn.close()

def get_courses_for_school(school_id: int):
    """כל הקורסים של בית ספר (לשימוש מנהל)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT c.course_id, c.name, c.description, c.teacher_id, c.created_at,
                   COUNT(CASE WHEN COALESCE(cm.member_status, 'ACTIVE') = 'ACTIVE' THEN cm.student_id END) as student_count,
                   u.name as teacher_name
            FROM courses c
            LEFT JOIN course_members cm ON c.course_id = cm.course_id
            LEFT JOIN users u ON c.teacher_id = u.id
            WHERE c.schoolID = ?
            GROUP BY c.course_id
        """, (school_id,))
        courses = [{"course_id": r[0], "name": r[1], "description": r[2],
                    "teacher_id": r[3], "created_at": r[4], "students": r[5],
                    "teacher_name": r[6] or "Unknown"}
                   for r in cur.fetchall()]
        return True, courses
    finally:
        conn.close()




def get_course_teacher(course_id: int):
    """מחזיר את מזהה המורה של קורס מסוים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT teacher_id FROM courses WHERE course_id=?", (course_id,))
        row = cur.fetchone()
        if not row:
            return False, "COURSE_NOT_FOUND"
        return True, row[0]
    finally:
        conn.close()


def get_course_school(course_id: int):
    """מחזיר את מזהה בית הספר של קורס מסוים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT schoolID FROM courses WHERE course_id=?", (course_id,))
        row = cur.fetchone()
        if not row:
            return False, "COURSE_NOT_FOUND"
        return True, row[0]
    finally:
        conn.close()

def get_course_file_paths(course_id: int):
    """כל נתיבי הקבצים המשויכים לקורס."""
    conn = _conn()
    try:
        cur = conn.cursor()
        paths = []

        cur.execute("SELECT attachment_path FROM assignments WHERE course_id=? AND attachment_path IS NOT NULL AND attachment_path <> ''", (course_id,))
        paths.extend([row[0] for row in cur.fetchall() if row[0]])

        cur.execute("SELECT file_path FROM materials WHERE course_id=? AND file_path IS NOT NULL AND file_path <> ''", (course_id,))
        paths.extend([row[0] for row in cur.fetchall() if row[0]])

        cur.execute("""
            SELECT s.file_path
            FROM submissions s
            JOIN assignments a ON s.assignment_id = a.assignment_id
            WHERE a.course_id=? AND s.file_path IS NOT NULL AND s.file_path <> ''
        """, (course_id,))
        paths.extend([row[0] for row in cur.fetchall() if row[0]])

        return True, paths
    finally:
        conn.close()


def delete_course(course_id: int):
    """מחיקת קורס וכל המידע המשויך אליו."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM courses WHERE course_id=?", (course_id,))
        if not cur.fetchone():
            return False, "COURSE_NOT_FOUND"

        cur.execute("SELECT assignment_id FROM assignments WHERE course_id=?", (course_id,))
        assignment_ids = [row[0] for row in cur.fetchall()]

        submission_ids = []
        if assignment_ids:
            placeholders = ",".join(["?"] * len(assignment_ids))
            cur.execute(f"SELECT submission_id FROM submissions WHERE assignment_id IN ({placeholders})", assignment_ids)
            submission_ids = [row[0] for row in cur.fetchall()]

        if submission_ids:
            placeholders = ",".join(["?"] * len(submission_ids))
            cur.execute(f"DELETE FROM ai_results WHERE submission_id IN ({placeholders})", submission_ids)
            cur.execute(f"DELETE FROM grades WHERE submission_id IN ({placeholders})", submission_ids)
            cur.execute(f"DELETE FROM feedback WHERE submission_id IN ({placeholders})", submission_ids)
            cur.execute(f"DELETE FROM grade_reads WHERE submission_id IN ({placeholders})", submission_ids)

        if assignment_ids:
            placeholders = ",".join(["?"] * len(assignment_ids))
            cur.execute(f"DELETE FROM submissions WHERE assignment_id IN ({placeholders})", assignment_ids)
            cur.execute(f"DELETE FROM assignments WHERE assignment_id IN ({placeholders})", assignment_ids)

        cur.execute("DELETE FROM message_reads WHERE message_id IN (SELECT message_id FROM messages WHERE course_id=?)", (course_id,))
        cur.execute("DELETE FROM materials WHERE course_id=?", (course_id,))
        cur.execute("DELETE FROM messages WHERE course_id=?", (course_id,))
        cur.execute("DELETE FROM course_members WHERE course_id=?", (course_id,))
        cur.execute("DELETE FROM courses WHERE course_id=?", (course_id,))
        conn.commit()
        return True, "COURSE_DELETED"
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


def get_course(course_id: int):
    """שליפת פרטי קורס לפי ID."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT course_id, name, description, teacher_id, schoolID, created_at FROM courses WHERE course_id=?",
            (course_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "COURSE_NOT_FOUND"
        return True, {
            "course_id": row[0],
            "name": row[1],
            "description": row[2],
            "teacher_id": row[3],
            "school_id": row[4],
            "created_at": row[5]
        }
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  COURSE MEMBERS
# ─────────────────────────────────────────────

def add_student_to_course(course_id: int, student_id: int, member_status: str = "ACTIVE"):
    """שיוך תלמיד לקורס."""
    conn = _conn()
    try:
        joined_at = datetime.now().isoformat(timespec="seconds")
        conn.execute(
            "INSERT OR IGNORE INTO course_members (course_id, student_id, joined_at, member_status) VALUES (?, ?, ?, ?)",
            (course_id, student_id, joined_at, str(member_status or "ACTIVE").upper())
        )
        conn.commit()
        return True, "STUDENT_ADDED"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def remove_student_from_course(course_id: int, student_id: int):
    """הסרת תלמיד מקורס."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM course_members WHERE course_id=? AND student_id=?",
                    (course_id, student_id))
        conn.commit()
        if cur.rowcount == 0:
            return False, "MEMBER_NOT_FOUND"
        return True, "STUDENT_REMOVED"
    finally:
        conn.close()


def delete_course_member(course_id: int, student_id: int):
    """מחיקת בקשת הצטרפות או תלמיד מקורס."""
    return remove_student_from_course(course_id, student_id)


def get_students_in_course(course_id: int):
    """כל התלמידים בקורס מסוים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT u.id, u.name, u.email, COALESCE(cm.member_status, 'ACTIVE'), cm.joined_at
            FROM users u
            JOIN course_members cm ON u.id = cm.student_id
            WHERE cm.course_id = ?
            ORDER BY u.name COLLATE NOCASE
        """, (course_id,))
        students = [{"id": r[0], "name": r[1], "email": r[2], "member_status": r[3], "joined_at": r[4] or ""} for r in cur.fetchall()]
        return True, students
    finally:
        conn.close()


def update_course_member_status(course_id: int, student_id: int, member_status: str):
    """עדכון סטטוס תלמיד בתוך קורס (ACTIVE / INACTIVE / PENDING)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE course_members SET member_status=? WHERE course_id=? AND student_id=?",
            (member_status, course_id, student_id)
        )
        conn.commit()
        if cur.rowcount == 0:
            return False, "MEMBER_NOT_FOUND"
        return True, "MEMBER_STATUS_UPDATED"
    finally:
        conn.close()

def get_course_member_status(course_id: int, student_id: int):
    """מחזיר את סטטוס החברות של תלמיד בכיתה."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT COALESCE(member_status, 'ACTIVE') FROM course_members WHERE course_id=? AND student_id=?",
            (course_id, student_id)
        )
        row = cur.fetchone()
        if not row:
            return False, "MEMBER_NOT_FOUND"
        return True, row[0]
    finally:
        conn.close()


def is_student_active_in_course(course_id: int, student_id: int):
    ok_status, status = get_course_member_status(course_id, student_id)
    if not ok_status:
        return False
    return str(status).upper() == "ACTIVE"


# ─────────────────────────────────────────────
#  ASSIGNMENTS
# ─────────────────────────────────────────────

def create_assignment(course_id: int, title: str, description: str, due_date: str, attachment_path=None, ai_enabled: bool = True):
    """יצירת מטלה חדשה בקורס. מחזיר (True, assignment_id) או (False, שגיאה)."""
    conn = _conn()
    try:
        created_at = datetime.now().isoformat(timespec="seconds")
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO assignments (course_id, title, description, due_date, attachment_path, ai_enabled, is_closed, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (course_id, title, description, due_date, attachment_path, 1 if ai_enabled else 0, 0, created_at)
        )
        conn.commit()
        return True, cur.lastrowid
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def get_assignments_for_course(course_id: int):
    """כל המטלות של קורס מסוים."""
    conn = _conn()
    try:
        close_expired_assignments(course_id=course_id, conn=conn)
        cur = conn.cursor()
        cur.execute(
            "SELECT assignment_id, course_id, title, description, due_date, attachment_path, ai_enabled, is_closed, created_at FROM assignments WHERE course_id=? ORDER BY COALESCE(due_date, created_at), assignment_id",
            (course_id,)
        )
        assignments = [_assignment_row_to_dict(r) for r in cur.fetchall()]
        return True, assignments
    finally:
        conn.close()


def get_assignment(assignment_id: int):
    """שליפת מטלה בודדת לפי ID."""
    conn = _conn()
    try:
        close_expired_assignments(assignment_id=assignment_id, conn=conn)
        cur = conn.cursor()
        cur.execute(
            "SELECT assignment_id, course_id, title, description, due_date, attachment_path, ai_enabled, is_closed, created_at FROM assignments WHERE assignment_id=?",
            (assignment_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "ASSIGNMENT_NOT_FOUND"
        return True, _assignment_row_to_dict(row)
    finally:
        conn.close()


def set_assignment_closed(assignment_id: int, is_closed: bool):
    """עדכון מצב פתוח/סגור של מטלה."""
    conn = _conn()
    try:
        close_expired_assignments(assignment_id=assignment_id, conn=conn)
        cur = conn.cursor()
        cur.execute(
            "SELECT is_closed, due_date FROM assignments WHERE assignment_id=?",
            (assignment_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "ASSIGNMENT_NOT_FOUND"

        due_dt = _parse_due_datetime(row[1])
        if not bool(is_closed) and due_dt is not None and due_dt <= datetime.now():
            return False, "ASSIGNMENT_ALREADY_PAST_DUE"

        cur.execute("UPDATE assignments SET is_closed=? WHERE assignment_id=?", (1 if is_closed else 0, assignment_id))
        conn.commit()
        if cur.rowcount == 0:
            return False, "ASSIGNMENT_NOT_FOUND"
        return True, "ASSIGNMENT_UPDATED"
    finally:
        conn.close()


def delete_assignment(assignment_id: int):
    """מחיקת מטלה וכל המידע המשויך אליה."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT attachment_path FROM assignments WHERE assignment_id=?", (assignment_id,))
        row = cur.fetchone()
        if not row:
            return False, "ASSIGNMENT_NOT_FOUND"
        attachment_path = row[0] or ""

        cur.execute("SELECT submission_id, file_path FROM submissions WHERE assignment_id=?", (assignment_id,))
        submission_rows = cur.fetchall()
        submission_ids = [int(r[0]) for r in submission_rows]
        submission_paths = [r[1] for r in submission_rows if r[1]]

        if submission_ids:
            placeholders = ",".join(["?"] * len(submission_ids))
            cur.execute(f"DELETE FROM ai_results WHERE submission_id IN ({placeholders})", submission_ids)
            cur.execute(f"DELETE FROM grades WHERE submission_id IN ({placeholders})", submission_ids)
            cur.execute(f"DELETE FROM feedback WHERE submission_id IN ({placeholders})", submission_ids)
            cur.execute(f"DELETE FROM grade_reads WHERE submission_id IN ({placeholders})", submission_ids)

        cur.execute("DELETE FROM submissions WHERE assignment_id=?", (assignment_id,))
        cur.execute("DELETE FROM assignments WHERE assignment_id=?", (assignment_id,))
        conn.commit()
        return True, {"message": "ASSIGNMENT_DELETED", "attachment_path": attachment_path, "submission_paths": submission_paths}
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()
def get_assignments_for_school(school_id: int):
    """כל המשימות של בית ספר מסוים (לשימוש מנהל)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM courses WHERE schoolID=?", (school_id,))
        for (course_id,) in cur.fetchall():
            close_expired_assignments(course_id=int(course_id), conn=conn)

        cur.execute("""
            SELECT a.assignment_id, a.title, a.description, a.due_date,
                   c.name as course_name, u.name as teacher_name,
                   COUNT(s.submission_id) as submission_count
            FROM assignments a
            JOIN courses c ON a.course_id = c.course_id
            JOIN users u ON c.teacher_id = u.id
            LEFT JOIN submissions s ON a.assignment_id = s.assignment_id
            WHERE c.schoolID = ?
            GROUP BY a.assignment_id
            ORDER BY COALESCE(a.due_date, a.created_at), a.assignment_id
        """, (school_id,))
        assignments = [
            {
                "assignment_id": r[0],
                "title":         r[1],
                "description":   r[2],
                "due_date":      _normalize_due_date_text(r[3]),
                "course_name":   r[4],
                "teacher_name":  r[5],
                "submission_count": r[6]
            }
            for r in cur.fetchall()
        ]
        return True, assignments
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()

# ─────────────────────────────────────────────
#  SUBMISSIONS
# ─────────────────────────────────────────────

def save_submission(assignment_id: int, student_id: int, file_path: str, status: str = "PENDING_AI"):
    """שמירת הגשה חדשה, תוך החלפת כל הגשה קודמת של אותו תלמיד לאותה מטלה."""
    conn = _conn()
    try:
        submitted_at = datetime.now().isoformat(timespec="seconds")
        cur = conn.cursor()

        cur.execute("""
            SELECT submission_id, file_path
            FROM submissions
            WHERE assignment_id=? AND student_id=?
        """, (int(assignment_id), int(student_id)))
        previous_rows = cur.fetchall()
        previous_ids = [int(r[0]) for r in previous_rows]
        previous_file_paths = [r[1] or "" for r in previous_rows if r[1]]

        if previous_ids:
            placeholders = ",".join(["?"] * len(previous_ids))
            cur.execute(f"DELETE FROM ai_results WHERE submission_id IN ({placeholders})", previous_ids)
            cur.execute(f"DELETE FROM grades WHERE submission_id IN ({placeholders})", previous_ids)
            cur.execute(f"DELETE FROM feedback WHERE submission_id IN ({placeholders})", previous_ids)
            cur.execute(f"DELETE FROM grade_reads WHERE submission_id IN ({placeholders})", previous_ids)
            cur.execute(f"DELETE FROM submissions WHERE submission_id IN ({placeholders})", previous_ids)

        cur.execute(
            "INSERT INTO submissions (assignment_id, student_id, file_path, submitted_at, status) VALUES (?, ?, ?, ?, ?)",
            (assignment_id, student_id, file_path, submitted_at, status)
        )
        conn.commit()
        return True, {"submission_id": int(cur.lastrowid), "replaced_file_paths": previous_file_paths}
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


def get_submissions_for_assignment(assignment_id: int):
    """כל ההגשות למטלה (לשימוש מורה)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT s.submission_id, s.student_id, u.name, s.file_path, s.submitted_at, s.status,
                   g.ai_score, g.final_score
            FROM submissions s
            JOIN users u ON s.student_id = u.id
            LEFT JOIN grades g ON s.submission_id = g.submission_id
            WHERE s.assignment_id = ?
              AND s.submission_id = (
                    SELECT MAX(s2.submission_id)
                    FROM submissions s2
                    WHERE s2.assignment_id = s.assignment_id AND s2.student_id = s.student_id
              )
            ORDER BY s.submitted_at DESC, s.submission_id DESC
        """, (assignment_id,))
        submissions = [{"submission_id": r[0], "student_id": r[1], "student_name": r[2],
                        "file_path": r[3], "submitted_at": r[4], "status": r[5],
                        "ai_score": r[6], "final_score": r[7]}
                       for r in cur.fetchall()]
        return True, submissions
    finally:
        conn.close()


def get_submission(submission_id: int):
    """פרטי הגשה ספציפית."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT submission_id, assignment_id, student_id, file_path, submitted_at, status FROM submissions WHERE submission_id=?",
            (submission_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "SUBMISSION_NOT_FOUND"
        return True, {"submission_id": row[0], "assignment_id": row[1], "student_id": row[2],
                      "file_path": row[3], "submitted_at": row[4], "status": row[5]}
    finally:
        conn.close()


def update_submission_status(submission_id: int, status: str):
    """עדכון סטטוס הגשה (PENDING_AI / AI_DONE / ERROR)."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE submissions SET status=? WHERE submission_id=?", (status, submission_id))
        conn.commit()
        if cur.rowcount == 0:
            return False, "SUBMISSION_NOT_FOUND"
        return True, "STATUS_UPDATED"
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  AI RESULTS
# ─────────────────────────────────────────────

def save_ai_result(submission_id: int, engine_name: str, score: float, feedback: str):
    """שמירת תוצאה ממנוע AI אחד."""
    conn = _conn()
    try:
        conn.execute(
            "INSERT INTO ai_results (submission_id, engine_name, score, feedback) VALUES (?, ?, ?, ?)",
            (submission_id, engine_name, score, feedback)
        )
        conn.commit()
        return True, "AI_RESULT_SAVED"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def get_ai_results(submission_id: int):
    """כל תוצאות ה-AI להגשה מסוימת."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT engine_name, score, feedback FROM ai_results WHERE submission_id=?",
            (submission_id,)
        )
        results = [{"engine": r[0], "score": r[1], "feedback": r[2]} for r in cur.fetchall()]
        return True, results
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  GRADES
# ─────────────────────────────────────────────

def save_grade(submission_id: int, ai_score: float, final_score=None, updated_by=None):
    """שמירת ציון AI ראשוני (ו/או ציון סופי) להגשה."""
    conn = _conn()
    try:
        updated_at = datetime.now().isoformat(timespec="seconds")
        conn.execute("""
            INSERT INTO grades (submission_id, ai_score, final_score, updated_by, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(submission_id) DO UPDATE SET
                ai_score    = excluded.ai_score,
                final_score = excluded.final_score,
                updated_by  = excluded.updated_by,
                updated_at  = excluded.updated_at
        """, (submission_id, ai_score, final_score, updated_by, updated_at))
        conn.commit()
        return True, "GRADE_SAVED"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def update_final_grade(submission_id: int, final_score: float, updated_by: int):
    """עדכון ציון סופי על ידי מורה."""
    conn = _conn()
    try:
        updated_at = datetime.now().isoformat(timespec="seconds")
        cur = conn.cursor()
        cur.execute("""
            UPDATE grades SET final_score=?, updated_by=?, updated_at=?
            WHERE submission_id=?
        """, (final_score, updated_by, updated_at, submission_id))
        conn.commit()
        if cur.rowcount == 0:
            return False, "GRADE_NOT_FOUND"
        return True, "GRADE_UPDATED"
    finally:
        conn.close()


def get_grade(submission_id: int):
    """שליפת ציון להגשה ספציפית."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT ai_score, final_score, updated_by, updated_at FROM grades WHERE submission_id=?",
            (submission_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "GRADE_NOT_FOUND"
        return True, {"ai_score": row[0], "final_score": row[1],
                      "updated_by": row[2], "updated_at": row[3]}
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  FEEDBACK
# ─────────────────────────────────────────────

def save_feedback(submission_id: int, ai_feedback=None, teacher_feedback=None):
    """שמירה/עדכון משוב AI ומשוב מורה."""
    conn = _conn()
    try:
        conn.execute("""
            INSERT INTO feedback (submission_id, ai_feedback, teacher_feedback)
            VALUES (?, ?, ?)
            ON CONFLICT(submission_id) DO UPDATE SET
                ai_feedback      = COALESCE(excluded.ai_feedback,      ai_feedback),
                teacher_feedback = COALESCE(excluded.teacher_feedback, teacher_feedback)
        """, (submission_id, ai_feedback, teacher_feedback))
        conn.commit()
        return True, "FEEDBACK_SAVED"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def get_feedback(submission_id: int):
    """שליפת משוב להגשה ספציפית."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT ai_feedback, teacher_feedback FROM feedback WHERE submission_id=?",
            (submission_id,)
        )
        row = cur.fetchone()
        if not row:
            return False, "FEEDBACK_NOT_FOUND"
        return True, {"ai_feedback": row[0], "teacher_feedback": row[1]}
    finally:
        conn.close()



# ─────────────────────────────────────────────
#  MATERIALS
# ─────────────────────────────────────────────

def create_material(course_id: int, title: str, description: str = "", material_type: str = "FILE", created_by=None, file_path=None):
    """יצירת חומר לימוד לקורס."""
    conn = _conn()
    try:
        created_at = datetime.now().isoformat(timespec="seconds")
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO materials (course_id, title, description, type, created_by, file_path, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (course_id, title, description, material_type, created_by, file_path, created_at)
        )
        conn.commit()
        return True, cur.lastrowid
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def get_materials_for_course(course_id: int):
    """כל חומרי הלימוד של קורס מסוים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT m.material_id, m.course_id, m.title, m.description, m.type,
                   m.created_by, m.file_path, m.created_at,
                   COALESCE(u.name, 'Teacher') as created_by_name
            FROM materials m
            LEFT JOIN users u ON m.created_by = u.id
            WHERE m.course_id=?
            ORDER BY m.created_at DESC
        """, (course_id,))
        materials = [{
            "material_id": r[0],
            "course_id": r[1],
            "title": r[2],
            "description": r[3],
            "type": r[4],
            "created_by": r[5],
            "file_path": r[6],
            "created_at": r[7],
            "created_by_name": r[8]
        } for r in cur.fetchall()]
        return True, materials
    finally:
        conn.close()


def get_material(material_id: int):
    """שליפת חומר לימוד בודד."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT material_id, course_id, title, description, type, created_by, file_path, created_at
            FROM materials
            WHERE material_id=?
        """, (material_id,))
        row = cur.fetchone()
        if not row:
            return False, "MATERIAL_NOT_FOUND"
        return True, {
            "material_id": row[0],
            "course_id": row[1],
            "title": row[2],
            "description": row[3],
            "type": row[4],
            "created_by": row[5],
            "file_path": row[6],
            "created_at": row[7]
        }
    finally:
        conn.close()


def delete_material(material_id: int):
    """מחיקת חומר לימוד."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT file_path, course_id FROM materials WHERE material_id=?", (material_id,))
        row = cur.fetchone()
        if not row:
            return False, "MATERIAL_NOT_FOUND"
        file_path = row[0] or ""
        course_id = int(row[1])
        cur.execute("DELETE FROM materials WHERE material_id=?", (material_id,))
        conn.commit()
        return True, {"message": "MATERIAL_DELETED", "file_path": file_path, "course_id": course_id}
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  MESSAGES
# ─────────────────────────────────────────────

def create_message(course_id: int, sender_id: int, subject: str, body: str, state: str = "sent"):
    """שמירת הודעה/טיוטה לקורס."""
    conn = _conn()
    try:
        created_at = datetime.now().isoformat(timespec="seconds")
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO messages (course_id, sender_id, subject, body, state, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (course_id, sender_id, subject, body, state, created_at)
        )
        conn.commit()
        return True, cur.lastrowid
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def get_messages_for_course(course_id: int):
    """שליפת הודעות של קורס מסוים."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT m.message_id, m.course_id, m.sender_id, m.subject, m.body, m.state, m.created_at,
                   COALESCE(u.name, 'Teacher') as sender_name
            FROM messages m
            LEFT JOIN users u ON m.sender_id = u.id
            WHERE m.course_id=?
            ORDER BY m.created_at DESC
        """, (course_id,))
        messages = [{
            "message_id": r[0],
            "course_id": r[1],
            "sender_id": r[2],
            "subject": r[3],
            "body": r[4],
            "state": r[5],
            "created_at": r[6],
            "sender_name": r[7]
        } for r in cur.fetchall()]
        return True, messages
    finally:
        conn.close()


def delete_message(message_id: int):
    """מחיקת הודעה."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM messages WHERE message_id=?", (message_id,))
        row = cur.fetchone()
        if not row:
            return False, "MESSAGE_NOT_FOUND"
        course_id = int(row[0])
        cur.execute("DELETE FROM message_reads WHERE message_id=?", (message_id,))
        cur.execute("DELETE FROM messages WHERE message_id=?", (message_id,))
        conn.commit()
        return True, {"message": "MESSAGE_DELETED", "course_id": course_id}
    finally:
        conn.close()




# --- Added: student dashboard / read-state helpers ---
def get_student_dashboard(student_id: int):
    """מחזיר את כל הנתונים למסך תלמיד: קורסים, מטלות, חומרים והודעות."""
    ok_courses, courses = get_courses_for_student(student_id)
    if not ok_courses:
        return False, courses

    conn = _conn()
    try:
        cur = conn.cursor()

        course_ids = [int(c["course_id"]) for c in courses]
        class_list = []
        for idx, course in enumerate(courses):
            teacher_name = "Teacher"
            try:
                cur.execute("SELECT name FROM users WHERE id=?", (int(course.get("teacher_id", -1)),))
                row = cur.fetchone()
                if row and row[0]:
                    teacher_name = row[0]
            except Exception:
                pass

            cur.execute("SELECT COUNT(*) FROM course_members WHERE course_id=? AND COALESCE(member_status, 'ACTIVE')='ACTIVE'", (int(course["course_id"]),))
            students_count = cur.fetchone()[0]
            palette = [
                ("#4F46E5", "#EEF2FF", "📘"),
                ("#2563EB", "#DBEAFE", "📗"),
                ("#D97706", "#FEF3C7", "📙"),
                ("#059669", "#D1FAE5", "🧪"),
                ("#7C3AED", "#EDE9FE", "📝"),
            ]
            accent, accent_soft, icon_text = palette[idx % len(palette)]
            class_list.append({
                "classId": int(course["course_id"]),
                "name": course.get("name", "Course"),
                "teacherName": teacher_name,
                "room": "—",
                "description": course.get("description") or "",
                "studentsCount": students_count,
                "code": (course.get("class_code") or ""),  # --- Modified: real stored class code ---
                "accent": accent,
                "accentSoft": accent_soft,
                "iconText": icon_text,
            })

        assignments = []
        materials = []
        messages = []

        if course_ids:
            placeholders = ",".join(["?"] * len(course_ids))

            for course_id in course_ids:
                close_expired_assignments(course_id=int(course_id), conn=conn)

            cur.execute(f"""
                SELECT a.assignment_id, a.course_id, a.title, a.description, a.due_date, a.attachment_path, a.created_at, a.is_closed,
                       s.submission_id, s.file_path, s.submitted_at,
                       g.final_score,
                       f.teacher_feedback,
                       CASE WHEN gr.id IS NULL THEN 0 ELSE 1 END AS grade_read
                FROM assignments a
                LEFT JOIN submissions s ON s.submission_id = (
                    SELECT s2.submission_id
                    FROM submissions s2
                    WHERE s2.assignment_id = a.assignment_id AND s2.student_id = ?
                    ORDER BY s2.submission_id DESC
                    LIMIT 1
                )
                LEFT JOIN grades g ON g.submission_id = s.submission_id
                LEFT JOIN feedback f ON f.submission_id = s.submission_id
                LEFT JOIN grade_reads gr ON gr.submission_id = s.submission_id AND gr.student_id = ?
                WHERE a.course_id IN ({placeholders})
                ORDER BY COALESCE(a.due_date, a.created_at), a.assignment_id
            """, [int(student_id), int(student_id), *course_ids])
            for row in cur.fetchall():
                attachment_name = Path(row[5]).name if row[5] else ""
                submission_name = Path(row[9]).name if row[9] else ""
                assignments.append({
                    "assignmentId": int(row[0]),
                    "classId": int(row[1]),
                    "title": row[2] or "",
                    "description": row[3] or "",
                    "instructions": row[3] or "",
                    "dueText": _normalize_due_date_text(row[4]),
                    "isClosed": bool(row[7]),
                    "submitted": row[8] is not None,
                    "submissionId": int(row[8]) if row[8] is not None else -1,
                    "finalGrade": float(row[11]) if row[11] is not None else -1,
                    "teacherFeedback": row[12] or "",
                    "attachmentName": attachment_name,
                    "attachmentPath": row[5] or "",
                    "submissionFileName": submission_name,
                    "submissionPath": row[9] or "",
                    "submittedAt": (row[10] or "").replace("T", " "),
                    "gradeRead": bool(row[13]),
                    "submissionText": "",
                })

            cur.execute(f"""
                SELECT m.material_id, m.course_id, m.type, m.title, m.description, m.file_path, m.created_at,
                       COALESCE(u.name, 'Teacher')
                FROM materials m
                LEFT JOIN users u ON m.created_by = u.id
                WHERE m.course_id IN ({placeholders})
                ORDER BY m.created_at DESC, m.material_id DESC
            """, course_ids)
            for row in cur.fetchall():
                materials.append({
                    "materialId": int(row[0]),
                    "classId": int(row[1]),
                    "type": row[2] or "FILE",
                    "title": row[3] or "",
                    "byText": row[7] or "Teacher",
                    "description": row[4] or "",
                    "viewText": row[4] or "",
                    "filePath": row[5] or "",
                    "whenText": (row[6] or "").replace("T", " "),
                })

            cur.execute(f"""
                SELECT msg.message_id, msg.course_id, COALESCE(u.name, 'Teacher'), msg.subject, msg.body, msg.created_at,
                       CASE WHEN mr.id IS NULL THEN 0 ELSE 1 END AS is_read
                FROM messages msg
                LEFT JOIN users u ON msg.sender_id = u.id
                LEFT JOIN message_reads mr ON mr.message_id = msg.message_id AND mr.student_id = ?
                WHERE msg.course_id IN ({placeholders}) AND COALESCE(msg.state, 'sent') <> 'draft'
                ORDER BY msg.created_at DESC, msg.message_id DESC
            """, [int(student_id), *course_ids])
            for row in cur.fetchall():
                messages.append({
                    "messageId": int(row[0]),
                    "classId": int(row[1]),
                    "fromText": row[2] or "Teacher",
                    "subject": row[3] or "",
                    "body": row[4] or "",
                    "whenText": (row[5] or "").replace("T", " "),
                    "read": bool(row[6]),
                })

        return True, {
            "classes": class_list,
            "assignments": assignments,
            "materials": materials,
            "messages": messages,
        }
    finally:
        conn.close()


def join_course_by_code(student_id: int, code_value: str):
    text = (code_value or "").strip().upper()
    if not text:
        return False, "INVALID_CLASS_CODE"

    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT course_id FROM courses WHERE UPPER(class_code) = ? LIMIT 1", (text,))
        row = cur.fetchone()

        # --- Added: backward compatibility for old numeric / CLS-0001 style codes ---
        if row is None:
            course_id = None
            if text.startswith("CLS-"):
                try:
                    course_id = int(text.split("-", 1)[1])
                except ValueError:
                    course_id = None
            elif text.isdigit():
                course_id = int(text)

            if course_id is not None:
                cur.execute("SELECT course_id FROM courses WHERE course_id = ? LIMIT 1", (course_id,))
                row = cur.fetchone()

        if row is None:
            return False, "CLASS_NOT_FOUND"

        course_id = int(row[0])

        cur.execute(
            "SELECT COALESCE(member_status, 'ACTIVE') FROM course_members WHERE course_id=? AND student_id=?",
            (course_id, student_id)
        )
        existing = cur.fetchone()
        if existing:
            existing_status = str(existing[0]).upper()
            if existing_status == "INACTIVE":
                return False, "You were blocked from this class. Please contact the class teacher."
            if existing_status == "PENDING":
                return False, "Your join request is already waiting for approval."
            return False, "You are already enrolled in this class."

        return add_student_to_course(course_id, student_id, "PENDING")
    finally:
        conn.close()


def leave_course_for_student(course_id: int, student_id: int):
    return remove_student_from_course(course_id, student_id)


def delete_submission_for_student(assignment_id: int, student_id: int):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT submission_id, file_path
            FROM submissions
            WHERE assignment_id=? AND student_id=?
            ORDER BY submission_id DESC
        """, (assignment_id, student_id))
        rows = cur.fetchall()
        if not rows:
            return False, "SUBMISSION_NOT_FOUND"

        submission_ids = [int(r[0]) for r in rows]
        file_paths = [r[1] or "" for r in rows if r[1]]
        latest_submission_id = submission_ids[0]
        placeholders = ",".join(["?"] * len(submission_ids))
        cur.execute(f"DELETE FROM ai_results WHERE submission_id IN ({placeholders})", submission_ids)
        cur.execute(f"DELETE FROM grades WHERE submission_id IN ({placeholders})", submission_ids)
        cur.execute(f"DELETE FROM feedback WHERE submission_id IN ({placeholders})", submission_ids)
        cur.execute(f"DELETE FROM grade_reads WHERE submission_id IN ({placeholders}) AND student_id=?", [*submission_ids, int(student_id)])
        cur.execute(f"DELETE FROM submissions WHERE submission_id IN ({placeholders})", submission_ids)
        conn.commit()
        return True, {"submission_id": latest_submission_id, "file_paths": file_paths}
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


def mark_message_read(student_id: int, message_id: int):
    conn = _conn()
    try:
        read_at = datetime.now().isoformat(timespec="seconds")
        conn.execute(
            "INSERT INTO message_reads (message_id, student_id, read_at) VALUES (?, ?, ?) ON CONFLICT(message_id, student_id) DO NOTHING",
            (message_id, student_id, read_at)
        )
        conn.commit()
        return True, "MESSAGE_MARKED_READ"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def mark_all_messages_read(student_id: int):
    ok_dash, data = get_student_dashboard(student_id)
    if not ok_dash:
        return False, data
    conn = _conn()
    try:
        read_at = datetime.now().isoformat(timespec="seconds")
        for item in data.get("messages", []):
            conn.execute(
                "INSERT INTO message_reads (message_id, student_id, read_at) VALUES (?, ?, ?) ON CONFLICT(message_id, student_id) DO NOTHING",
                (int(item["messageId"]), int(student_id), read_at)
            )
        conn.commit()
        return True, "ALL_MESSAGES_MARKED_READ"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def mark_grade_read(student_id: int, submission_id: int):
    conn = _conn()
    try:
        read_at = datetime.now().isoformat(timespec="seconds")
        conn.execute(
            "INSERT INTO grade_reads (submission_id, student_id, read_at) VALUES (?, ?, ?) ON CONFLICT(submission_id, student_id) DO NOTHING",
            (submission_id, student_id, read_at)
        )
        conn.commit()
        return True, "GRADE_MARKED_READ"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()

# ─────────────────────────────────────────────
#  STATS (לשימוש מנהל)
# ─────────────────────────────────────────────

def get_school_stats(school_id: int):
    """סטטיסטיקות כלליות לבית ספר: מספר משתמשים, קורסים, הגשות, ממוצע ציון."""
    conn = _conn()
    try:
        cur = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM users WHERE schoolID=? AND role='STUDENT'", (school_id,))
        num_students = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE schoolID=? AND role='TEACHER'", (school_id,))
        num_teachers = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM courses WHERE schoolID=?", (school_id,))
        num_courses = cur.fetchone()[0]

        cur.execute("""
            SELECT COUNT(*) FROM submissions s
            JOIN assignments a ON s.assignment_id = a.assignment_id
            JOIN courses c ON a.course_id = c.course_id
            WHERE c.schoolID=?
        """, (school_id,))
        num_submissions = cur.fetchone()[0]

        cur.execute("""
            SELECT AVG(g.final_score) FROM grades g
            JOIN submissions s ON g.submission_id = s.submission_id
            JOIN assignments a ON s.assignment_id = a.assignment_id
            JOIN courses c ON a.course_id = c.course_id
            WHERE c.schoolID=? AND g.final_score IS NOT NULL
        """, (school_id,))
        avg_grade = cur.fetchone()[0]

        return True, {
            "num_students":    num_students,
            "num_teachers":    num_teachers,
            "num_courses":     num_courses,
            "num_submissions": num_submissions,
            "avg_grade":       round(avg_grade, 1) if avg_grade else None
        }
    finally:
        conn.close()

# ─────────────────────────────────────────────
#  AI WORKER HELPERS
# ─────────────────────────────────────────────

def claim_next_pending_submission():
    """תפיסת ההגשה הממתינה הבאה בצורה אטומית והעברתה ל-AI_IN_PROGRESS."""
    conn = _conn()
    try:
        conn.execute("BEGIN IMMEDIATE")
        cur = conn.cursor()
        cur.execute("""
            SELECT submission_id
            FROM submissions
            WHERE status = 'PENDING_AI'
            ORDER BY submission_id ASC
            LIMIT 1
        """)
        row = cur.fetchone()
        if not row:
            conn.commit()
            return False, "NO_PENDING_SUBMISSIONS"

        submission_id = int(row[0])
        cur.execute(
            "UPDATE submissions SET status=? WHERE submission_id=? AND status='PENDING_AI'",
            ("AI_IN_PROGRESS", submission_id)
        )
        if cur.rowcount == 0:
            conn.rollback()
            return False, "CLAIM_CONFLICT"

        conn.commit()
        return get_submission(submission_id)
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


def list_pending_submission_ids(limit: int = 20):
    """רשימת הגשות ממתינות, ללא תפיסה שלהן לעיבוד."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT submission_id FROM submissions WHERE status='PENDING_AI' ORDER BY submission_id ASC LIMIT ?",
            (int(limit),)
        )
        return True, [int(r[0]) for r in cur.fetchall()]
    finally:
        conn.close()


def reset_in_progress_submissions():
    """מאפס עבודות שנתקעו במצב AI_IN_PROGRESS בחזרה ל-PENDING_AI בעת עליית השרת."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE submissions SET status='PENDING_AI' WHERE status='AI_IN_PROGRESS'")
        conn.commit()
        return True, cur.rowcount
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


def delete_ai_results_for_submission(submission_id: int):
    """ניקוי תוצאות AI קודמות להגשה, לפני ריצה מחדש."""
    conn = _conn()
    try:
        conn.execute("DELETE FROM ai_results WHERE submission_id=?", (submission_id,))
        conn.commit()
        return True, "AI_RESULTS_DELETED"
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  ADMIN HELPERS
# ─────────────────────────────────────────────
def admin_get_overview():
    """Full system snapshot for ADMIN dashboard."""
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT s.school_id, s.name, s.address, s.contact_name, s.contact_email, COALESCE(s.created_at, ''),
                   COUNT(DISTINCT u.id) as users_count,
                   COUNT(DISTINCT c.course_id) as courses_count
            FROM schools s
            LEFT JOIN users u ON s.school_id = u.schoolID
            LEFT JOIN courses c ON s.school_id = c.schoolID
            GROUP BY s.school_id
            ORDER BY s.school_id
        """)
        schools = [{
            "school_id": r[0],
            "name": r[1] or "",
            "address": r[2] or "",
            "contact_name": r[3] or "",
            "contact_email": r[4] or "",
            "created_at": r[5] or "",
            "users_count": int(r[6] or 0),
            "courses_count": int(r[7] or 0)
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT u.id, u.name, u.email, u.role, u.schoolID, u.status, u.created_at,
                   COALESCE(s.name, '') as school_name,
                   COUNT(DISTINCT cm.course_id) as memberships_count
            FROM users u
            LEFT JOIN schools s ON u.schoolID = s.school_id
            LEFT JOIN course_members cm ON u.id = cm.student_id
            GROUP BY u.id
            ORDER BY u.id
        """)
        users = [{
            "id": r[0],
            "name": r[1] or "",
            "email": r[2] or "",
            "role": r[3] or "",
            "school_id": r[4],
            "status": r[5] or "",
            "created_at": r[6] or "",
            "school_name": r[7] or "",
            "memberships_count": int(r[8] or 0)
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT c.course_id, c.name, c.description, c.teacher_id, c.schoolID, c.created_at, c.class_code,
                   COALESCE(u.name, '') as teacher_name, COALESCE(s.name, '') as school_name,
                   COUNT(DISTINCT CASE WHEN COALESCE(cm.member_status, 'ACTIVE') = 'ACTIVE' THEN cm.student_id END) as students,
                   COUNT(DISTINCT a.assignment_id) as assignments_count,
                   COUNT(DISTINCT m.material_id) as materials_count,
                   COUNT(DISTINCT msg.message_id) as messages_count
            FROM courses c
            LEFT JOIN users u ON c.teacher_id = u.id
            LEFT JOIN schools s ON c.schoolID = s.school_id
            LEFT JOIN course_members cm ON c.course_id = cm.course_id
            LEFT JOIN assignments a ON c.course_id = a.course_id
            LEFT JOIN materials m ON c.course_id = m.course_id
            LEFT JOIN messages msg ON c.course_id = msg.course_id
            GROUP BY c.course_id
            ORDER BY c.course_id
        """)
        courses = [{
            "course_id": r[0],
            "name": r[1] or "",
            "description": r[2] or "",
            "teacher_id": r[3],
            "school_id": r[4],
            "created_at": r[5] or "",
            "class_code": r[6] or "",
            "teacher_name": r[7] or "",
            "school_name": r[8] or "",
            "students": int(r[9] or 0),
            "assignments_count": int(r[10] or 0),
            "materials_count": int(r[11] or 0),
            "messages_count": int(r[12] or 0)
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT cm.id, cm.course_id, COALESCE(c.name, '') as course_name, COALESCE(c.class_code, '') as class_code,
                   c.schoolID, COALESCE(s.name, '') as school_name, cm.student_id,
                   COALESCE(u.name, '') as student_name, COALESCE(u.email, '') as student_email,
                   COALESCE(cm.member_status, 'ACTIVE') as member_status, cm.joined_at
            FROM course_members cm
            LEFT JOIN courses c ON cm.course_id = c.course_id
            LEFT JOIN schools s ON c.schoolID = s.school_id
            LEFT JOIN users u ON cm.student_id = u.id
            ORDER BY cm.id
        """)
        members = [{
            "member_id": r[0],
            "course_id": r[1],
            "course_name": r[2] or "",
            "class_code": r[3] or "",
            "school_id": r[4],
            "school_name": r[5] or "",
            "student_id": r[6],
            "student_name": r[7] or "",
            "student_email": r[8] or "",
            "member_status": r[9] or "",
            "joined_at": r[10] or ""
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT a.assignment_id, a.course_id, a.title, a.description, a.due_date, a.attachment_path, a.ai_enabled, a.is_closed, a.created_at,
                   COALESCE(c.name, '') as course_name, COALESCE(u.name, '') as teacher_name,
                   COALESCE(s.name, '') as school_name, c.schoolID,
                   COUNT(DISTINCT sub.submission_id) as submission_count,
                   COUNT(DISTINCT g.grade_id) as graded_count
            FROM assignments a
            LEFT JOIN courses c ON a.course_id = c.course_id
            LEFT JOIN users u ON c.teacher_id = u.id
            LEFT JOIN schools s ON c.schoolID = s.school_id
            LEFT JOIN submissions sub ON a.assignment_id = sub.assignment_id
            LEFT JOIN grades g ON sub.submission_id = g.submission_id
            GROUP BY a.assignment_id
            ORDER BY a.assignment_id
        """)
        assignments = [{
            "assignment_id": r[0],
            "course_id": r[1],
            "title": r[2] or "",
            "description": r[3] or "",
            "due_date": _normalize_due_date_text(r[4]),
            "attachment_path": r[5] or "",
            "ai_enabled": int(r[6] or 0),
            "is_closed": int(r[7] or 0),
            "created_at": r[8] or "",
            "course_name": r[9] or "",
            "teacher_name": r[10] or "",
            "school_name": r[11] or "",
            "school_id": r[12],
            "submission_count": int(r[13] or 0),
            "graded_count": int(r[14] or 0)
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT sub.submission_id, sub.assignment_id, COALESCE(a.title, '') as assignment_title,
                   sub.student_id, COALESCE(u.name, '') as student_name, COALESCE(u.email, '') as student_email,
                   sub.file_path, sub.submitted_at, sub.status,
                   COALESCE(c.course_id, -1) as course_id, COALESCE(c.name, '') as course_name,
                   COALESCE(s.school_id, -1) as school_id, COALESCE(s.name, '') as school_name,
                   g.ai_score, g.final_score, g.updated_at,
                   COUNT(DISTINCT ar.ai_result_id) as ai_results_count
            FROM submissions sub
            LEFT JOIN assignments a ON sub.assignment_id = a.assignment_id
            LEFT JOIN courses c ON a.course_id = c.course_id
            LEFT JOIN schools s ON c.schoolID = s.school_id
            LEFT JOIN users u ON sub.student_id = u.id
            LEFT JOIN grades g ON sub.submission_id = g.submission_id
            LEFT JOIN ai_results ar ON sub.submission_id = ar.submission_id
            GROUP BY sub.submission_id
            ORDER BY sub.submission_id
        """)
        submissions = [{
            "submission_id": r[0],
            "assignment_id": r[1],
            "assignment_title": r[2] or "",
            "student_id": r[3],
            "student_name": r[4] or "",
            "student_email": r[5] or "",
            "file_path": r[6] or "",
            "submitted_at": r[7] or "",
            "status": r[8] or "",
            "course_id": r[9],
            "course_name": r[10] or "",
            "school_id": r[11],
            "school_name": r[12] or "",
            "ai_score": r[13],
            "final_score": r[14],
            "updated_at": r[15] or "",
            "ai_results_count": int(r[16] or 0)
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT ar.ai_result_id, ar.submission_id, ar.engine_name, ar.score, ar.feedback,
                   COALESCE(a.title, '') as assignment_title, COALESCE(c.name, '') as course_name,
                   COALESCE(u.name, '') as student_name
            FROM ai_results ar
            LEFT JOIN submissions sub ON ar.submission_id = sub.submission_id
            LEFT JOIN assignments a ON sub.assignment_id = a.assignment_id
            LEFT JOIN courses c ON a.course_id = c.course_id
            LEFT JOIN users u ON sub.student_id = u.id
            ORDER BY ar.ai_result_id
        """)
        ai_results = [{
            "ai_result_id": r[0],
            "submission_id": r[1],
            "engine_name": r[2] or "",
            "score": r[3],
            "feedback": r[4] or "",
            "assignment_title": r[5] or "",
            "course_name": r[6] or "",
            "student_name": r[7] or ""
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT g.grade_id, g.submission_id, g.ai_score, g.final_score, g.updated_by,
                   COALESCE(editor.name, '') as updated_by_name, g.updated_at,
                   COALESCE(a.title, '') as assignment_title, COALESCE(c.name, '') as course_name,
                   COALESCE(student.name, '') as student_name
            FROM grades g
            LEFT JOIN submissions sub ON g.submission_id = sub.submission_id
            LEFT JOIN assignments a ON sub.assignment_id = a.assignment_id
            LEFT JOIN courses c ON a.course_id = c.course_id
            LEFT JOIN users student ON sub.student_id = student.id
            LEFT JOIN users editor ON g.updated_by = editor.id
            ORDER BY g.grade_id
        """)
        grades = [{
            "grade_id": r[0],
            "submission_id": r[1],
            "ai_score": r[2],
            "final_score": r[3],
            "updated_by": r[4],
            "updated_by_name": r[5] or "",
            "updated_at": r[6] or "",
            "assignment_title": r[7] or "",
            "course_name": r[8] or "",
            "student_name": r[9] or ""
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT f.feedback_id, f.submission_id, f.ai_feedback, f.teacher_feedback,
                   COALESCE(a.title, '') as assignment_title, COALESCE(c.name, '') as course_name,
                   COALESCE(u.name, '') as student_name
            FROM feedback f
            LEFT JOIN submissions sub ON f.submission_id = sub.submission_id
            LEFT JOIN assignments a ON sub.assignment_id = a.assignment_id
            LEFT JOIN courses c ON a.course_id = c.course_id
            LEFT JOIN users u ON sub.student_id = u.id
            ORDER BY f.feedback_id
        """)
        feedback = [{
            "feedback_id": r[0],
            "submission_id": r[1],
            "ai_feedback": r[2] or "",
            "teacher_feedback": r[3] or "",
            "assignment_title": r[4] or "",
            "course_name": r[5] or "",
            "student_name": r[6] or ""
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT m.material_id, m.course_id, COALESCE(c.name, '') as course_name,
                   COALESCE(s.name, '') as school_name, m.title, m.description, m.type,
                   m.created_by, COALESCE(u.name, '') as created_by_name,
                   m.file_path, m.created_at
            FROM materials m
            LEFT JOIN courses c ON m.course_id = c.course_id
            LEFT JOIN schools s ON c.schoolID = s.school_id
            LEFT JOIN users u ON m.created_by = u.id
            ORDER BY m.material_id
        """)
        materials = [{
            "material_id": r[0],
            "course_id": r[1],
            "course_name": r[2] or "",
            "school_name": r[3] or "",
            "title": r[4] or "",
            "description": r[5] or "",
            "type": r[6] or "",
            "created_by": r[7],
            "created_by_name": r[8] or "",
            "file_path": r[9] or "",
            "created_at": r[10] or ""
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT msg.message_id, msg.course_id, COALESCE(c.name, '') as course_name,
                   COALESCE(s.name, '') as school_name, msg.sender_id,
                   COALESCE(u.name, '') as sender_name, msg.subject, msg.body,
                   msg.state, msg.created_at, COUNT(mr.id) as read_count
            FROM messages msg
            LEFT JOIN courses c ON msg.course_id = c.course_id
            LEFT JOIN schools s ON c.schoolID = s.school_id
            LEFT JOIN users u ON msg.sender_id = u.id
            LEFT JOIN message_reads mr ON msg.message_id = mr.message_id
            GROUP BY msg.message_id
            ORDER BY msg.message_id
        """)
        messages = [{
            "message_id": r[0],
            "course_id": r[1],
            "course_name": r[2] or "",
            "school_name": r[3] or "",
            "sender_id": r[4],
            "sender_name": r[5] or "",
            "subject": r[6] or "",
            "body": r[7] or "",
            "state": r[8] or "",
            "created_at": r[9] or "",
            "read_count": int(r[10] or 0)
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT mr.id, mr.message_id, COALESCE(msg.subject, '') as message_subject,
                   mr.student_id, COALESCE(u.name, '') as student_name,
                   COALESCE(c.name, '') as course_name, mr.read_at
            FROM message_reads mr
            LEFT JOIN messages msg ON mr.message_id = msg.message_id
            LEFT JOIN courses c ON msg.course_id = c.course_id
            LEFT JOIN users u ON mr.student_id = u.id
            ORDER BY mr.id
        """)
        message_reads = [{
            "read_id": r[0],
            "message_id": r[1],
            "message_subject": r[2] or "",
            "student_id": r[3],
            "student_name": r[4] or "",
            "course_name": r[5] or "",
            "read_at": r[6] or ""
        } for r in cur.fetchall()]

        cur.execute("""
            SELECT gr.id, gr.submission_id, COALESCE(a.title, '') as assignment_title,
                   gr.student_id, COALESCE(u.name, '') as student_name,
                   COALESCE(c.name, '') as course_name, gr.read_at
            FROM grade_reads gr
            LEFT JOIN submissions sub ON gr.submission_id = sub.submission_id
            LEFT JOIN assignments a ON sub.assignment_id = a.assignment_id
            LEFT JOIN courses c ON a.course_id = c.course_id
            LEFT JOIN users u ON gr.student_id = u.id
            ORDER BY gr.id
        """)
        grade_reads = [{
            "read_id": r[0],
            "submission_id": r[1],
            "assignment_title": r[2] or "",
            "student_id": r[3],
            "student_name": r[4] or "",
            "course_name": r[5] or "",
            "read_at": r[6] or ""
        } for r in cur.fetchall()]

        def table_count(table_name):
            cur.execute(f"SELECT COUNT(*) FROM {table_name}")
            return int(cur.fetchone()[0] or 0)

        def grouped_counts(table_name, column_name):
            cur.execute(f"SELECT COALESCE({column_name}, ''), COUNT(*) FROM {table_name} GROUP BY {column_name}")
            return {str(row[0] or "UNKNOWN"): int(row[1] or 0) for row in cur.fetchall()}

        db_path = Path("server_data/classify.db")
        storage_root = Path("server_storage")
        storage_file_count = 0
        storage_size_bytes = 0
        if storage_root.exists():
            for file_path in storage_root.rglob("*"):
                if file_path.is_file():
                    storage_file_count += 1
                    storage_size_bytes += file_path.stat().st_size

        activity = []
        for row in users:
            activity.append({"type": "User", "title": row["name"], "detail": row["email"], "at": row["created_at"]})
        for row in courses:
            activity.append({"type": "Course", "title": row["name"], "detail": row["school_name"], "at": row["created_at"]})
        for row in assignments:
            activity.append({"type": "Assignment", "title": row["title"], "detail": row["course_name"], "at": row["created_at"]})
        for row in submissions:
            activity.append({"type": "Submission", "title": row["student_name"], "detail": row["assignment_title"], "at": row["submitted_at"]})
        for row in materials:
            activity.append({"type": "Material", "title": row["title"], "detail": row["course_name"], "at": row["created_at"]})
        activity = sorted([item for item in activity if item.get("at")], key=lambda item: item["at"], reverse=True)[:60]

        stats = {
            "counts": {
                "schools": table_count("schools"),
                "users": table_count("users"),
                "courses": table_count("courses"),
                "course_members": table_count("course_members"),
                "assignments": table_count("assignments"),
                "submissions": table_count("submissions"),
                "ai_results": table_count("ai_results"),
                "grades": table_count("grades"),
                "feedback": table_count("feedback"),
                "materials": table_count("materials"),
                "messages": table_count("messages"),
                "message_reads": table_count("message_reads"),
                "grade_reads": table_count("grade_reads")
            },
            "users_by_role": grouped_counts("users", "role"),
            "users_by_status": grouped_counts("users", "status"),
            "submissions_by_status": grouped_counts("submissions", "status"),
            "system": {
                "db_size_bytes": db_path.stat().st_size if db_path.exists() else 0,
                "storage_file_count": storage_file_count,
                "storage_size_bytes": storage_size_bytes
            }
        }

        system_rows = [
            {"metric": "Database file", "value": str(stats["system"]["db_size_bytes"]), "unit": "bytes", "source": str(db_path)},
            {"metric": "Storage files", "value": str(storage_file_count), "unit": "files", "source": str(storage_root)},
            {"metric": "Storage size", "value": str(storage_size_bytes), "unit": "bytes", "source": str(storage_root)}
        ]

        return True, {
            "schools": schools,
            "users": users,
            "courses": courses,
            "members": members,
            "assignments": assignments,
            "submissions": submissions,
            "ai_results": ai_results,
            "grades": grades,
            "feedback": feedback,
            "materials": materials,
            "messages": messages,
            "message_reads": message_reads,
            "grade_reads": grade_reads,
            "activity": activity,
            "system": system_rows,
            "stats": stats
        }
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def admin_create_user(name, email, password_hash, role, school_id, status="ACTIVE"):
    conn = _conn()
    try:
        role = (role or "").upper().strip()
        status = (status or "ACTIVE").upper().strip()
        if role not in {"ADMIN", "MANAGER", "TEACHER", "STUDENT"}:
            return False, "INVALID_ROLE"
        if status not in {"ACTIVE", "PENDING", "BLOCKED"}:
            return False, "INVALID_STATUS"
        if role != "ADMIN" and not school_exists(int(school_id)):
            return False, "SCHOOL_NOT_FOUND"
        conn.execute("INSERT INTO users (name, email, password_hash, role, schoolID, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                     (name, email.strip().lower(), password_hash, role, int(school_id), status, datetime.now().isoformat(timespec="seconds")))
        conn.commit()
        return True, "USER_CREATED"
    except sqlite3.IntegrityError:
        return False, "USER_ALREADY_EXISTS"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def admin_update_user(user_id, name, email, role, school_id, status):
    conn = _conn()
    try:
        role = (role or "").upper().strip()
        status = (status or "").upper().strip()
        if role not in {"ADMIN", "MANAGER", "TEACHER", "STUDENT"}:
            return False, "INVALID_ROLE"
        if status not in {"ACTIVE", "PENDING", "BLOCKED"}:
            return False, "INVALID_STATUS"
        if role != "ADMIN" and not school_exists(int(school_id)):
            return False, "SCHOOL_NOT_FOUND"
        cur = conn.cursor()
        cur.execute("UPDATE users SET name=?, email=?, role=?, schoolID=?, status=? WHERE id=?", (name, email.strip().lower(), role, int(school_id), status, int(user_id)))
        conn.commit()
        if cur.rowcount == 0:
            return False, "USER_NOT_FOUND"
        return True, "USER_UPDATED"
    except sqlite3.IntegrityError:
        return False, "USER_ALREADY_EXISTS"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def admin_delete_school(school_id):
    conn = _conn()
    try:
        cur = conn.cursor()
        sid = int(school_id)
        cur.execute("SELECT course_id FROM courses WHERE schoolID=?", (sid,))
        course_ids = [int(r[0]) for r in cur.fetchall()]
        for cid in course_ids:
            delete_course(cid)
        cur.execute("DELETE FROM users WHERE schoolID=?", (sid,))
        cur.execute("DELETE FROM schools WHERE school_id=?", (sid,))
        conn.commit()
        if cur.rowcount == 0:
            return False, "SCHOOL_NOT_FOUND"
        return True, "SCHOOL_DELETED"
    except sqlite3.Error as e:
        conn.rollback()
        return False, str(e)
    finally:
        conn.close()


def admin_update_course(course_id, name, description, teacher_id, school_id):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT role, schoolID FROM users WHERE id=?", (int(teacher_id),))
        row = cur.fetchone()
        if not row or (row[0] or "").upper() not in {"TEACHER", "ADMIN"}:
            return False, "TEACHER_NOT_FOUND"
        cur.execute("UPDATE courses SET name=?, description=?, teacher_id=?, schoolID=? WHERE course_id=?", (name, description, int(teacher_id), int(school_id), int(course_id)))
        conn.commit()
        if cur.rowcount == 0:
            return False, "COURSE_NOT_FOUND"
        return True, "COURSE_UPDATED"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


def admin_update_assignment(assignment_id, title, description, due_date, ai_enabled, is_closed):
    conn = _conn()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE assignments SET title=?, description=?, due_date=?, ai_enabled=?, is_closed=? WHERE assignment_id=?",
                    (title, description, _normalize_due_date_text(due_date), 1 if ai_enabled else 0, 1 if is_closed else 0, int(assignment_id)))
        conn.commit()
        if cur.rowcount == 0:
            return False, "ASSIGNMENT_NOT_FOUND"
        return True, "ASSIGNMENT_UPDATED"
    except sqlite3.Error as e:
        return False, str(e)
    finally:
        conn.close()


