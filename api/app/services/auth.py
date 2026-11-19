from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.security import DUMMY_PASSWORD_HASH, hash_password, verify_password
from app.models import Account, User
from app.models.account import USER_WALLET


def normalize_email(email: str) -> str:
    return email.strip().lower()


def register_user(db: Session, *, email: str, password: str, display_name: str) -> User:
    """Create the user and their wallet in one database transaction."""
    user = User(
        email=normalize_email(email),
        display_name=display_name.strip(),
        password_hash=hash_password(password),
    )
    db.add(user)
    try:
        db.flush()  # INSERT the user now so its id exists for the wallet.
        db.add(Account(type=USER_WALLET, user_id=user.id))
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        # The UNIQUE constraint decides, even if two requests with the same email arrive at once.
        if getattr(exc.orig.diag, "constraint_name", None) == "uq_users_email":
            raise ApiError(
                409, "email_already_registered", "An account with this email already exists."
            ) from exc
        raise
    db.refresh(user)  # Load created_at, which the database filled in.
    return user


def authenticate(db: Session, *, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == normalize_email(email)))
    # Same error, and roughly the same time, whether the email or the password is wrong.
    password_hash = user.password_hash if user else DUMMY_PASSWORD_HASH
    if not verify_password(password_hash, password) or user is None:
        raise ApiError(401, "invalid_credentials", "Incorrect email or password.")
    return user
