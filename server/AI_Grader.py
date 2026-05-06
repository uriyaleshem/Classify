import json
import io
import html
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import time
import zipfile
from pathlib import Path, PurePosixPath
from statistics import median
from typing import Any, Dict, List, Optional, Tuple

import db

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass


SUPPORTED_TEXT_EXTENSIONS = {
    ".txt", ".md", ".csv", ".json", ".jsonl", ".log", ".html", ".htm", ".xml",
    ".py", ".pyw", ".cs", ".java", ".js", ".jsx", ".ts", ".tsx", ".c", ".h",
    ".cpp", ".cc", ".cxx", ".hpp", ".hh", ".rs", ".go", ".php", ".rb", ".swift",
    ".kt", ".kts", ".dart", ".scala", ".sql", ".r", ".m", ".mm", ".pl", ".lua",
    ".sh", ".bash", ".zsh", ".bat", ".cmd", ".ps1", ".psm1", ".qml", ".xaml",
    ".css", ".scss", ".sass", ".less", ".vue", ".svelte", ".yaml", ".yml", ".toml",
    ".ini", ".cfg", ".conf", ".properties", ".gradle", ".csproj", ".sln", ".vb",
}
ARCHIVE_EXTENSIONS = {
    ".zip", ".jar", ".war", ".ear", ".tar", ".tgz", ".tbz", ".tbz2", ".txz",
    ".tar.gz", ".tar.bz2", ".tar.xz", ".rar", ".7z",
}
BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tif", ".tiff", ".ico",
    ".mp3", ".wav", ".ogg", ".mp4", ".mov", ".avi", ".mkv", ".webm",
    ".exe", ".dll", ".so", ".dylib", ".class", ".o", ".obj", ".bin", ".dat",
}

POLL_INTERVAL_SECONDS = int(os.getenv("AI_GRADER_POLL_INTERVAL", "10"))
MAX_TEXT_CHARS = int(os.getenv("AI_GRADER_MAX_TEXT_CHARS", "50000"))
MAX_FEEDBACK_LINE_CHARS = int(os.getenv("AI_GRADER_MAX_FEEDBACK_LINE_CHARS", "170"))
MAX_ARCHIVE_FILES = int(os.getenv("AI_GRADER_MAX_ARCHIVE_FILES", "80"))
MAX_ARCHIVE_MEMBER_BYTES = int(os.getenv("AI_GRADER_MAX_ARCHIVE_MEMBER_BYTES", str(3 * 1024 * 1024)))
MAX_ARCHIVE_TOTAL_BYTES = int(os.getenv("AI_GRADER_MAX_ARCHIVE_TOTAL_BYTES", str(18 * 1024 * 1024)))
ARCHIVE_TOOL_TIMEOUT_SECONDS = int(os.getenv("AI_GRADER_ARCHIVE_TOOL_TIMEOUT", "20"))
DEFAULT_OPENAI_MODEL = os.getenv("OPENAI_GRADING_MODEL", "gpt-5.4-mini")
DEFAULT_ANTHROPIC_MODEL = os.getenv("ANTHROPIC_GRADING_MODEL", "claude-haiku-4-5")
DEFAULT_GEMINI_MODEL = os.getenv("GEMINI_GRADING_MODEL", "gemini-3-flash-preview")
DEFAULT_SUMMARIZER_PROVIDER = os.getenv("AI_SUMMARIZER_PROVIDER", "openai").strip().lower()
DEFAULT_SUMMARIZER_MODEL = os.getenv("AI_SUMMARIZER_MODEL", "")

# Comma-separated list, for example: openai,anthropic,gemini
ENABLED_PROVIDER_NAMES = [
    item.strip().lower()
    for item in os.getenv("AI_GRADING_PROVIDERS", "openai").split(",")
    if item.strip()
]

HEBREW_RE = re.compile(r"[\u0590-\u05FF]")
RTL_EMBED = "\u202B"
POP_DIRECTIONAL = "\u202C"
LRM = "\u200E"


