"""Shared pytest fixtures. Tests run against a separate PostgreSQL database, never SQLite.

DATABASE_URL is switched to "<db>_test" BEFORE importing the app, so the app's engine, the API
under TestClient and Alembic all point at the test database and never touch development data.
"""

import os

from sqlalchemy.engine import make_url

_dev_url = make_url(os.environ["DATABASE_URL"])
TEST_DATABASE_URL = _dev_url.set(database=f"{_dev_url.database}_test")
os.environ["DATABASE_URL"] = TEST_DATABASE_URL.render_as_string(hide_password=False)

import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

import app.models  # noqa: E402, F401
from app.db.base import Base  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.models import Account, User  # noqa: E402
from app.models.account import SYSTEM_FUNDING, USER_WALLET  # noqa: E402


def _create_test_database() -> None:
    """Create the test database once if it does not exist yet."""
    admin_engine = create_engine(
        TEST_DATABASE_URL.set(database="postgres"), isolation_level="AUTOCOMMIT"
    )
    with admin_engine.connect() as conn:
        exists = conn.scalar(
            text("SELECT 1 FROM pg_database WHERE datname = :name"),
            {"name": TEST_DATABASE_URL.database},
        )
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{TEST_DATABASE_URL.database}"'))
    admin_engine.dispose()


@pytest.fixture(scope="session", autouse=True)
def test_database() -> None:
    """Once per test run: create the test database and apply the real migrations to it."""
    _create_test_database()
    command.upgrade(Config("alembic.ini"), "head")


@pytest.fixture
def db() -> Session:
    """A session on an empty database (plus the system account).

    Tables are emptied with TRUNCATE instead of rolling back a wrapping transaction, because the
    concurrency tests need real commits from several connections.
    """
    tables = ", ".join(table.name for table in Base.metadata.sorted_tables)
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE {tables} RESTART IDENTITY CASCADE"))

    session = SessionLocal()
    # TRUNCATE also removed the system_funding row created by the migration.
    session.add(Account(type=SYSTEM_FUNDING, user_id=None))
    session.commit()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def make_user(db: Session):
    """Factory that creates a committed user with their wallet: make_user("ana@x.com")."""

    def _make_user(email: str = "ana@example.com", display_name: str = "Ana") -> User:
        user = User(email=email, display_name=display_name, password_hash="not-a-real-hash")
        db.add(user)
        db.flush()
        db.add(Account(type=USER_WALLET, user_id=user.id))
        db.commit()
        return user

    return _make_user


@pytest.fixture
def client(db: Session):
    """HTTP client for the real app, on a freshly emptied test database."""
    from fastapi.testclient import TestClient

    from app.main import app

    return TestClient(app)
