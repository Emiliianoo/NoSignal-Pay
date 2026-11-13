"""Test top-ups: fixed amounts, capped per user over the last 24 hours."""

from dataclasses import dataclass
from datetime import timedelta
from uuid import UUID

from sqlalchemy import BigInteger, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import Transaction
from app.models.transaction import TOP_UP
from app.services import idempotency, ledger
from app.services.wallet import get_system_account, get_wallet

ALLOWED_AMOUNTS_CENTS = (10_000, 50_000, 100_000)  # $100, $500 and $1,000 MXN
DAILY_LIMIT_CENTS = 1_000_000  # $10,000 MXN per user in any 24-hour window
LIMIT_WINDOW = timedelta(hours=24)


@dataclass(frozen=True)
class TopUpResult:
    transaction: Transaction
    replayed: bool  # True when the same key and body were already processed


def top_up(db: Session, *, user_id: UUID, amount_cents: int, idempotency_key: str) -> TopUpResult:
    expected_hash = idempotency.request_hash(f"{TOP_UP}:{amount_cents}")

    if amount_cents not in ALLOWED_AMOUNTS_CENTS:
        raise ApiError(
            422,
            "top_up_amount_not_allowed",
            "Top-ups must be $100, $500 or $1,000.",
            {"allowed_cents": list(ALLOWED_AMOUNTS_CENTS)},
        )

    # At most two rounds; the second only runs if the INSERT lost a race on the same key.
    for _ in range(2):
        # Lock the wallet BEFORE looking up the key. A request that waited here behind another
        # one with the same key then sees the committed winner and replays it, instead of
        # counting the winner's money against the 24-hour limit and failing.
        wallet = get_wallet(db, user_id, lock=True)

        previous = idempotency.find_previous(
            db, user_id=user_id, idempotency_key=idempotency_key, expected_hash=expected_hash
        )
        if previous is not None:
            db.rollback()  # Nothing to write: release the lock.
            return TopUpResult(previous, replayed=True)

        used_cents = _topped_up_in_window(db, user_id)
        if used_cents + amount_cents > DAILY_LIMIT_CENTS:
            db.rollback()  # Release the lock right away.
            raise ApiError(
                422,
                "top_up_limit_exceeded",
                "Top-ups are limited to $10,000 every 24 hours.",
                {"limit_cents": DAILY_LIMIT_CENTS, "used_cents": used_cents},
            )

        try:
            transaction = ledger.post_transaction(
                db,
                type=TOP_UP,
                amount_cents=amount_cents,
                initiator_user_id=user_id,
                idempotency_key=idempotency_key,
                request_hash=expected_hash,
                movements=[
                    ledger.Movement(get_system_account(db).id, -amount_cents),
                    ledger.Movement(wallet.id, amount_cents),
                ],
            )
            db.commit()
        except IntegrityError as exc:
            db.rollback()
            if idempotency.is_idempotency_conflict(exc):
                continue  # Lost the race: look the key up again and replay the winner.
            raise
        return TopUpResult(transaction, replayed=False)

    # Only reachable if the conflicting row vanished, which the immutable ledger rules out.
    raise RuntimeError("Idempotency conflict could not be resolved.")


def _topped_up_in_window(db: Session, user_id: UUID) -> int:
    """Sum of the user's top-ups in the last 24 hours, measured with the database clock."""
    total = func.coalesce(func.sum(Transaction.amount_cents), 0).cast(BigInteger)
    return db.scalar(
        select(total).where(
            Transaction.initiator_user_id == user_id,
            Transaction.type == TOP_UP,
            Transaction.created_at > func.now() - LIMIT_WINDOW,
        )
    )