class GraderProvider:
    name = "base"

    def is_available(self) -> bool:
        raise NotImplementedError

    def grade(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        raise NotImplementedError


class OpenAIGraderProvider(GraderProvider):
    name = "openai"

    def __init__(self, model: Optional[str] = None):
        self.api_key = os.getenv("OPENAI_API_KEY", "").strip()
        self.model = model or DEFAULT_OPENAI_MODEL
        self.client = None

        if self.api_key:
            try:
                from openai import OpenAI
                self.client = OpenAI(api_key=self.api_key)
            except Exception:
                self.client = None

    def is_available(self) -> bool:
        return self.client is not None

    def grade(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.client:
            raise RuntimeError("OpenAI provider is not available")

        schema = build_grading_schema()
        prompt = build_grading_prompt(payload)

        response = self.client.responses.create(
            model=self.model,
            input=[
                {
                    "role": "system",
                    "content": [
                        {
                            "type": "input_text",
                            "text": (
                                "You are a fair, teacher-friendly school assignment grader. "
                                "Grade only according to the rubric and assignment instructions. "
                                "Give partial credit generously for equivalent correct work, and deduct "
                                "points only for clear rubric misses or explicit instruction violations. "
                                "Return only valid JSON that matches the requested schema."
                            ),
                        }
                    ],
                },
                {
                    "role": "user",
                    "content": [{"type": "input_text", "text": prompt}],
                },
            ],
            text={
                "format": {
                    "type": "json_schema",
                    "name": schema["name"],
                    "schema": schema["schema"],
                    "strict": True,
                }
            },
        )

        raw_text = extract_openai_response_text(response)
        data = parse_provider_json(raw_text)
        data["engine_name"] = f"openai:{self.model}"
        return normalize_grading_result(data)


class AnthropicGraderProvider(GraderProvider):
    name = "anthropic"

    def __init__(self, model: Optional[str] = None):
        self.api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
        self.model = model or DEFAULT_ANTHROPIC_MODEL
        self.client = None

        if self.api_key:
            try:
                from anthropic import Anthropic
                self.client = Anthropic(api_key=self.api_key)
            except Exception:
                self.client = None

    def is_available(self) -> bool:
        return self.client is not None

    def grade(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.client:
            raise RuntimeError("Anthropic provider is not available")

        prompt = build_grading_prompt(payload)
        response = self.client.messages.create(
            model=self.model,
            max_tokens=2500,
            system=(
                "You are a fair, teacher-friendly school assignment grader. "
                "Grade only according to the rubric and assignment instructions. "
                "Give partial credit generously for equivalent correct work, and deduct "
                "points only for clear rubric misses or explicit instruction violations. "
                "Return JSON only, with no markdown fences and no extra commentary."
            ),
            messages=[
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
        )

        raw_text = extract_anthropic_text(response)
        print("[DEBUG][antrophic RAW]", raw_text)
        data = parse_provider_json(raw_text)
        data["engine_name"] = f"anthropic:{self.model}"
        return normalize_grading_result(data)


class GeminiGraderProvider(GraderProvider):
    name = "gemini"

    def __init__(self, model: Optional[str] = None):
        self.api_key = os.getenv("GEMINI_API_KEY", "").strip()
        self.model = model or DEFAULT_GEMINI_MODEL
        self.client = None

        if self.api_key:
            try:
                from google import genai
                self._genai_module = genai
                self.client = genai.Client(api_key=self.api_key)
            except Exception:
                self.client = None

    def is_available(self) -> bool:
        return self.client is not None

    def grade(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.client:
            raise RuntimeError("Gemini provider is not available")

        prompt = build_grading_prompt(payload)

        config = {
            "response_mime_type": "application/json",
            "temperature": 0.2,
        }

        response = self.client.models.generate_content(
            model=self.model,
            contents=prompt,
            config=config,
        )

        raw_text = extract_gemini_text(response)
        print("[DEBUG][GEMINI RAW]", raw_text)
        data = parse_provider_json(raw_text)
        data["engine_name"] = f"gemini:{self.model}"
        return normalize_grading_result(data)


class ProviderRegistry:
    def __init__(self):
        self.providers: Dict[str, GraderProvider] = {}

    def register(self, provider: GraderProvider):
        self.providers[provider.name] = provider

    def get_available(self, names: List[str]) -> List[GraderProvider]:
        available = []
        for name in names:
            provider = self.providers.get(name)
            if provider and provider.is_available():
                available.append(provider)
        return available

    def get_first_available(self, preferred_name: str) -> Optional[GraderProvider]:
        provider = self.providers.get(preferred_name)
        if provider and provider.is_available():
            return provider
        for item in self.providers.values():
            if item.is_available():
                return item
        return None


def build_grading_schema() -> Dict[str, Any]:
    return {
        "name": "grading_result",
        "schema": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "score": {"type": "number"},
                "summary": {"type": "string"},
                "strengths": {"type": "array", "items": {"type": "string"}},
                "improvements": {"type": "array", "items": {"type": "string"}},
                "criterion_scores": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "additionalProperties": False,
                        "properties": {
                            "criterion": {"type": "string"},
                            "score": {"type": "number"},
                            "max_score": {"type": "number"},
                            "comment": {"type": "string"}
                        },
                        "required": ["criterion", "score", "max_score", "comment"]
                    }
                },
                "flags": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "missing_submission_parts": {"type": "boolean"},
                        "off_topic": {"type": "boolean"},
                        "unclear_rubric": {"type": "boolean"},
                        "low_confidence": {"type": "boolean"}
                    },
                    "required": ["missing_submission_parts", "off_topic", "unclear_rubric", "low_confidence"]
                },
                "final_feedback": {"type": "string"}
            },
            "required": [
                "score",
                "summary",
                "strengths",
                "improvements",
                "criterion_scores",
                "flags",
                "final_feedback"
            ]
        }
    }


def normalize_grading_result(data: Dict[str, Any]) -> Dict[str, Any]:
    result = {
        "score": safe_float(data.get("score", 0.0)),
        "summary": compact_text(data.get("summary", ""), 220),
        "strengths": [compact_text(x, 160) for x in (data.get("strengths") or []) if compact_text(x, 160)][:2],
        "improvements": [compact_text(x, 180) for x in (data.get("improvements") or []) if compact_text(x, 180)][:4],
        "criterion_scores": [],
        "flags": {
            "missing_submission_parts": bool((data.get("flags") or {}).get("missing_submission_parts", False)),
            "off_topic": bool((data.get("flags") or {}).get("off_topic", False)),
            "unclear_rubric": bool((data.get("flags") or {}).get("unclear_rubric", False)),
            "low_confidence": bool((data.get("flags") or {}).get("low_confidence", False)),
        },
        "final_feedback": compact_text(data.get("final_feedback", ""), 260),
        "engine_name": str(data.get("engine_name", "unknown")).strip() or "unknown",
    }

    for item in data.get("criterion_scores") or []:
        criterion = str(item.get("criterion", "")).strip()
        if not criterion:
            continue
        row = {
            "criterion": compact_text(criterion, 90),
            "score": max(0.0, safe_float(item.get("score", 0.0))),
            "max_score": max(0.0, safe_float(item.get("max_score", 0.0))),
            "comment": compact_text(item.get("comment", ""), MAX_FEEDBACK_LINE_CHARS),
        }
        if row["max_score"] > 0 and row["score"] > row["max_score"]:
            row["score"] = row["max_score"]
        result["criterion_scores"].append(row)

    result["score"] = max(0.0, min(100.0, result["score"]))
    return result
def build_json_contract_text() -> str:
    return """
    Return exactly one JSON object with this structure:
    {
      "score": 0-100,
      "summary": "one short sentence",
      "strengths": ["up to 2 short items"],
      "improvements": ["up to 4 short missing/deduction items"],
      "criterion_scores": [
        {
          "criterion": "criterion name",
          "score": 0,
          "max_score": 0,
          "comment": "short reason for the score"
        }
      ],
      "flags": {
        "missing_submission_parts": false,
        "off_topic": false,
        "unclear_rubric": false,
        "low_confidence": false
      },
      "final_feedback": "one or two short teacher-facing sentences"
    }
    
    Rules:
    - score must be a number only, not a string like "92/100"
    - criterion_scores must be an array
    - flags must include all 4 boolean fields
    - keep every human-readable string concise
    - if Hebrew is the main language of the assignment/submission, write feedback fields in Hebrew
    - keep code identifiers, filenames, and exact technical terms unchanged
    - no markdown
    - no code fences
    - no explanations outside JSON
    """.strip()


def compact_text(value: Any, limit: int = MAX_FEEDBACK_LINE_CHARS) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    text = re.sub(r"\s+", " ", text)
    if len(text) <= limit:
        return text
    cutoff = text.rfind(" ", 0, max(0, limit - 1))
    if cutoff < max(40, int(limit * 0.55)):
        cutoff = max(0, limit - 1)
    return text[:cutoff].rstrip(" ,;:-") + "..."


def safe_float(value: Any) -> float:
    if value is None:
        return 0.0

    if isinstance(value, (int, float)):
        return float(value)

    text = str(value).strip()
    if not text:
        return 0.0

    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if match:
        try:
            return float(match.group(0))
        except Exception:
            return 0.0

    return 0.0


