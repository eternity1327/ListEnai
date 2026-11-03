from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TranscriptUpdate(BaseModel):
    transcript: str = Field(min_length=1)


class AskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=500)


class GenerateRequest(BaseModel):
    mode: Literal["student", "meeting"] = "student"
    level: Literal["beginner", "detailed", "exam"] = "detailed"


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Term(Strict):
    term: str
    meaning: str


class Section(Strict):
    heading: str
    explanation: str
    example: str


class Lesson(Strict):
    title: str
    overview: str
    objectives: list[str]
    sections: list[Section]
    key_terms: list[Term]
    remember: list[str]


class QuizItem(Strict):
    question: str
    correct: str
    wrong: list[str] = Field(min_length=3, max_length=3)
    explanation: str


class Quiz(Strict):
    questions: list[QuizItem] = Field(min_length=10, max_length=10)


class Meeting(Strict):
    title: str
    summary: str
    points: list[str]
    decisions: list[str]
    action_items: list[str]
    to_confirm: list[str]
