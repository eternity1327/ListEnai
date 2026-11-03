from fastapi import Depends, FastAPI, Header, HTTPException

from app import config
from app import database
from app.routers import sessions

database.init()


def check_app_key(x_app_key: str = Header("")):
    if config.APP_KEY and x_app_key != config.APP_KEY:
        raise HTTPException(401, "This app is not allowed to use the server.")


app = FastAPI(title="ListenAI")
app.include_router(sessions.router, dependencies=[Depends(check_app_key)])


@app.get("/health")
def health():
    return {"status": "running"}