def extract_openai_response_text(response: Any) -> str:
    text = getattr(response, "output_text", None)
    if isinstance(text, str) and text.strip():
        return text

    output = getattr(response, "output", None) or []
    parts = []
    for item in output:
        content = getattr(item, "content", None)
        if content is None and isinstance(item, dict):
            content = item.get("content", [])
        for block in content or []:
            if isinstance(block, dict):
                txt = block.get("text")
                if isinstance(txt, str):
                    parts.append(txt)
                elif isinstance(txt, dict) and isinstance(txt.get("value"), str):
                    parts.append(txt["value"])
                elif isinstance(block.get("output_text"), str):
                    parts.append(block["output_text"])
            else:
                txt = getattr(block, "text", None)
                if isinstance(txt, str):
                    parts.append(txt)
                elif hasattr(txt, "value") and isinstance(txt.value, str):
                    parts.append(txt.value)
    if not parts:
        raise RuntimeError("Could not extract text from OpenAI response")
    return "\n".join(parts)


def extract_anthropic_text(response: Any) -> str:
    blocks = getattr(response, "content", None) or []
    parts: List[str] = []
    for block in blocks:
        txt = getattr(block, "text", None)
        if isinstance(txt, str) and txt.strip():
            parts.append(txt)
        elif isinstance(block, dict) and isinstance(block.get("text"), str):
            parts.append(block["text"])
    if not parts:
        raise RuntimeError("Could not extract text from Anthropic response")
    return "\n".join(parts)


def extract_gemini_text(response: Any) -> str:
    text = getattr(response, "text", None)
    if isinstance(text, str) and text.strip():
        return text

    candidates = getattr(response, "candidates", None) or []
    parts: List[str] = []
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        if not content:
            continue
        candidate_parts = getattr(content, "parts", None) or []
        for part in candidate_parts:
            txt = getattr(part, "text", None)
            if isinstance(txt, str) and txt.strip():
                parts.append(txt)
    if not parts:
        raise RuntimeError("Could not extract text from Gemini response")
    return "\n".join(parts)


def parse_provider_json(raw_text: str) -> Dict[str, Any]:
    raw = (raw_text or "").strip()
    if not raw:
        raise RuntimeError("Empty model response")

    try:
        return json.loads(raw)
    except Exception:
        pass

    raw = raw.replace("```json", "```").replace("```JSON", "```")
    fence_match = re.search(r"```\s*(\{.*?\})\s*```", raw, flags=re.DOTALL)
    if fence_match:
        return json.loads(fence_match.group(1))

    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        return json.loads(raw[start:end + 1])

    raise RuntimeError("Model response did not contain valid JSON")


def build_grading_prompt(payload: Dict[str, Any]) -> str:
    contract = build_json_contract_text()

    return f"""
Grade the student submission.

{contract}

Assignment title:
{payload['assignment_title']}

Assignment description / instructions:
{payload['assignment_description']}

Rubric / task file text:
{payload['rubric_text']}

Student submission text and extracted files:
{payload['submission_text']}

Important grading rules:
1. Score from 0 to 100.
2. Prefer the rubric over general assumptions.
3. If the rubric is incomplete, still produce a best-effort grade and set unclear_rubric=true.
4. If the submission is incomplete or clearly missing required parts, set missing_submission_parts=true.
5. Keep final_feedback concise, teacher-friendly, and specific to this student's actual text.
6. criterion_scores should include one item per rubric item when possible.
7. Avoid repeating generic phrases.
8. Do not over-penalize small deviations from word-count requirements.
9. Use the full scoring range when justified.
10. If the answer is empty or essentially empty, score it 0.
11. If the answer is mostly off-topic, set off_topic=true and score accordingly.
12. Mention concrete strengths or weaknesses from the student's submission.
13. When the submission contains multiple extracted files, use the FILE headers as filenames and grade the project as a whole.
14. For code submissions, inspect the code against the teacher instructions instead of judging only prose style.
15. If an archive or binary file could not be extracted, grade the readable parts and mention the extraction limitation.
16. Start from full credit and subtract only for clear missing requirements, incorrect behavior, or explicit rubric criteria.
17. Award partial credit generously for correct ideas, equivalent implementations, or working code that differs from the expected style.
18. Do not deduct for style, formatting, language mix, file organization, comments, or naming unless the rubric explicitly asks for it.
19. For code, prioritize correctness, required features, and runnable logic over prose quality.
20. Keep summary, improvements, criterion comments, and final_feedback short enough for a teacher review panel.
21. If Hebrew is the main language in the assignment, rubric, or submission, write all feedback fields in Hebrew. Keep code identifiers and technical names in their original language.

Return JSON only.
""".strip()


def build_summary_prompt(payload: Dict[str, Any], model_results: List[Dict[str, Any]]) -> str:
    judges_text = []
    for item in model_results:
        judges_text.append(
            json.dumps(
                {
                    "engine_name": item.get("engine_name", "unknown"),
                    "score": item.get("score", 0),
                    "summary": item.get("summary", ""),
                    "strengths": item.get("strengths", []),
                    "improvements": item.get("improvements", []),
                    "criterion_scores": item.get("criterion_scores", []),
                    "flags": item.get("flags", {}),
                    "final_feedback": item.get("final_feedback", ""),
                },
                ensure_ascii=False,
                indent=2,
            )
        )

    return f"""
You are combining multiple grading results for one student submission.
Return JSON only. Do not use markdown. Do not include any text outside JSON.

Task:
Create a single final grading result that is specific, concise, and not repetitive.
Base the result on the judges below and keep it aligned with the rubric.
Do not over-emphasize minor word-count misses.
When there is uncertainty or disagreement, choose the fairer interpretation that is still supported by the rubric.
Deduct only for clear misses, and keep teacher-facing text short.
If the judges disagree, choose the consensus view.
Use the assignment/submission's primary language for feedback fields; if it is Hebrew, write concise Hebrew feedback and keep code terms unchanged.

Assignment title:
{payload['assignment_title']}

Assignment description / instructions:
{payload['assignment_description']}

Rubric / task file text:
{payload['rubric_text']}

Student submission text and extracted files:
{payload['submission_text']}

Judge results:
{chr(10).join(judges_text)}
""".strip()


def truncate_text(text: str) -> str:
    text = (text or "").strip()
    if len(text) <= MAX_TEXT_CHARS:
        return text
    return text[:MAX_TEXT_CHARS] + "\n\n[TRUNCATED]"


def file_suffix(name: str) -> str:
    lower_name = str(name or "").lower()
    for suffix in sorted(ARCHIVE_EXTENSIONS, key=len, reverse=True):
        if lower_name.endswith(suffix):
            return suffix
    return Path(lower_name).suffix


