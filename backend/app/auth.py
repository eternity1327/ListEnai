from fastapi import Header, HTTPException
from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app import config

LOCAL_USER = "local"
google_request = google_requests.Request()


def current_user(authorization: str = Header("")):
    if not config.GOOGLE_CLIENT_ID:
        return LOCAL_USER
    token = authorization.removeprefix("Bearer ").strip()
    try:
        return id_token.verify_oauth2_token(token, google_request, config.GOOGLE_CLIENT_ID)["sub"]
    except (ValueError, GoogleAuthError):
        raise HTTPException(401, "Please sign in again.") from None
