from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import JWT_ALGORITHM
from app.models import Account, User
from app.models.account import USER_WALLET
from app.services.ledger import get_balance

REGISTER = "/api/v1/auth/register"
LOGIN = "/api/v1/auth/login"
ME = "/api/v1/users/me"

ANA = {"email": "ana@example.com", "password": "correct-horse", "display_name": "Ana"}


def register(client: TestClient, **overrides: str):
    return client.post(REGISTER, json={**ANA, **overrides})


def error_code(response) -> str:
    return response.json()["error"]["code"]


def auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ---------- register ----------


def test_register_creates_user_with_empty_wallet_and_returns_token(
    client: TestClient, db: Session
) -> None:
    response = register(client)

    assert response.status_code == 201
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["expires_in"] == settings.jwt_expires_seconds
    assert body["user"]["email"] == "ana@example.com"
    assert body["user"]["display_name"] == "Ana"
    assert "password" not in str(body)

    user = db.scalar(select(User).where(User.email == "ana@example.com"))
    wallet = db.scalar(select(Account).where(Account.user_id == user.id))
    assert wallet.type == USER_WALLET
    assert get_balance(db, wallet.id) == 0


def test_register_stores_email_in_lowercase(client: TestClient) -> None:
    response = register(client, email="Ana@Example.COM")

    assert response.status_code == 201
    assert response.json()["user"]["email"] == "ana@example.com"


def test_register_never_stores_the_plain_password(client: TestClient, db: Session) -> None:
    register(client)

    user = db.scalar(select(User))
    assert user.password_hash != ANA["password"]
    assert user.password_hash.startswith("$argon2id$")


def test_register_duplicate_email_ignoring_case_is_409(client: TestClient, db: Session) -> None:
    register(client)

    response = register(client, email="ANA@example.com")

    assert response.status_code == 409
    assert error_code(response) == "email_already_registered"
    assert len(db.scalars(select(User)).all()) == 1


def test_register_short_password_is_validation_error(client: TestClient) -> None:
    response = register(client, password="short")

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["details"]["errors"][0]["field"] == "password"


def test_register_rejects_unknown_fields(client: TestClient) -> None:
    response = client.post(REGISTER, json={**ANA, "is_admin": True})

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


# ---------- login ----------


def test_login_returns_token_for_correct_credentials(client: TestClient) -> None:
    register(client)

    response = client.post(LOGIN, json={"email": "ANA@example.com", "password": "correct-horse"})

    assert response.status_code == 200
    assert response.json()["user"]["email"] == "ana@example.com"


def test_login_wrong_password_and_unknown_email_give_the_same_error(client: TestClient) -> None:
    register(client)

    wrong_password = client.post(LOGIN, json={"email": ANA["email"], "password": "nope-nope"})
    unknown_email = client.post(LOGIN, json={"email": "who@example.com", "password": "nope-nope"})

    assert wrong_password.status_code == unknown_email.status_code == 401
    assert wrong_password.json() == unknown_email.json()
    assert error_code(wrong_password) == "invalid_credentials"


# ---------- /users/me ----------


def test_me_returns_the_token_owner(client: TestClient) -> None:
    token = register(client).json()["access_token"]

    response = client.get(ME, headers=auth_header(token))

    assert response.status_code == 200
    assert response.json()["email"] == "ana@example.com"


def test_me_without_token_is_not_authenticated(client: TestClient) -> None:
    response = client.get(ME)

    assert response.status_code == 401
    assert error_code(response) == "not_authenticated"


def test_me_with_garbage_token_is_not_authenticated(client: TestClient) -> None:
    response = client.get(ME, headers=auth_header("not-a-jwt"))

    assert response.status_code == 401
    assert error_code(response) == "not_authenticated"


def test_me_with_token_signed_by_another_secret_is_not_authenticated(client: TestClient) -> None:
    user_id = register(client).json()["user"]["id"]
    now = datetime.now(UTC)
    forged = jwt.encode(
        {"sub": user_id, "iat": now, "exp": now + timedelta(hours=1)},
        "x" * 32,
        algorithm=JWT_ALGORITHM,
    )

    response = client.get(ME, headers=auth_header(forged))

    assert response.status_code == 401
    assert error_code(response) == "not_authenticated"


def test_me_with_expired_token_is_token_expired(client: TestClient) -> None:
    user_id = register(client).json()["user"]["id"]
    past = datetime.now(UTC) - timedelta(days=2)
    expired = jwt.encode(
        {"sub": user_id, "iat": past, "exp": past + timedelta(days=1)},
        settings.jwt_secret,
        algorithm=JWT_ALGORITHM,
    )

    response = client.get(ME, headers=auth_header(expired))

    assert response.status_code == 401
    assert error_code(response) == "token_expired"


def test_me_for_a_user_that_no_longer_exists_is_not_authenticated(client: TestClient) -> None:
    now = datetime.now(UTC)
    token = jwt.encode(
        {"sub": str(uuid4()), "iat": now, "exp": now + timedelta(hours=1)},
        settings.jwt_secret,
        algorithm=JWT_ALGORITHM,
    )

    response = client.get(ME, headers=auth_header(token))

    assert response.status_code == 401
    assert error_code(response) == "not_authenticated"