def is_archive_name(name: str) -> bool:
    return file_suffix(name) in ARCHIVE_EXTENSIONS


def looks_binary(data: bytes) -> bool:
    sample = data[:4096]
    if not sample:
        return False
    if b"\x00" in sample:
        return True
    control_count = sum(1 for byte in sample if byte < 9 or (13 < byte < 32))
    return (control_count / max(1, len(sample))) > 0.2


def decode_text_bytes(data: bytes) -> Tuple[bool, str]:
    for encoding in ("utf-8", "utf-8-sig", "cp1255", "cp1252"):
        try:
            return True, data.decode(encoding)
        except Exception:
            continue

    if not looks_binary(data):
        try:
            return True, data.decode("latin-1")
        except Exception:
            pass

    return False, "BINARY_CONTENT"


def xml_bytes_to_text(xml_bytes: bytes) -> str:
    xml_text = xml_bytes.decode("utf-8", errors="ignore")
    xml_text = re.sub(r"</(?:w:p|a:p|row|si|t)>", "\n", xml_text)
    text = re.sub(r"<[^>]+>", "", xml_text)
    text = html.unescape(text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_openxml_text(data: bytes, suffix: str) -> Tuple[bool, str]:
    try:
        with zipfile.ZipFile(io.BytesIO(data), "r") as zf:
            if suffix == ".docx":
                candidates = ["word/document.xml"]
            elif suffix == ".pptx":
                candidates = sorted(
                    name for name in zf.namelist()
                    if name.startswith("ppt/slides/") and name.endswith(".xml")
                )
            elif suffix == ".xlsx":
                candidates = ["xl/sharedStrings.xml"] + sorted(
                    name for name in zf.namelist()
                    if name.startswith("xl/worksheets/") and name.endswith(".xml")
                )
            else:
                candidates = []

            parts = []
            for name in candidates:
                try:
                    text = xml_bytes_to_text(zf.read(name))
                    if text:
                        parts.append(text)
                except Exception:
                    continue

        if not parts:
            return False, f"{suffix.upper().lstrip('.')} text is empty"
        return True, "\n\n".join(parts)
    except Exception as exc:
        return False, f"{suffix.upper().lstrip('.')} read failed: {exc}"


def extract_pdf_text(data: bytes) -> Tuple[bool, str]:
    try:
        try:
            from pypdf import PdfReader
        except Exception:
            from PyPDF2 import PdfReader
        reader = PdfReader(io.BytesIO(data))
        pages = [(page.extract_text() or "") for page in reader.pages]
        text = "\n\n".join(pages).strip()
        if not text:
            return False, "PDF text is empty"
        return True, text
    except Exception as exc:
        return False, f"PDF read failed: {exc}"


def extract_legacy_doc_text(data: bytes) -> str:
    candidates = []
    try:
        utf16_text = data.decode("utf-16le", errors="ignore")
        candidates.extend(re.findall(r"[\w\s.,;:!?(){}\\/\-+*=<>#@'\"]{20,}", utf16_text))
    except Exception:
        pass

    try:
        latin_text = data.decode("latin-1", errors="ignore")
        candidates.extend(re.findall(r"[\w\s.,;:!?(){}\\/\-+*=<>#@'\"]{20,}", latin_text))
    except Exception:
        pass

    cleaned = []
    seen = set()
    for item in candidates:
        text = re.sub(r"\s+", " ", item).strip()
        if len(text) >= 20 and text.lower() not in seen:
            seen.add(text.lower())
            cleaned.append(text)
        if len("\n".join(cleaned)) >= MAX_TEXT_CHARS:
            break
    return "\n".join(cleaned).strip()


def file_block(label: str, text: str) -> str:
    return f"===== FILE: {label} =====\n{text.strip()}"


def archive_summary_block(label: str, skipped: List[str]) -> str:
    if not skipped:
        return ""
    skipped_text = "\n".join(f"- {item}" for item in skipped[:40])
    extra = "" if len(skipped) <= 40 else f"\n- ... {len(skipped) - 40} more skipped entries"
    return f"===== ARCHIVE NOTES: {label} =====\nSkipped or limited files:\n{skipped_text}{extra}"


def read_zip_archive(data: bytes, label: str, depth: int) -> Tuple[bool, str]:
    try:
        with zipfile.ZipFile(io.BytesIO(data), "r") as zf:
            entries = [(info.filename, info.file_size, info.is_dir(), lambda i=info: zf.read(i)) for info in zf.infolist()]
            return read_archive_entries(entries, label, depth)
    except Exception as exc:
        return False, f"ZIP_READ_FAILED: {exc}"


def read_tar_archive(data: bytes, label: str, depth: int) -> Tuple[bool, str]:
    try:
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf:
            entries = []
            for member in tf.getmembers():
                entries.append((member.name, member.size, not member.isfile(), lambda m=member: (tf.extractfile(m) or io.BytesIO()).read()))
            return read_archive_entries(entries, label, depth)
    except Exception as exc:
        return False, f"TAR_READ_FAILED: {exc}"


def archive_tool_candidates() -> List[str]:
    candidates = []
    for path_text in (
        r"C:\Program Files\7-Zip\7z.exe",
        r"C:\Program Files (x86)\7-Zip\7z.exe",
        r"C:\ProgramData\chocolatey\bin\7z.exe",
        r"C:\msys64\usr\bin\bsdtar.exe",
    ):
        if Path(path_text).exists() and path_text not in candidates:
            candidates.append(path_text)

    names = ["7z", "7za", "7zr", "unar", "unrar", "bsdtar", "tar"]
    for name in names:
        found = shutil.which(name)
        if found and found not in candidates:
            candidates.append(found)

    windows_tar = r"C:\Windows\system32\tar.exe"
    if Path(windows_tar).exists() and windows_tar not in candidates:
        candidates.append(windows_tar)
    return candidates


def archive_tool_kind(tool_path: str) -> str:
    name = Path(tool_path).name.lower()
    if name in {"7z.exe", "7za.exe", "7zr.exe", "7z", "7za", "7zr"}:
        return "7z"
    if name in {"unar.exe", "unar"}:
        return "unar"
    if name in {"unrar.exe", "unrar", "rar.exe", "rar"}:
        return "unrar"
    return "tar"


def make_archive_temp_dir(prefix: str) -> str:
    try:
        return tempfile.mkdtemp(prefix=prefix, dir=str(Path(__file__).resolve().parent))
    except Exception:
        return tempfile.mkdtemp(prefix=prefix)


def make_archive_temp_file(suffix: str):
    try:
        return tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir=str(Path(__file__).resolve().parent))
    except Exception:
        return tempfile.NamedTemporaryFile(delete=False, suffix=suffix)


