"""The ledger: the only module allowed to write money (transactions and entries).

Every other service (top-ups, payments, later offline settlement) calls post_transaction().
Rows are only ever inserted: never UPDATE or DELETE a transaction or an entry.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import BigInteger, func, select
from sqlalchemy.orm import Session

from app.models import Entry, Transaction


class LedgerError(ValueError):
    """A transaction would break a ledger rule. Raised before anything is written."""


@dataclass(frozen=True)
class Movement:
    """One side of a transaction: positive money enters the account, negative leaves it."""

    account_id: UUID
    amount_cents: int


def post_transaction(
    db: Session,
    *,
    type: str,
    amount_cents: int,
    initiator_user_id: UUID,
    idempotency_key: str,
    request_hash: str,
    movements: Sequence[Movement],
    payment_request_id: UUID | None = None,
) -> Transaction:
    """Insert a transaction and its entries after checking that the movements balance.

    Only flushes, never commits: the calling service owns the database transaction, so its row
    locks, its checks and these inserts are committed (or rolled back) together.
    """
    _validate(amount_cents, movements)

    transaction = Transaction(
        type=type,
        amount_cents=amount_cents,
        initiator_user_id=initiator_user_id,
        idempotency_key=idempotency_key,
        request_hash=request_hash,
        payment_request_id=payment_request_id,
    )
    db.add(transaction)
    db.flush()  # Sends the INSERT now so transaction.id exists for the entries.

    db.add_all(
        Entry(
            transaction_id=transaction.id,
            account_id=movement.account_id,
            amount_cents=movement.amount_cents,
        )
        for movement in movements
    )
    db.flush()
    return transaction


def get_balance(db: Session, account_id: UUID) -> int:
    """Balance in cents: the sum of the account's entries (0 if it has none)."""
    total = func.coalesce(func.sum(Entry.amount_cents), 0)
    # PostgreSQL's SUM of BIGINT returns NUMERIC (a Decimal in Python); cast it back to an integer.
    return db.scalar(select(total.cast(BigInteger)).where(Entry.account_id == account_id))


def _validate(amount_cents: int, movements: Sequence[Movement]) -> None:
    if len(movements) < 2:
        raise LedgerError("A transaction needs at least two movements.")

    for movement in movements:
        # bool is a subclass of int in Python, so True would otherwise pass as 1.
        if type(movement.amount_cents) is not int:
            raise LedgerError("Movement amounts must be integer cents.")
        if movement.amount_cents == 0:
            raise LedgerError("Movement amounts cannot be zero.")

    account_ids = [movement.account_id for movement in movements]
    if len(set(account_ids)) != len(account_ids):
        raise LedgerError("An account can appear only once per transaction.")

    if sum(movement.amount_cents for movement in movements) != 0:
        raise LedgerError("Movements must sum to zero.")

    money_moved = sum(m.amount_cents for m in movements if m.amount_cents > 0)
    if amount_cents != money_moved:
        raise LedgerError("amount_cents must equal the money moved by the movements.")
