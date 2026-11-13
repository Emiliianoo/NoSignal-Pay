"""Idempotency for operations that move money.

The key identifies one user intent (not one HTTP request) and lives in the transaction row:
UNIQUE (initiator_user_id, idempotency_key) is the real guarantee. Looking it up first only saves
work in the common case, because two requests with the same key can arrive at the same time.
"""

import hashlib
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import Transaction

IDEMPOTENCY_CONSTRAINT = "uq_transactions_idempotency"


def request_hash(canonical_request: str) -> str:
    """SHA-256 of a canonical text such as "top_up:50000" or "payment:<payment_request_id>".

    Hashing a canonical text instead of the raw JSON means spaces or key order don't matter.
    """
    return hashlib.sha256(canonical_request.encode()).hexdigest()


def find_previous(
    db: Session, *, user_id: UUID, idempotency_key: str, expected_hash: str
) -> Transaction | None:
    """The transaction already created with this key, or None if the key is new.

    Raises idempotency_key_reused if the key was used before for a different request.
    """
    previous = db.scalar(
        select(Transaction).where(
            Transaction.initiator_user_id == user_id,
            Transaction.idempotency_key == idempotency_key,
        )
    )
    if previous is not None and previous.request_hash != expected_hash:
        raise ApiError(
            422,
            "idempotency_key_reused",
            "This Idempotency-Key was already used for a different request.",
        )
    return previous


def is_idempotency_conflict(exc: IntegrityError) -> bool:
    """True when the INSERT lost a race against another request with the same key."""
    return getattr(exc.orig.diag, "constraint_name", None) == IDEMPOTENCY_CONSTRAINT