def normalize_archive_member_name(name: str) -> str:
    clean_name = str(name or "").replace("\\", "/").lstrip("/")
    if not clean_name or "\x00" in clean_name or re.match(r"^[A-Za-z]:", clean_name):
        return ""
    parts = PurePosixPath(clean_name).parts
    if any(part in {"", ".", ".."} for part in parts):
        return ""
    return clean_name


def find_extracted_member(root: Path, member_name: str) -> Optional[Path]:
    root_resolved = root.resolve()
    target = (root / member_name).resolve()
    if target.is_file() and root_resolved in target.parents:
        return target

    basename = Path(member_name).name
    for candidate in root.rglob(basename):
        resolved = candidate.resolve()
        if candidate.is_file() and root_resolved in resolved.parents:
            return candidate
    return None


def run_archive_tool(tool_path: str, args: List[str]):
    return subprocess.run(
        [tool_path, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=ARCHIVE_TOOL_TIMEOUT_SECONDS,
        check=False,
    )


def list_archive_with_tool(tool_path: str, archive_path: str) -> Tuple[bool, List[str], str]:
    kind = archive_tool_kind(tool_path)
    try:
        if kind == "7z":
            proc = run_archive_tool(tool_path, ["l", "-ba", archive_path])
            text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
            names = []
            for line in text.splitlines():
                match = re.match(r"^\d{4}-\d{2}-\d{2}.*\s(.+)$", line.strip())
                if match:
                    candidate = match.group(1).strip()
                    if candidate and not candidate.endswith("\\") and not candidate.endswith("/"):
                        names.append(candidate)
            return proc.returncode == 0 and bool(names), names, text.strip()

        if kind == "unar":
            proc = run_archive_tool(tool_path, ["-list", archive_path])
            text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
            names = [line.strip() for line in text.splitlines() if line.strip() and not line.lower().startswith(("archive:", "contents"))]
            names = [name for name in names if not name.endswith("/") and not name.endswith("\\")]
            return proc.returncode == 0 and bool(names), names, text.strip()

        if kind == "unrar":
            proc = run_archive_tool(tool_path, ["lb", archive_path])
            text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
            names = [line.strip() for line in text.splitlines() if line.strip() and not line.endswith("/") and not line.endswith("\\")]
            return proc.returncode == 0 and bool(names), names, text.strip()

        proc = run_archive_tool(tool_path, ["-tf", archive_path])
        text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
        names = [line.strip() for line in text.splitlines() if line.strip() and not line.endswith("/") and not line.endswith("\\")]
        return proc.returncode == 0 and bool(names), names, text.strip()
    except Exception as exc:
        return False, [], str(exc)


def extract_archive_member_with_tool(tool_path: str, archive_path: str, member_name: str) -> Tuple[bool, bytes, str]:
    kind = archive_tool_kind(tool_path)
    try:
        if kind == "7z":
            proc = run_archive_tool(tool_path, ["x", "-so", archive_path, member_name])
        elif kind == "unar":
            tmp_dir = make_archive_temp_dir("classify_unar_")
            try:
                proc = run_archive_tool(tool_path, ["-quiet", "-force-overwrite", "-output-directory", tmp_dir, archive_path])
                if proc.returncode != 0:
                    text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
                    return False, b"", text.strip()
                target = Path(tmp_dir) / member_name
                if not target.exists() or not target.is_file():
                    matches = [p for p in Path(tmp_dir).rglob(Path(member_name).name) if p.is_file()]
                    if not matches:
                        return False, b"", "member was not extracted"
                    target = matches[0]
                return True, target.read_bytes(), ""
            finally:
                shutil.rmtree(tmp_dir, ignore_errors=True)
        elif kind == "unrar":
            proc = run_archive_tool(tool_path, ["p", "-inul", archive_path, member_name])
        else:
            safe_name = normalize_archive_member_name(member_name)
            if not safe_name:
                return False, b"", "unsafe archive member path"
            tmp_dir = make_archive_temp_dir("classify_tar_")
            try:
                proc = run_archive_tool(tool_path, ["-xf", archive_path, "-C", tmp_dir, member_name])
                if proc.returncode != 0:
                    text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
                    return False, b"", text.strip()
                target = find_extracted_member(Path(tmp_dir), safe_name)
                if target is None:
                    return False, b"", "member was not extracted"
                return True, target.read_bytes(), ""
            finally:
                shutil.rmtree(tmp_dir, ignore_errors=True)

        if proc.returncode != 0:
            text = proc.stdout.decode("utf-8", errors="ignore") + proc.stderr.decode("utf-8", errors="ignore")
            return False, b"", text.strip()
        return True, proc.stdout, ""
    except Exception as exc:
        return False, b"", str(exc)


def read_external_archive(data: bytes, label: str, depth: int) -> Tuple[bool, str]:
    suffix = file_suffix(label)
    with make_archive_temp_file(suffix or ".archive") as tmp_file:
        tmp_file.write(data)
        archive_path = tmp_file.name

    try:
        last_error = ""
        for tool_path in archive_tool_candidates():
            ok_list, names, list_error = list_archive_with_tool(tool_path, archive_path)
            if not ok_list:
                last_error = f"{Path(tool_path).name}: {list_error}"
                continue

            entries = []
            for name in names:
                def read_member(member_name=name, selected_tool=tool_path):
                    ok_extract, raw, extract_error = extract_archive_member_with_tool(selected_tool, archive_path, member_name)
                    if not ok_extract:
                        raise RuntimeError(extract_error or "archive extraction failed")
                    return raw

                entries.append((name, 0, False, read_member))

            ok_read, text = read_archive_entries(entries, label, depth)
            if "===== FILE:" not in text and "could not read" in text:
                last_error = f"{Path(tool_path).name}: listed archive but could not extract readable members"
                continue
            return ok_read, text

        return True, (
            f"===== ARCHIVE: {label} =====\n"
            f"{label} could not be extracted by available local archive tools. "
            f"Last extraction error: {last_error or 'no compatible archive tool found'}"
        )
    finally:
        try:
            Path(archive_path).unlink(missing_ok=True)
        except Exception:
            pass


def read_rar_archive(data: bytes, label: str, depth: int) -> Tuple[bool, str]:
    external_ok, external_text = read_external_archive(data, label, depth)
    if external_ok and "could not be extracted" not in external_text:
        return external_ok, external_text

    try:
        import rarfile
    except Exception:
        return external_ok, external_text

    try:
        with rarfile.RarFile(io.BytesIO(data)) as rf:
            entries = [(info.filename, info.file_size, info.isdir(), lambda i=info: rf.read(i)) for info in rf.infolist()]
            return read_archive_entries(entries, label, depth)
    except Exception as exc:
        return True, f"{external_text}\nrarfile fallback failed: {exc}".strip()


def read_7z_archive(data: bytes, label: str, depth: int) -> Tuple[bool, str]:
    external_ok, external_text = read_external_archive(data, label, depth)
    if external_ok and "could not be extracted" not in external_text:
        return external_ok, external_text

    try:
        import py7zr
    except Exception:
        return external_ok, external_text

    try:
        with py7zr.SevenZipFile(io.BytesIO(data), mode="r") as archive:
            extracted = archive.readall()
        entries = []
        for name, file_obj in extracted.items():
            raw = file_obj.read()
            entries.append((name, len(raw), False, lambda raw=raw: raw))
        return read_archive_entries(entries, label, depth)
    except Exception as exc:
        return True, f"{external_text}\npy7zr fallback failed: {exc}".strip()


def read_archive_entries(entries, label: str, depth: int) -> Tuple[bool, str]:
    if depth > 2:
        return True, f"===== ARCHIVE: {label} =====\nNested archive skipped after depth limit."

    parts = []
    skipped = []
    total_bytes = 0
    file_count = 0

    for member_name, member_size, is_dir, read_member in entries:
        clean_name = normalize_archive_member_name(member_name)
        if is_dir or not clean_name or clean_name.startswith("__MACOSX/"):
            continue

        file_count += 1
        if file_count > MAX_ARCHIVE_FILES:
            skipped.append(f"{clean_name}: archive file limit reached")
            break

        reported_size = max(0, int(member_size or 0))
        if reported_size > MAX_ARCHIVE_MEMBER_BYTES:
            skipped.append(f"{clean_name}: larger than per-file AI extraction limit")
            continue

        if reported_size and total_bytes + reported_size > MAX_ARCHIVE_TOTAL_BYTES:
            skipped.append(f"{clean_name}: archive total extraction limit reached")
            break

        try:
            member_bytes = read_member()
        except Exception as exc:
            skipped.append(f"{clean_name}: could not read ({exc})")
            continue

        actual_size = len(member_bytes)
        if actual_size > MAX_ARCHIVE_MEMBER_BYTES:
            skipped.append(f"{clean_name}: larger than per-file AI extraction limit")
            continue
        if total_bytes + actual_size > MAX_ARCHIVE_TOTAL_BYTES:
            skipped.append(f"{clean_name}: archive total extraction limit reached")
            break
        total_bytes += actual_size

        ok_member, member_text = read_named_bytes(member_bytes, clean_name, depth + 1)
        if ok_member:
            parts.append(file_block(clean_name, member_text))
        else:
            skipped.append(f"{clean_name}: {member_text}")

        if len("\n\n".join(parts)) >= MAX_TEXT_CHARS:
            skipped.append("archive text truncated after AI text limit")
            break

    notes = archive_summary_block(label, skipped)
    if notes:
        parts.append(notes)

    if not parts:
        return True, f"===== ARCHIVE: {label} =====\nNo readable text files were found in this archive."

    return True, truncate_text("\n\n".join(parts))


def read_named_bytes(data: bytes, label: str, depth: int = 0) -> Tuple[bool, str]:
    suffix = file_suffix(label)

    if suffix in {".zip", ".jar", ".war", ".ear"}:
        return read_zip_archive(data, label, depth)
    if suffix in {".tar", ".tgz", ".tbz", ".tbz2", ".txz", ".tar.gz", ".tar.bz2", ".tar.xz"}:
        return read_tar_archive(data, label, depth)
    if suffix == ".rar":
        return read_rar_archive(data, label, depth)
    if suffix == ".7z":
        return read_7z_archive(data, label, depth)
    if suffix == ".pdf":
        return extract_pdf_text(data)
    if suffix in {".docx", ".pptx", ".xlsx"}:
        return extract_openxml_text(data, suffix)
    if suffix == ".doc":
        text = extract_legacy_doc_text(data)
        if text:
            return True, text
        return True, "Legacy .doc file received, but no reliable text could be extracted."

    if suffix in SUPPORTED_TEXT_EXTENSIONS or not looks_binary(data):
        ok_decode, text = decode_text_bytes(data)
        if ok_decode:
            return True, text

    if suffix in BINARY_EXTENSIONS or looks_binary(data):
        return True, f"Binary file received ({len(data)} bytes). Text could not be extracted for direct AI inspection."

    return False, f"UNSUPPORTED_FILE_TYPE: {suffix or 'NO_EXTENSION'}"


def read_file_text(file_path: str) -> Tuple[bool, str]:
    path = Path(file_path)
    if not path.exists() or not path.is_file():
        return False, f"FILE_NOT_FOUND: {file_path}"

    try:
        data = path.read_bytes()
    except Exception as exc:
        return False, f"FILE_READ_FAILED: {exc}"

    ok_read, text = read_named_bytes(data, path.name)
    if not ok_read:
        return False, text
    return True, truncate_text(text)


def load_submission_payload(submission: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
    ok_submission, submission_text = read_file_text(submission["file_path"])
    if not ok_submission:
        return False, {"error": submission_text}

    ok_assignment, assignment = db.get_assignment(submission["assignment_id"])
    if not ok_assignment:
        return False, {"error": assignment}

    rubric_path = assignment.get("attachment_path") or ""
    if not rubric_path:
        return False, {"error": "RUBRIC_ATTACHMENT_MISSING"}

    ok_rubric, rubric_text = read_file_text(rubric_path)
    if not ok_rubric:
        return False, {"error": rubric_text}

    return True, {
        "assignment_id": assignment["assignment_id"],
        "assignment_title": assignment.get("title", ""),
        "assignment_description": assignment.get("description", ""),
        "rubric_path": rubric_path,
        "rubric_text": rubric_text,
        "submission_id": submission["submission_id"],
        "submission_path": submission["file_path"],
        "submission_text": submission_text,
        "student_id": submission["student_id"],
    }


def aggregate_results(payload: Dict[str, Any], results: List[Dict[str, Any]], summary_provider: Optional[GraderProvider]) -> Dict[str, Any]:
    if not results:
        raise RuntimeError("No model results to aggregate")

    if len(results) == 1:
        return results[0]

    aggregated = aggregate_without_llm(results)

    if summary_provider is None:
        aggregated["engine_name"] = f"consensus:{','.join([r.get('engine_name', 'unknown') for r in results])}"
        return aggregated

    try:
        summary_payload = dict(payload)
        summary_payload["assignment_title"] = payload.get("assignment_title", "")
        prompt = build_summary_prompt(summary_payload, results)

        if summary_provider.name == "openai":
            provider = summary_provider
            schema = build_grading_schema()
            response = provider.client.responses.create(
                model=DEFAULT_SUMMARIZER_MODEL or getattr(provider, "model", DEFAULT_OPENAI_MODEL),
                input=[
                    {
                        "role": "system",
                        "content": [{
                            "type": "input_text",
                            "text": "You combine several grading judgments into one final JSON result. Return JSON only.",
                        }],
                    },
                    {
                        "role": "user",
                        "content": [{"type": "input_text", "text": prompt}],
                    },
                ],
                text={
                    "format": {
                        "type": "json_schema",
                        "name": schema["name"],
                        "schema": schema["schema"],
                        "strict": True,
                    }
                },
            )
            data = normalize_grading_result(parse_provider_json(extract_openai_response_text(response)))
            data["engine_name"] = f"consensus:{','.join([r.get('engine_name', 'unknown') for r in results])}"
            data["score"] = aggregated["score"]
            data["criterion_scores"] = aggregated["criterion_scores"]
            return data
    except Exception as exc:
        print(f"[AI WORKER] summarizer warning: {exc}")

    aggregated["engine_name"] = f"consensus:{','.join([r.get('engine_name', 'unknown') for r in results])}"
    return aggregated


def aggregate_without_llm(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    scores = [max(0.0, min(100.0, safe_float(item.get("score", 0.0)))) for item in results]
    score_value = round(float(median(scores)), 2)

    criterion_map: Dict[str, List[Dict[str, Any]]] = {}
    for result in results:
        for row in result.get("criterion_scores") or []:
            key = normalize_criterion_name(row.get("criterion", ""))
            if not key:
                continue
            criterion_map.setdefault(key, []).append(row)

    aggregated_criteria = []
    for key, rows in criterion_map.items():
        max_scores = [safe_float(r.get("max_score", 0.0)) for r in rows]
        row_scores = [safe_float(r.get("score", 0.0)) for r in rows]
        comments = [str(r.get("comment", "")).strip() for r in rows if str(r.get("comment", "")).strip()]
        label = rows[0].get("criterion", key)
        aggregated_criteria.append({
            "criterion": label,
            "score": round(float(median(row_scores)), 2),
            "max_score": round(float(median(max_scores)), 2),
            "comment": choose_best_comment(comments),
        })

    strengths = merge_unique_lines(results, "strengths", limit=5)
    improvements = merge_unique_lines(results, "improvements", limit=5)

    flags = {
        "missing_submission_parts": any((r.get("flags") or {}).get("missing_submission_parts", False) for r in results),
        "off_topic": any((r.get("flags") or {}).get("off_topic", False) for r in results),
        "unclear_rubric": any((r.get("flags") or {}).get("unclear_rubric", False) for r in results),
        "low_confidence": any((r.get("flags") or {}).get("low_confidence", False) for r in results),
    }

    summary = choose_best_comment([str(r.get("summary", "")).strip() for r in results if str(r.get("summary", "")).strip()])
    final_feedback = choose_best_comment([str(r.get("final_feedback", "")).strip() for r in results if str(r.get("final_feedback", "")).strip()])

    return normalize_grading_result({
        "score": score_value,
        "summary": summary,
        "strengths": strengths,
        "improvements": improvements,
        "criterion_scores": aggregated_criteria,
        "flags": flags,
        "final_feedback": final_feedback,
        "engine_name": "consensus",
    })


def normalize_criterion_name(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "").strip().lower())


def choose_best_comment(comments: List[str]) -> str:
    unique: List[str] = []
    seen = set()
    for comment in comments:
        text = compact_text(comment, 220)
        key = re.sub(r"\s+", " ", text.lower())
        if key and key not in seen:
            seen.add(key)
            unique.append(text)
    if not unique:
        return ""
    unique.sort(key=lambda x: (0 if 35 <= len(x) <= 180 else 1, abs(len(x) - 110), len(x), x))
    return unique[0]


def merge_unique_lines(results: List[Dict[str, Any]], field_name: str, limit: int) -> List[str]:
    seen = set()
    output: List[str] = []
    for result in results:
        for item in result.get(field_name) or []:
            text = str(item).strip()
            key = re.sub(r"\s+", " ", text.lower())
            if text and key not in seen:
                seen.add(key)
                output.append(text)
            if len(output) >= limit:
                return output
    return output


def contains_hebrew(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, dict):
        return any(contains_hebrew(item) for item in value.values())
    if isinstance(value, (list, tuple, set)):
        return any(contains_hebrew(item) for item in value)
    return bool(HEBREW_RE.search(str(value)))


def format_number(value: Any) -> str:
    number = round(safe_float(value), 2)
    if number.is_integer():
        return str(int(number))
    return f"{number:.2f}".rstrip("0").rstrip(".")


def format_points(score: Any, max_score: Any, rtl: bool) -> str:
    value = f"{format_number(score)}/{format_number(max_score)}"
    return f"{LRM}{value}{LRM}" if rtl else value


def make_rtl_block(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if line.strip():
            lines.append(f"{RTL_EMBED}{line}{POP_DIRECTIONAL}")
        else:
            lines.append("")
    return "\n".join(lines)


def unique_short_items(items: List[str], limit: int) -> List[str]:
    output: List[str] = []
    seen = set()
    for item in items:
        text = compact_text(item, MAX_FEEDBACK_LINE_CHARS)
        key = re.sub(r"\s+", " ", text.lower())
        if text and key not in seen:
            seen.add(key)
            output.append(text)
        if len(output) >= limit:
            break
    return output


def deduction_items(result: Dict[str, Any], rtl: bool) -> List[str]:
    items: List[str] = []
    flags = result.get("flags") or {}

    if flags.get("missing_submission_parts"):
        items.append("חסרים חלקים שנדרשו במטלה." if rtl else "Required submission parts are missing.")
    if flags.get("off_topic"):
        items.append("חלק מההגשה אינו עונה ישירות על דרישות המטלה." if rtl else "Part of the submission does not address the assignment requirements.")
    if flags.get("unclear_rubric"):
        items.append("המחוון לא היה ברור לגמרי, לכן הציון ניתן לפי מיטב ההערכה." if rtl else "The rubric was unclear, so the grade is a best-effort assessment.")
    if flags.get("low_confidence"):
        items.append("קיימת אי-ודאות מסוימת בציון ומומלץ לעבור עליו ידנית." if rtl else "There is some grading uncertainty; a quick manual review is recommended.")

    items.extend([str(x).strip() for x in result.get("improvements", []) if str(x).strip()])
    if items:
        return unique_short_items(items, 4)

    for row in result.get("criterion_scores", []) or []:
        score = safe_float(row.get("score", 0))
        max_score = safe_float(row.get("max_score", 0))
        comment = str(row.get("comment", "")).strip()
        if max_score > 0 and score < max_score and comment:
            criterion = compact_text(row.get("criterion", "Criterion"), 60)
            items.append(f"{criterion}: {comment}")

    return unique_short_items(items, 4)


def build_teacher_feedback(result: Dict[str, Any], payload: Optional[Dict[str, Any]] = None) -> str:
    rtl = contains_hebrew(payload or {}) or contains_hebrew(result)
    labels = {
        "score": "ציון" if rtl else "Score",
        "summary": "סיכום" if rtl else "Summary",
        "breakdown": "פירוט לפי סעיפים" if rtl else "Breakdown",
        "missing": "חסר / ירדו נקודות" if rtl else "Missing / deducted",
        "final": "הערה קצרה" if rtl else "Short note",
        "criterion": "סעיף" if rtl else "Criterion",
    }

    lines: List[str] = [f"{labels['score']}: {format_points(result.get('score', 0), 100, rtl)}"]

    summary = (result.get("summary") or "").strip()
    if summary:
        lines.append(f"{labels['summary']}: {compact_text(summary, MAX_FEEDBACK_LINE_CHARS)}")

    criterion_scores = result.get("criterion_scores", []) or []
    if criterion_scores:
        lines.append(f"{labels['breakdown']}:")
        for row in criterion_scores:
            criterion = compact_text(row.get("criterion", labels["criterion"]), 70)
            points = format_points(row.get("score", 0), row.get("max_score", 0), rtl)
            comment = compact_text(row.get("comment", ""), MAX_FEEDBACK_LINE_CHARS)
            suffix = f" - {comment}" if comment else ""
            lines.append(f"- {criterion}: {points}{suffix}")

    missing = deduction_items(result, rtl)
    if missing:
        lines.append(f"{labels['missing']}:")
        lines.extend([f"- {item}" for item in missing])

    final_feedback = (result.get("final_feedback") or "").strip()
    if final_feedback:
        lines.append(f"{labels['final']}: {compact_text(final_feedback, MAX_FEEDBACK_LINE_CHARS)}")

    text = "\n".join(lines).strip()
    return make_rtl_block(text) if rtl else text


def format_final_feedback(result: Dict[str, Any], payload: Optional[Dict[str, Any]] = None) -> str:
    return build_teacher_feedback(result, payload)


def score_spread(results: List[Dict[str, Any]]) -> float:
    if len(results) < 2:
        return 0.0
    scores = [safe_float(item.get("score", 0.0)) for item in results]
    return max(scores) - min(scores)


def process_one_submission(providers: List[GraderProvider], summary_provider: Optional[GraderProvider]) -> bool:
    ok_claim, submission_or_error = db.claim_next_pending_submission()
    if not ok_claim:
        if submission_or_error in ("NO_PENDING_SUBMISSIONS", "CLAIM_CONFLICT"):
            return False
        print(f"[AI WORKER] claim error: {submission_or_error}")
        return False

    submission = submission_or_error
    submission_id = int(submission["submission_id"])
    print(f"[AI WORKER] Processing submission {submission_id}")

    try:
        ok_payload, payload_or_error = load_submission_payload(submission)
        if not ok_payload:
            error_message = payload_or_error.get("error", "LOAD_PAYLOAD_FAILED")
            db.save_feedback(submission_id, ai_feedback=f"AI worker error: {error_message}", teacher_feedback=None)
            db.update_submission_status(submission_id, "ERROR")
            print(f"[AI WORKER] submission {submission_id} -> ERROR ({error_message})")
            return True

        if not providers:
            raise RuntimeError("No enabled grading providers are available. Check API keys and installed SDKs.")

        payload = payload_or_error
        db.delete_ai_results_for_submission(submission_id)

        per_model_results: List[Dict[str, Any]] = []
        provider_errors: List[str] = []

        for provider in providers:
            try:
                result = provider.grade(payload)
                result = normalize_grading_result(result)
                per_model_results.append(result)
                db.save_ai_result(
                    submission_id,
                    result.get("engine_name", provider.name),
                    result.get("score", 0.0),
                    format_final_feedback(result, payload),
                )
            except Exception as exc:
                provider_errors.append(f"{provider.name}: {exc}")
                print(f"[AI WORKER] provider {provider.name} failed for submission {submission_id}: {exc}")

        if not per_model_results:
            raise RuntimeError("All AI providers failed: " + " | ".join(provider_errors))

        final_result = aggregate_results(payload, per_model_results, summary_provider)
        spread = score_spread(per_model_results)
        if spread >= 12:
            final_result.setdefault("flags", {})["low_confidence"] = True

        final_result_text = format_final_feedback(final_result, payload)
        final_score = max(0.0, min(100.0, safe_float(final_result.get("score", 0.0))))

        if provider_errors:
            final_result_text += "\nModel errors: " + " | ".join(provider_errors)

        db.save_grade(submission_id, ai_score=final_score, final_score=None, updated_by=None)
        db.save_feedback(submission_id, ai_feedback=final_result_text, teacher_feedback=None)
        db.update_submission_status(submission_id, "AI_DONE")
        print(f"[AI WORKER] submission {submission_id} -> AI_DONE ({final_score})")
        return True

    except Exception as exc:
        db.save_feedback(submission_id, ai_feedback=f"AI worker exception: {exc}", teacher_feedback=None)
        db.update_submission_status(submission_id, "ERROR")
        print(f"[AI WORKER] submission {submission_id} -> ERROR ({exc})")
        return True


def build_provider_registry() -> ProviderRegistry:
    registry = ProviderRegistry()
    registry.register(OpenAIGraderProvider())
    registry.register(AnthropicGraderProvider())
    registry.register(GeminiGraderProvider())
    return registry


def run_ai_grading_worker(stop_event=None):
    try:
        ok_reset, reset_result = db.reset_in_progress_submissions()
        if ok_reset and reset_result:
            print(f"[AI WORKER] reset {reset_result} stuck AI_IN_PROGRESS submission(s)")
    except Exception as exc:
        print(f"[AI WORKER] reset warning: {exc}")

    registry = build_provider_registry()
    providers = registry.get_available(ENABLED_PROVIDER_NAMES)
    summary_provider = registry.get_first_available(DEFAULT_SUMMARIZER_PROVIDER)

    if not providers:
        print("[AI WORKER] warning: no AI providers are available. Install SDKs and set API keys.")
    else:
        print("[AI WORKER] started with providers=" + ", ".join([p.name for p in providers]))

    while True:
        if stop_event is not None and stop_event.is_set():
            print("[AI WORKER] stop requested")
            return

        processed = process_one_submission(providers, summary_provider)
        if not processed:
            time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    run_ai_grading_worker()
