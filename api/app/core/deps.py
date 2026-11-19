"""Dependencies shared by routers."""

from typing import Annotated

from fastapi import Depends, Header
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


IDEMPOTENCY_KEY_MIN_LENGTH = 8
IDEMPOTENCY_KEY_MAX_LENGTH = 128


def get_idempotency_key(
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> str:
    """Required on every endpoint that moves money. Any text of 8 to 128 characters.

    It is not forced to be a UUID: offline payments will later use "allowance_id:counter".
    """
    if idempotency_key is None:
        raise ApiError(400, "idempotency_key_required", "Missing Idempotency-Key header.")
    if not IDEMPOTENCY_KEY_MIN_LENGTH <= len(idempotency_key) <= IDEMPOTENCY_KEY_MAX_LENGTH:
        raise ApiError(
            400,
            "idempotency_key_invalid",
            "Idempotency-Key must be 8 to 128 characters long.",
            {"min_length": IDEMPOTENCY_KEY_MIN_LENGTH, "max_length": IDEMPOTENCY_KEY_MAX_LENGTH},
        )
    return idempotency_key
