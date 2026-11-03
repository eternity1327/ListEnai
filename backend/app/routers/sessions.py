import json
import shutil
from datetime import datetime
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, UploadFile

from app import database as db
from app.schemas import AskRequest, GenerateRequest, TranscriptUpdate
from app.services import ai, transcription

router = APIRouter(prefix="/sessions", tags=["sessions"])

AUDIO_TYPES = {".m4a", ".mp3", ".wav", ".aac", ".ogg", ".opus", ".flac", ".webm", ".mp4"}
MAX_BYTES = 300 * 1024 * 1024
BUSY = {"transcribing", "generating"}


def find(session_id):
    rows = db.query("SELECT * FROM sessions WHERE id = ?", (session_id,))
    if not rows:
        raise HTTPException(404, "Session not found.")
    session = rows[0]
    session["report"] = json.loads(session["report"]) if session["report"] else None
    return session


def find_idle(session_id):
    session = find(session_id)
    if session["status"] in BUSY:
        raise HTTPException(409, "This session is still processing.")
    return session


def save_upload(file):
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in AUDIO_TYPES:
        raise HTTPException(400, f"Unsupported audio type '{suffix}'.")
    path = db.AUDIO_DIR / f"{uuid4().hex}{suffix}"
    with path.open("wb") as out:
        shutil.copyfileobj(file.file, out)
    size = path.stat().st_size
    if 0 < size <= MAX_BYTES:
        return path
    path.unlink()
    raise HTTPException(400, "The audio file is empty or larger than 300 MB.")


@router.get("")
def list_sessions():
    return db.query("SELECT id, title, created_at, status, mode FROM sessions ORDER BY id DESC")


@router.post("", status_code=201)
def create_session(tasks: BackgroundTasks, title: str = Form(...), file: UploadFile = File(...)):
    if not title.strip():
        raise HTTPException(400, "Title is required.")
    path = save_upload(file)
    created_at = datetime.now().isoformat(timespec="seconds")
    session_id = db.insert(
        "INSERT INTO sessions (title, created_at, audio_path, status) VALUES (?, ?, ?, 'uploaded')",
        (title.strip(), created_at, str(path)),
    )
    return start_transcription(session_id, tasks)


@router.get("/{session_id}")
def get_session(session_id: int):
    return find(session_id)


@router.post("/{session_id}/transcribe", status_code=202)
def start_transcription(session_id: int, tasks: BackgroundTasks):
    session = find_idle(session_id)
    if not Path(session["audio_path"]).exists():
        raise HTTPException(409, "The audio is no longer on the server. Upload it again.")
    db.execute("UPDATE sessions SET status = 'transcribing', error = NULL, progress = NULL WHERE id = ?", (session_id,))
    tasks.add_task(run_transcription, session_id, session["audio_path"])
    return find(session_id)


@router.put("/{session_id}/transcript")
def update_transcript(session_id: int, body: TranscriptUpdate):
    session = find_idle(session_id)
    status = "transcribed" if session["status"] == "uploaded" else session["status"]
    db.execute(
        "UPDATE sessions SET transcript = ?, status = ? WHERE id = ?",
        (body.transcript.strip(), status, session_id),
    )
    return find(session_id)


@router.post("/{session_id}/generate", status_code=202)
def start_generation(session_id: int, body: GenerateRequest, tasks: BackgroundTasks):
    session = find_idle(session_id)
    if not session["transcript"]:
        raise HTTPException(409, "Transcribe the audio first.")
    fallback = "ready" if session["report"] else "transcribed"
    db.execute(
        "UPDATE sessions SET status = 'generating', error = NULL, progress = NULL, mode = ?, level = ? "
        "WHERE id = ?",
        (body.mode, body.level, session_id),
    )
    tasks.add_task(run_generation, session_id, session["transcript"], body, fallback)
    return find(session_id)


@router.get("/{session_id}/questions")
def list_questions(session_id: int):
    find(session_id)
    return db.query(
        "SELECT question, answer FROM questions WHERE session_id = ? ORDER BY id",
        (session_id,),
    )


@router.post("/{session_id}/ask")
def ask_question(session_id: int, body: AskRequest):
    session = find(session_id)
    if not session["transcript"]:
        raise HTTPException(409, "Transcribe the audio first.")
    question = body.question.strip()
    try:
        answer = ai.answer(session["transcript"], question)
    except RuntimeError as error:
        raise HTTPException(503, str(error)) from None
    db.execute(
        "INSERT INTO questions (session_id, question, answer, created_at) VALUES (?, ?, ?, ?)",
        (session_id, question, answer, datetime.now().isoformat(timespec="seconds")),
    )
    return {"answer": answer}


@router.delete("/{session_id}", status_code=204)
def delete_session(session_id: int):
    session = find_idle(session_id)
    Path(session["audio_path"]).unlink(missing_ok=True)
    db.execute("DELETE FROM questions WHERE session_id = ?", (session_id,))
    db.execute("DELETE FROM sessions WHERE id = ?", (session_id,))


def tracker(session_id):
    return lambda text: db.execute("UPDATE sessions SET progress = ? WHERE id = ?", (text, session_id))


def run_transcription(session_id, audio_path):
    try:
        text = transcription.transcribe(audio_path, tracker(session_id))
        if not text:
            raise ValueError("No speech was detected in this recording.")
        db.execute(
            "UPDATE sessions SET transcript = ?, status = 'transcribed', progress = NULL WHERE id = ?",
            (text, session_id),
        )
        Path(audio_path).unlink(missing_ok=True)
    except Exception as error:
        db.execute(
            "UPDATE sessions SET status = 'uploaded', error = ?, progress = NULL WHERE id = ?",
            (f"Transcription failed: {error}", session_id),
        )


def run_generation(session_id, transcript, options, fallback):
    try:
        report = ai.create_report(transcript, options.mode, options.level, tracker(session_id))
        db.execute(
            "UPDATE sessions SET report = ?, status = 'ready', progress = NULL WHERE id = ?",
            (json.dumps(report), session_id),
        )
    except Exception as error:
        db.execute(
            "UPDATE sessions SET status = ?, error = ?, progress = NULL WHERE id = ?",
            (fallback, f"Generation failed: {error}", session_id),
        )
