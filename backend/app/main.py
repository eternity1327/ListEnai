from fastapi import FastAPI

from app import database
from app.routers import sessions

database.init()

app = FastAPI(title="ListenAI")
app.include_router(sessions.router)


@app.get("/health")
def health():
    return {"status": "running"}
