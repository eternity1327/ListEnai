import random
import re
import time

import requests
from pydantic import ValidationError

from app import config
from app.schemas import Lesson, Meeting, Quiz

CONTEXT_TOKENS = 16384
TIMEOUT_SECONDS = 900
RETRIES = 3
CHUNK_WORDS = 60000 if config.CLOUD else 4000
OLLAMA_DOWN = "Ollama is not running. Start Ollama and try again."
ASK_WORDS = 2500
ASK_PARTS = 2
COMMON_WORDS = {
    "the", "and", "are", "was", "for", "how", "why", "who", "what", "when", "where", "which",
    "does", "did", "can", "with", "that", "this", "from", "about", "between", "difference",
    "explain", "describe", "mean", "means", "lecture", "ano", "ang", "mga", "yung", "paano",
}

GROUNDING = (
    "Use only information supported by the transcript. "
    "If part of the transcript is unclear, say so instead of guessing. "
    "Write in the main language of the transcript. "
    "Use plain text only, with no Markdown symbols such as ** or #."
)

LEVELS = {
    "beginner": "Explain like you are teaching a first-year student, with simple words.",
    "detailed": "Give thorough explanations with correct terminology and show how concepts connect.",
    "exam": "Focus on key facts, definitions, formulas, and common misconceptions for exam review.",
}

ASK_PROMPT = (
    "You are ListenAI. Answer the student's question using only the transcript excerpts. "
    "If the excerpts do not cover it, say it was not discussed in the recording. "
    "Answer in a few clear sentences."
)

NOTES_PROMPT = (
    "You are ListenAI. This is one part of a long recording. "
    "Write detailed bullet-point notes covering every concept, definition, example, "
    "formula, name, decision, action item, and deadline in this part."
)

LESSON_PROMPT = (
    "You are ListenAI. Turn the lecture transcript into a structured study lesson. "
    "Cover every topic from the start to the end of the transcript, in order. "
    "Use the transcript's examples for each section, or an empty string if it gives none."
)

QUIZ_PROMPT = (
    "You are ListenAI. Write a 10-question multiple-choice quiz about the lecture transcript. "
    "Each question has one correct answer and exactly three wrong but believable answers. "
    "Keep every answer short, under 15 words, and similar in length. "
    "Spread the questions across the whole transcript. "
    "Exactly one answer may be correct. Never use the words NOT or EXCEPT in a question. "
    "The explanation says why the correct answer is right, based on the transcript."
)

MEETING_PROMPT = (
    "You are ListenAI. Turn the meeting transcript into a meeting report. "
    "List only decisions, action items, owners, and deadlines that were actually stated. "
    "Put anything uncertain or incomplete in to_confirm."
)


def post(url, unreachable, **kwargs):
    for _ in range(RETRIES):
        try:
            response = requests.post(url, timeout=TIMEOUT_SECONDS, **kwargs)
        except requests.ConnectionError:
            raise RuntimeError(unreachable) from None
        if response.status_code != 429:
            break
        time.sleep(float(response.headers.get("retry-after", 20)))
    if not response.ok:
        raise RuntimeError(f"AI error: {response.text[:300]}")
    return response.json()


def ollama_chat(messages, schema):
    body = {
        "model": config.OLLAMA_MODEL,
        "stream": False,
        "think": False,
        "keep_alive": config.KEEP_ALIVE,
        "options": {"num_ctx": CONTEXT_TOKENS, "temperature": 0.3},
        "messages": messages,
    }
    if schema:
        body["format"] = schema.model_json_schema()
    data = post(f"{config.OLLAMA_URL}/api/chat", OLLAMA_DOWN, json=body)
    return data["message"]["content"]


def groq_chat(messages, schema):
    body = {
        "model": config.GROQ_MODEL,
        "temperature": 0.3,
        "reasoning_effort": "low",
        "messages": messages,
    }
    if schema:
        body["response_format"] = {
            "type": "json_schema",
            "json_schema": {"name": schema.__name__, "strict": True, "schema": schema.model_json_schema()},
        }
    headers = {"Authorization": f"Bearer {config.GROQ_KEY}"}
    data = post(f"{config.GROQ_URL}/chat/completions", "Cannot reach the AI service.", json=body, headers=headers)
    return data["choices"][0]["message"]["content"]


def chat(system, transcript, schema=None):
    messages = [
        {"role": "system", "content": f"{system} {GROUNDING}"},
        {"role": "user", "content": f"Transcript:\n{transcript}"},
    ]
    send = groq_chat if config.CLOUD else ollama_chat
    return send(messages, schema).split("</think>")[-1].replace("\u2011", "-").strip()


def ask(system, transcript, schema):
    try:
        return schema.model_validate_json(chat(system, transcript, schema))
    except ValidationError:
        return schema.model_validate_json(chat(system, transcript, schema))


def split(transcript, size=CHUNK_WORDS):
    words = transcript.split()
    return [" ".join(words[i:i + size]) for i in range(0, len(words), size)]


def relevant(transcript, question):
    words = re.findall(r"\w+", question.lower())
    keywords = {word for word in words if len(word) > 2 and word not in COMMON_WORDS}
    parts = split(transcript, ASK_WORDS)
    best = sorted(parts, key=lambda part: -sum(part.lower().count(word) for word in keywords))
    return "\n\n".join(part for part in parts if part in best[:ASK_PARTS])


def answer(transcript, question):
    return chat(ASK_PROMPT, f"{relevant(transcript, question)}\n\nQuestion: {question}")


def condense(transcript, progress):
    parts = split(transcript)
    if len(parts) <= 1:
        return transcript
    notes = []
    for number, part in enumerate(parts, 1):
        progress(f"Reading part {number} of {len(parts)}...")
        notes.append(f"Part {number}:\n{chat(NOTES_PROMPT, part)}")
    return "\n\n".join(notes)


def to_question(item):
    choices = [item.correct, *item.wrong]
    random.shuffle(choices)
    return {
        "question": item.question,
        "choices": choices,
        "answer": choices.index(item.correct),
        "explanation": item.explanation,
    }


def create_lesson(transcript, level, progress):
    progress("Writing the lesson...")
    lesson = ask(f"{LESSON_PROMPT} {LEVELS[level]}", transcript, Lesson)
    progress("Writing the quiz...")
    quiz = ask(QUIZ_PROMPT, transcript, Quiz)
    questions = [to_question(item) for item in quiz.questions]
    return {"type": "lesson", "level": level, **lesson.model_dump(), "quiz": questions}


def create_meeting_report(transcript, progress):
    progress("Writing the meeting report...")
    meeting = ask(MEETING_PROMPT, transcript, Meeting)
    return {"type": "meeting", **meeting.model_dump()}


def create_report(transcript, mode, level, progress):
    source = condense(transcript, progress)
    if mode == "meeting":
        return create_meeting_report(source, progress)
    return create_lesson(source, level, progress)
