# Classify

Classify is a desktop school management and assignment review system. It includes a PySide6/QML client, a Python TCP server, SQLite persistence, file storage for assignments and submissions, and an optional AI grading worker.

## Main Features

- Role-based login for students, teachers, managers, and admins.
- School, user, course, assignment, material, and message management.
- Student dashboard for joining classes, viewing assignments, submitting work, and reading grades.
- Teacher dashboard for creating assignments, reviewing submissions, and saving final grades.
- Admin dashboard for managing schools, users, courses, and assignments.
- File upload/download support with a 25 MB limit.
- AI-assisted grading for text, documents, code files, and archives such as ZIP, TAR, RAR, and 7Z.
- Hebrew-aware teacher feedback formatting, including right-to-left display when Hebrew content is detected.
- Encrypted client-server traffic using Diffie-Hellman key exchange and AES-GCM.

## Project Structure

```text
Classify_Client.py      PySide6 desktop client and QML bridge
Classify_Server.py      TCP server, request routing, auth, file storage, and AI worker startup
AI_Grader.py            AI grading providers, archive/text extraction, result merging, feedback formatting
db.py                   SQLite schema, migrations, and data access functions
DH.py                   Diffie-Hellman handshake helpers
AES_e.py                AES-GCM encryption helpers
tcp_by_size.py          Length-prefixed TCP send/receive helpers
main.qml                Main QML application window
data/screens/           QML screens and UI assets
server_data/            Runtime database and server logs
server_storage/         Uploaded assignment files, materials, and submissions
```

## Requirements

- Python 3.10 or newer
- Windows is the primary development target
- PySide6
- cryptography
- Optional AI SDKs, depending on the providers you want to use:
  - openai
  - anthropic
  - google-genai
- Optional document/archive helpers:
  - pypdf or PyPDF2
  - rarfile
  - py7zr
  - 7-Zip, UnRAR, or a compatible `tar` tool for external archive extraction

## Setup

Create and activate a virtual environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install the core dependencies:

```powershell
pip install PySide6 cryptography python-dotenv
```

Install optional AI and file extraction dependencies:

```powershell
pip install openai anthropic google-genai pypdf PyPDF2 rarfile py7zr
```

## Environment Variables

The AI grader reads environment variables from the process environment and from a local `.env` file when present.

Example `.env`:

```env
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
GEMINI_API_KEY=your_gemini_key

AI_GRADING_PROVIDERS=openai
OPENAI_GRADING_MODEL=gpt-5.4-mini
ANTHROPIC_GRADING_MODEL=claude-haiku-4-5
GEMINI_GRADING_MODEL=gemini-3-flash-preview
AI_SUMMARIZER_PROVIDER=openai
```

By default, `AI_GRADING_PROVIDERS` is `openai`. If no provider is configured, the server still runs, but AI grading will remain unavailable until a provider SDK and API key are configured.

## Running the App

Start the server first:

```powershell
python Classify_Server.py
```

The server listens on:

```text
0.0.0.0:5555
```

Then start the desktop client:

```powershell
python Classify_Client.py
```

The client connects to:

```text
127.0.0.1:5555
```

## Data and Storage

Runtime data is stored locally:

- `server_data/classify.db` stores application data in SQLite.
- `server_data/server_log.txt` stores request/response logs.
- `server_storage/` stores uploaded rubrics, materials, submissions, and demo files.

These files can change during normal app usage. Be careful before committing database, log, or uploaded submission changes.

## AI Grading Flow

1. A teacher creates an AI-enabled assignment and attaches rubric/instruction material.
2. A student submits text and/or a file.
3. The server marks the submission as pending AI review.
4. The AI worker extracts readable content from the submission.
5. One or more AI providers grade the work.
6. The system stores the AI score, concise feedback, and provider results.
7. The teacher can review the AI feedback and save a final grade.

Supported readable inputs include common text/code files, PDF, DOCX, PPTX, XLSX, ZIP, TAR, RAR, and 7Z. Binary files are detected and summarized when text cannot be extracted.

## Security Notes

- Client-server messages are encrypted after a Diffie-Hellman handshake.
- The server does not keep long-lived socket sessions for login state.
- Authenticated requests include a signed auth token issued at login.
- Passwords are hashed on the client before being sent to the server.
- Server logs redact sensitive fields such as passwords, tokens, and uploaded file contents.
- Failed login attempts are rate-limited per source IP. Defaults: 20 failed attempts within 15 minutes blocks that source for 30 minutes. Override with `CLASSIFY_MAX_FAILED_LOGIN_ATTEMPTS`, `CLASSIFY_FAILED_LOGIN_WINDOW_SECONDS`, and `CLASSIFY_LOGIN_BLOCK_SECONDS`.
- Uploaded files are scanned on the server before they are saved to `server_storage/`. The server auto-detects ClamAV (`clamdscan`/`clamscan`) or Microsoft Defender on Windows. If no scanner is available, uploads fail closed with `FILE_SCAN_UNAVAILABLE`; set `CLASSIFY_AV_SCAN_COMMAND` for a custom scanner command using `{path}`, `CLASSIFY_AV_SCAN_ENABLED=0` for local-only development, or `CLASSIFY_AV_FAIL_OPEN=1` to allow uploads when scanning is unavailable.
