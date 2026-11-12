"""Dependencies shared by routers."""

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models import User

# auto_error=False so a missing header goes through our error format instead of FastAPI's.
# HTTPBearer also adds the "Authorize" button to /docs.
_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise ApiError(401, "not_authenticated", "Missing access token.")

    user_id = decode_access_token(credentials.credentials)
    user = db.get(User, user_id)
    if user is None:
        raise ApiError(401, "not_authenticated", "Invalid token.")
    return user
