"""Password hashing (argon2id) and access tokens (JWT HS256)."""

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import settings
from app.core.errors import ApiError

JWT_ALGORITHM = "HS256"

# argon2-cffi's PasswordHasher uses argon2id with safe default parameters.
_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str, password: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


# Used when the email does not exist, so a failed login takes the same time either way
# and response timing does not reveal which emails are registered.
DUMMY_PASSWORD_HASH = hash_password("not-a-real-password")


def create_access_token(user_id: UUID) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(seconds=settings.jwt_expires_seconds),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> UUID:
    """Return the user id inside a valid token, or raise token_expired / not_authenticated."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[JWT_ALGORITHM],
            options={"require": ["sub", "iat", "exp"]},
        )
        return UUID(payload["sub"])
    except jwt.ExpiredSignatureError as exc:
        raise ApiError(401, "token_expired", "Session expired. Log in again.") from exc
    except (jwt.InvalidTokenError, ValueError) as exc:
        raise ApiError(401, "not_authenticated", "Invalid token.") from exc
