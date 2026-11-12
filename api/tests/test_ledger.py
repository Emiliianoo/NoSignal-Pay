from datetime import UTC, datetime, timedelta
from uuid import UUID

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Account, Entry, PaymentRequest, Transaction, User
from app.models.account import SYSTEM_FUNDING
from app.models.transaction import PAYMENT, TOP_UP
from app.services.ledger import LedgerError, Movement, get_balance, post_transaction

FAKE_HASH = "0" * 64


def wallet_of(db: Session, user: User) -> UUID:
    return db.scalar(select(Account.id).where(Account.user_id == user.id))


def system_account(db: Session) -> UUID:
    return db.scalar(select(Account.id).where(Account.type == SYSTEM_FUNDING))


def count(db: Session, model: type) -> int:
    return db.scalar(select(func.count()).select_from(model))


def top_up(db: Session, user: User, amount_cents: int, key: str) -> Transaction:
    return post_transaction(
        db,
        type=TOP_UP,
        amount_cents=amount_cents,
        initiator_user_id=user.id,
        idempotency_key=key,
        request_hash=FAKE_HASH,
        movements=[
            Movement(system_account(db), -amount_cents),
            Movement(wallet_of(db, user), amount_cents),
        ],
    )


def test_movements_that_do_not_sum_to_zero_write_nothing(db: Session, make_user) -> None:
    ana = make_user()

    with pytest.raises(LedgerError):
        post_transaction(
            db,
            type=TOP_UP,
            amount_cents=50_000,
            initiator_user_id=ana.id,
            idempotency_key="key-00001",
            request_hash=FAKE_HASH,
            movements=[
                Movement(system_account(db), -50_000),
                Movement(wallet_of(db, ana), 40_000),
            ],
        )
    db.rollback()

    assert count(db, Transaction) == 0
    assert count(db, Entry) == 0


@pytest.mark.parametrize(
    "case",
    ["single_movement", "zero_movement", "repeated_account", "amount_mismatch", "float_amount"],
)
def test_invalid_movements_are_rejected(db: Session, make_user, case: str) -> None:
    ana = make_user()
    system, wallet = system_account(db), wallet_of(db, ana)
    movements, amount = {
        "single_movement": ([Movement(wallet, 100)], 100),
        "zero_movement": ([Movement(system, 0), Movement(wallet, 0)], 100),
        "repeated_account": ([Movement(wallet, -100), Movement(wallet, 100)], 100),
        "amount_mismatch": ([Movement(system, -100), Movement(wallet, 100)], 999),
        "float_amount": ([Movement(system, -100.0), Movement(wallet, 100.0)], 100),
    }[case]

    with pytest.raises(LedgerError):
        post_transaction(
            db,
            type=TOP_UP,
            amount_cents=amount,
            initiator_user_id=ana.id,
            idempotency_key="key-00001",
            request_hash=FAKE_HASH,
            movements=movements,
        )


def test_top_up_moves_money_from_system_account_to_wallet(db: Session, make_user) -> None:
    ana = make_user()

    top_up(db, ana, 50_000, "key-00001")
    db.commit()

    assert get_balance(db, wallet_of(db, ana)) == 50_000
    assert get_balance(db, system_account(db)) == -50_000
    assert count(db, Entry) == 2


def test_account_without_entries_has_zero_balance(db: Session, make_user) -> None:
    ana = make_user()

    balance = get_balance(db, wallet_of(db, ana))

    assert balance == 0
    assert type(balance) is int


def test_post_transaction_does_not_commit(db: Session, make_user) -> None:
    ana = make_user()

    top_up(db, ana, 10_000, "key-00001")
    db.rollback()  # The caller decides; rolling back must leave no trace.

    assert count(db, Transaction) == 0
    assert get_balance(db, wallet_of(db, ana)) == 0


def test_all_entries_sum_to_zero_after_several_operations(db: Session, make_user) -> None:
    ana = make_user("ana@example.com", "Ana")
    luis = make_user("luis@example.com", "Luis")
    top_up(db, ana, 100_000, "key-00001")
    top_up(db, luis, 50_000, "key-00002")

    request = PaymentRequest(
        payee_account_id=wallet_of(db, luis),
        amount_cents=12_000,
        expires_at=datetime.now(UTC) + timedelta(minutes=10),
    )
    db.add(request)
    db.flush()
    post_transaction(
        db,
        type=PAYMENT,
        amount_cents=12_000,
        initiator_user_id=ana.id,
        idempotency_key="key-00003",
        request_hash=FAKE_HASH,
        payment_request_id=request.id,
        movements=[
            Movement(wallet_of(db, ana), -12_000),
            Movement(wallet_of(db, luis), 12_000),
        ],
    )
    db.commit()

    assert db.scalar(select(func.sum(Entry.amount_cents))) == 0
    assert get_balance(db, wallet_of(db, ana)) == 88_000
    assert get_balance(db, wallet_of(db, luis)) == 62_000
    # The system account is the negative of all money in circulation.
    assert get_balance(db, system_account(db)) == -150_000
