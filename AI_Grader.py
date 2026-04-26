import json
import os
import re
import time
import zipfile
from pathlib import Path
from statistics import median
from typing import Any, Dict, List, Optional, Tuple

import db

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass


SUPPORTED_TEXT_EXTENSIONS = {".txt", ".md", ".csv", ".json", ".log", ".py", ".html", ".htm", ".xml"}
UNSUPPORTED_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tif", ".tiff"}

POLL_INTERVAL_SECONDS = int(os.getenv("AI_GRADER_POLL_INTERVAL", "10"))
MAX_TEXT_CHARS = int(os.getenv("AI_GRADER_MAX_TEXT_CHARS", "50000"))
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
                                "You are a strict but fair school assignment grader. "
                                "Grade only according to the rubric and assignment instructions. "
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
                "You are a strict but fair school assignment grader. "
                "Grade only according to the rubric and assignment instructions. "
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
        "summary": str(data.get("summary", "")).strip(),
        "strengths": [str(x).strip() for x in (data.get("strengths") or []) if str(x).strip()],
        "improvements": [str(x).strip() for x in (data.get("improvements") or []) if str(x).strip()],
        "criterion_scores": [],
        "flags": {
            "missing_submission_parts": bool((data.get("flags") or {}).get("missing_submission_parts", False)),
            "off_topic": bool((data.get("flags") or {}).get("off_topic", False)),
            "unclear_rubric": bool((data.get("flags") or {}).get("unclear_rubric", False)),
            "low_confidence": bool((data.get("flags") or {}).get("low_confidence", False)),
        },
        "final_feedback": str(data.get("final_feedback", "")).strip(),
        "engine_name": str(data.get("engine_name", "unknown")).strip() or "unknown",
    }

    for item in data.get("criterion_scores") or []:
        criterion = str(item.get("criterion", "")).strip()
        if not criterion:
            continue
        row = {
            "criterion": criterion,
            "score": max(0.0, safe_float(item.get("score", 0.0))),
            "max_score": max(0.0, safe_float(item.get("max_score", 0.0))),
            "comment": str(item.get("comment", "")).strip(),
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
      "summary": "short summary",
      "strengths": ["item 1", "item 2"],
      "improvements": ["item 1", "item 2"],
      "criterion_scores": [
        {
          "criterion": "criterion name",
          "score": 0,
          "max_score": 0,
          "comment": "specific comment"
        }
      ],
      "flags": {
        "missing_submission_parts": false,
        "off_topic": false,
        "unclear_rubric": false,
        "low_confidence": false
      },
      "final_feedback": "short final feedback"
    }
    
    Rules:
    - score must be a number only, not a string like "92/100"
    - criterion_scores must be an array
    - flags must include all 4 boolean fields
    - no markdown
    - no code fences
    - no explanations outside JSON
    """.strip()

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

Rubric text:
{payload['rubric_text']}

Student submission text:
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
If the judges disagree, choose the consensus view.
make sure to have only one language in the summery, based on the grading results languages.

Assignment title:
{payload['assignment_title']}

Assignment description / instructions:
{payload['assignment_description']}

Rubric text:
{payload['rubric_text']}

Student submission text:
{payload['submission_text']}

Judge results:
{chr(10).join(judges_text)}
""".strip()


def truncate_text(text: str) -> str:
    text = (text or "").strip()
    if len(text) <= MAX_TEXT_CHARS:
        return text
    return text[:MAX_TEXT_CHARS] + "\n\n[TRUNCATED]"


def read_file_text(file_path: str) -> Tuple[bool, str]:
    path = Path(file_path)
    if not path.exists() or not path.is_file():
        return False, f"FILE_NOT_FOUND: {file_path}"

    suffix = path.suffix.lower()

    if suffix in SUPPORTED_TEXT_EXTENSIONS:
        for encoding in ("utf-8", "utf-8-sig", "cp1255", "cp1252", "latin-1"):
            try:
                return True, truncate_text(path.read_text(encoding=encoding))
            except Exception:
                continue
        return False, f"TEXT_READ_FAILED: {file_path}"

    if suffix == ".pdf":
        try:
            try:
                from pypdf import PdfReader
            except Exception:
                from PyPDF2 import PdfReader
            reader = PdfReader(str(path))
            pages = []
            for page in reader.pages:
                pages.append(page.extract_text() or "")
            text = "\n\n".join(pages).strip()
            if not text:
                return False, f"PDF_TEXT_EMPTY: {file_path}"
            return True, truncate_text(text)
        except Exception as exc:
            return False, f"PDF_READ_FAILED: {exc}"

    if suffix == ".docx":
        try:
            with zipfile.ZipFile(path, "r") as zf:
                xml_bytes = zf.read("word/document.xml")
            xml_text = xml_bytes.decode("utf-8", errors="ignore")
            xml_text = xml_text.replace("</w:p>", "\n")
            xml_text = xml_text.replace("</w:tr>", "\n")
            text = re.sub(r"<[^>]+>", "", xml_text).strip()
            if not text:
                return False, f"DOCX_TEXT_EMPTY: {file_path}"
            return True, truncate_text(text)
        except Exception as exc:
            return False, f"DOCX_READ_FAILED: {exc}"

    if suffix in UNSUPPORTED_IMAGE_EXTENSIONS:
        return False, f"UNSUPPORTED_IMAGE_FILE: {suffix}"

    return False, f"UNSUPPORTED_FILE_TYPE: {suffix or 'NO_EXTENSION'}"


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
        key = re.sub(r"\s+", " ", comment.strip().lower())
        if key and key not in seen:
            seen.add(key)
            unique.append(comment.strip())
    if not unique:
        return ""
    unique.sort(key=lambda x: (-len(x), x))
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


def format_final_feedback(result: Dict[str, Any]) -> str:
    lines = []

    summary = (result.get("summary") or "").strip()
    if summary:
        lines.append(f"Summary: {summary}")

    strengths = [s.strip() for s in result.get("strengths", []) if str(s).strip()]
    if strengths:
        lines.append("Strengths:")
        lines.extend([f"- {item}" for item in strengths])

    improvements = [s.strip() for s in result.get("improvements", []) if str(s).strip()]
    if improvements:
        lines.append("Improvements:")
        lines.extend([f"- {item}" for item in improvements])

    criterion_scores = result.get("criterion_scores", []) or []
    if criterion_scores:
        lines.append("Criterion breakdown:")
        for row in criterion_scores:
            lines.append(
                f"- {row.get('criterion', 'Criterion')}: {row.get('score', 0)}/{row.get('max_score', 0)} | {row.get('comment', '')}"
            )

    final_feedback = (result.get("final_feedback") or "").strip()
    if final_feedback:
        lines.append("Final feedback:")
        lines.append(final_feedback)

    # ❌ הורדנו את ה-flags מהפלט

    return "\n".join(lines).strip()


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
                    format_final_feedback(result),
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

        final_result_text = format_final_feedback(final_result)
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
