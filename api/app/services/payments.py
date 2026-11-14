"""Paying a QR charge (payment request) from one wallet to another.

Everything happens in one database transaction. Locks are always taken in the same order,
payment request first and payer wallet second, so two payments never wait on each other in a
circle (deadlock).
"""

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import Account, PaymentRequest, Transaction, User
from app.models.transaction import PAYMENT
from app.services import idempotency, ledger
from app.services.wallet import get_wallet

PAYMENT_REQUEST_CONSTRAINT = "uq_transactions_payment_request"


@dataclass(frozen=True)
class PaymentResult:
    transaction: Transaction
    replayed: bool  # True when the same key and body were already processed


def pay(
    db: Session, *, payer_id: UUID, payment_request_id: UUID, idempotency_key: str
) -> PaymentResult:
    expected_hash = idempotency.request_hash(f"{PAYMENT}:{payment_request_id}")

    # At most two rounds; the second only runs if the INSERT lost a race on the same key.
    for _ in range(2):
        # 1. Lock the payment request. This comes BEFORE the key lookup (the design doc lists
        # them the other way around): a double tap whose second request waited here sees the
        # committed first payment and replays it, instead of answering "already paid".
        payment_request = db.scalar(
            select(PaymentRequest).where(PaymentRequest.id == payment_request_id).with_for_update()
        )
        if payment_request is None:
            db.rollback()
            raise ApiError(404, "payment_request_not_found", "This payment request does not exist.")

        # 2. Same key again: return the original payment (or 422 if the body changed).
        previous = idempotency.find_previous(
            db, user_id=payer_id, idempotency_key=idempotency_key, expected_hash=expected_hash
        )
        if previous is not None:
            db.rollback()  # Nothing to write: release the locks.
            return PaymentResult(previous, replayed=True)

        # 3. Rules of the charge, in the order the design doc lists the errors.
        _check_payable(db, payment_request, payer_id)

        # 4. Lock the payer's wallet and check the balance while nobody else can spend from it.
        payer_wallet = get_wallet(db, payer_id, lock=True)
        balance_cents = ledger.get_balance(db, payer_wallet.id)
        if balance_cents < payment_request.amount_cents:
            db.rollback()
            raise ApiError(
                422,
                "insufficient_funds",
                "Your balance is not enough for this payment.",
                {"balance_cents": balance_cents, "amount_cents": payment_request.amount_cents},
            )

        # 5. Write the payment: money leaves the payer and reaches the payee.
        amount = payment_request.amount_cents
        try:
            transaction = ledger.post_transaction(
                db,
                type=PAYMENT,
                amount_cents=amount,
                initiator_user_id=payer_id,
                idempotency_key=idempotency_key,
                request_hash=expected_hash,
                payment_request_id=payment_request.id,
                movements=[
                    ledger.Movement(payer_wallet.id, -amount),
                    ledger.Movement(payment_request.payee_account_id, amount),
                ],
            )
            db.commit()
        except IntegrityError as exc:
            db.rollback()
            if idempotency.is_idempotency_conflict(exc):
                continue  # Lost the race on the same key: go back and replay the winner.
            if _constraint_name(exc) == PAYMENT_REQUEST_CONSTRAINT:
                # The lock should make this impossible; the UNIQUE constraint is the last word.
                raise _already_paid() from exc
            raise
        return PaymentResult(transaction, replayed=False)

    # Only reachable if the conflicting row vanished, which the immutable ledger rules out.
    raise RuntimeError("Idempotency conflict could not be resolved.")


def describe(db: Session, transaction: Transaction) -> tuple[str, str | None]:
    """Payee name and description of a payment, to build the response (also on a replay)."""
    row = db.execute(
        select(User.display_name, PaymentRequest.description)
        .join(Account, Account.user_id == User.id)
        .join(PaymentRequest, PaymentRequest.payee_account_id == Account.id)
        .where(PaymentRequest.id == transaction.payment_request_id)
    ).one()
    return row.display_name, row.description


def _check_payable(db: Session, payment_request: PaymentRequest, payer_id: UUID) -> None:
    """Raise the right error if the charge can't be paid. Rolls back first to release the lock."""
    already_paid = db.scalar(
        select(Transaction.id).where(Transaction.payment_request_id == payment_request.id)
    )
    if already_paid is not None:
        db.rollback()
        raise _already_paid()

    # The database clock decides, never the phone's.
    if payment_request.expires_at <= db.scalar(select(func.now())):
        db.rollback()
        raise ApiError(410, "payment_request_expired", "This payment request has expired.")

    payee_user_id = db.scalar(
        select(Account.user_id).where(Account.id == payment_request.payee_account_id)
    )
    if payee_user_id == payer_id:
        db.rollback()
        raise ApiError(422, "cannot_pay_own_request", "You cannot pay your own payment request.")


def _already_paid() -> ApiError:
    return ApiError(409, "payment_request_already_paid", "This payment request was already paid.")


def _constraint_name(exc: IntegrityError) -> str | None:
    return getattr(exc.orig.diag, "constraint_name", None)
