import os
import sqlite3
from contextlib import closing
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

STORAGE = Path(__file__).resolve().parent.parent / "storage"
AUDIO_DIR = STORAGE / "audio"
DB_PATH = STORAGE / "listenai.db"
DATABASE_URL = os.getenv("DATABASE_URL")
ID = "SERIAL PRIMARY KEY" if DATABASE_URL else "INTEGER PRIMARY KEY AUTOINCREMENT"

SCHEMA = f"""
CREATE TABLE IF NOT EXISTS sessions (
    id {ID},
    title TEXT NOT NULL,
    created_at TEXT NOT NULL,
    audio_path TEXT NOT NULL,
    status TEXT NOT NULL,
    error TEXT,
    transcript TEXT,
    mode TEXT,
    level TEXT,
    report TEXT,
    progress TEXT
)
"""

QUESTIONS = f"""
CREATE TABLE IF NOT EXISTS questions (
    id {ID},
    session_id INTEGER NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    created_at TEXT NOT NULL
)
"""

RESET_INTERRUPTED = """
UPDATE sessions SET progress = NULL, status = CASE
    WHEN status = 'transcribing' THEN 'uploaded'
    WHEN report IS NOT NULL THEN 'ready'
    ELSE 'transcribed'
END
WHERE status IN ('transcribing', 'generating')
"""


def connect():
    if DATABASE_URL:
        return psycopg.connect(DATABASE_URL, row_factory=dict_row, prepare_threshold=None)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def run(sql, params):
    if DATABASE_URL:
        sql = sql.replace("?", "%s")
    with closing(connect()) as conn, conn:
        cursor = conn.execute(sql, params)
        return [dict(row) for row in cursor.fetchall()] if cursor.description else []


def query(sql, params=()):
    return run(sql, params)


def execute(sql, params=()):
    run(sql, params)


def insert(sql, params=()):
    return run(f"{sql} RETURNING id", params)[0]["id"]


def init():
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    execute(SCHEMA)
    execute(QUESTIONS)
    execute(RESET_INTERRUPTED)
