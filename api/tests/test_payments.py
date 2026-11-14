"""POST /payments. Payment requests are inserted directly in the database: the
POST /payment-requests endpoint is built separately."""

import hashlib
import threading
from datetime import timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.main import app
from app.models import Entry, PaymentRequest, Transaction

REGISTER = "/api/v1/auth/register"
WALLET = "/api/v1/wallet"
TOP_UPS = "/api/v1/wallet/top-ups"
PAYMENTS = "/api/v1/payments"


# ---------- helpers ----------


def register(client: TestClient, email: str, name: str) -> dict[str, str]:
    body = {"email": email, "password": "correct-horse", "display_name": name}
    token = client.post(REGISTER, json=body).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def fund(client: TestClient, auth: dict[str, str], *amounts: int) -> None:
    for amount in amounts:
        headers = {**auth, "Idempotency-Key": f"fund-{uuid4()}"}
        assert (
            client.post(TOP_UPS, json={"amount_cents": amount}, headers=headers).status_code == 201
        )


def balance(client: TestClient, auth: dict[str, str]) -> int:
    return client.get(WALLET, headers=auth).json()["balance_cents"]


def wallet_id(client: TestClient, auth: dict[str, str]) -> UUID:
    return UUID(client.get(WALLET, headers=auth).json()["account_id"])


def create_request(
    db: Session,
    payee_wallet: UUID,
    amount_cents: int,
    description: str | None = None,
    expired: bool = False,
) -> UUID:
    """Inserts a payment request (as POST /payment-requests will) and commits it."""
    now = db.scalar(select(func.now()))
    if expired:
        created_at, expires_at = now - timedelta(minutes=20), now - timedelta(minutes=10)
    else:
        created_at, expires_at = now, now + timedelta(minutes=10)
    request = PaymentRequest(
        payee_account_id=payee_wallet,
        amount_cents=amount_cents,
        description=description,
        created_at=created_at,
        expires_at=expires_at,
    )
    db.add(request)
    db.commit()
    return request.id


def pay(client: TestClient, auth: dict[str, str], request_id, key: str | None = "pay-key-0001"):
    headers = dict(auth)
    if key is not None:
        headers["Idempotency-Key"] = key
    return client.post(PAYMENTS, json={"payment_request_id": str(request_id)}, headers=headers)


def error_code(response) -> str:
    return response.json()["error"]["code"]


def count_transactions(db: Session, type_: str = "payment") -> int:
    db.expire_all()  # Read what other connections committed.
    return db.scalar(select(func.count()).select_from(Transaction).where(Transaction.type == type_))


def ledger_total(db: Session) -> int:
    db.expire_all()
    return db.scalar(select(func.coalesce(func.sum(Entry.amount_cents), 0)))


def run_at_the_same_time(*requests):
    """Run each callable in its own thread, released together by a barrier."""
    barrier = threading.Barrier(len(requests))
    results = [None] * len(requests)

    def worker(index, request):
        barrier.wait()
        results[index] = request()

    threads = [threading.Thread(target=worker, args=pair) for pair in enumerate(requests)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    return results


@pytest.fixture
def ana(client: TestClient) -> dict[str, str]:
    """The payer, with $1,000."""
    auth = register(client, "ana@example.com", "Ana Torres")
    fund(client, auth, 100_000)
    return auth


@pytest.fixture
def luis(client: TestClient) -> dict[str, str]:
    """The payee, starting at $0."""
    return register(client, "luis@example.com", "Luis Méndez")


# ---------- happy path ----------


def test_payment_moves_money_from_payer_to_payee(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 8_550, "Café y pan")

    response = pay(client, ana, request_id)

    assert response.status_code == 201
    assert "Idempotent-Replayed" not in response.headers
    body = response.json()
    assert body["balance_cents"] == 100_000 - 8_550
    assert body["transaction"]["type"] == "payment"
    assert body["transaction"]["direction"] == "out"
    assert body["transaction"]["amount_cents"] == 8_550
    assert body["transaction"]["counterparty_name"] == "Luis Méndez"
    assert body["transaction"]["description"] == "Café y pan"
    assert balance(client, ana) == 91_450
    assert balance(client, luis) == 8_550
    assert ledger_total(db) == 0


def test_payment_stores_the_canonical_request_hash(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)

    pay(client, ana, request_id)

    db.expire_all()
    stored = db.scalar(select(Transaction).where(Transaction.type == "payment"))
    assert stored.payment_request_id == request_id
    assert stored.request_hash == hashlib.sha256(f"payment:{request_id}".encode()).hexdigest()


# ---------- request validation ----------


def test_payment_requires_idempotency_key(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)

    response = pay(client, ana, request_id, key=None)

    assert response.status_code == 400
    assert error_code(response) == "idempotency_key_required"


def test_payment_requires_token(client, db, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)

    response = client.post(
        PAYMENTS, json={"payment_request_id": str(request_id)}, headers={"Idempotency-Key": "k" * 8}
    )

    assert response.status_code == 401


def test_payment_rejects_an_amount_in_the_body(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)

    response = client.post(
        PAYMENTS,
        json={"payment_request_id": str(request_id), "amount_cents": 1},
        headers={**ana, "Idempotency-Key": "pay-key-0001"},
    )

    assert response.status_code == 422
    assert error_code(response) == "validation_error"
    assert count_transactions(db) == 0


def test_payment_rejects_an_id_that_is_not_a_uuid(client, ana) -> None:
    response = pay(client, ana, "not-a-uuid")

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


# ---------- rules of the charge ----------


def test_unknown_request_is_404(client, ana) -> None:
    response = pay(client, ana, uuid4())

    assert response.status_code == 404
    assert error_code(response) == "payment_request_not_found"


def test_expired_request_is_410(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000, expired=True)

    response = pay(client, ana, request_id)

    assert response.status_code == 410
    assert error_code(response) == "payment_request_expired"
    assert balance(client, ana) == 100_000


def test_cannot_pay_own_request(client, db, ana) -> None:
    request_id = create_request(db, wallet_id(client, ana), 1_000)

    response = pay(client, ana, request_id)

    assert response.status_code == 422
    assert error_code(response) == "cannot_pay_own_request"


def test_insufficient_funds_writes_nothing(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 100_001)

    response = pay(client, ana, request_id)

    assert response.status_code == 422
    assert error_code(response) == "insufficient_funds"
    assert response.json()["error"]["details"] == {
        "balance_cents": 100_000,
        "amount_cents": 100_001,
    }
    assert count_transactions(db) == 0
    assert balance(client, ana) == 100_000


def test_paying_a_paid_request_again_with_a_new_key_is_409(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)
    assert pay(client, ana, request_id, key="first-key-01").status_code == 201

    response = pay(client, ana, request_id, key="second-key-02")

    assert response.status_code == 409
    assert error_code(response) == "payment_request_already_paid"
    assert balance(client, ana) == 99_000


def test_someone_else_cannot_pay_a_paid_request(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)
    pay(client, ana, request_id)
    carla = register(client, "carla@example.com", "Carla Ruiz")
    fund(client, carla, 10_000)

    response = pay(client, carla, request_id)

    assert response.status_code == 409
    assert error_code(response) == "payment_request_already_paid"
    assert balance(client, carla) == 10_000


# ---------- idempotency ----------


def test_same_key_and_body_replays_the_payment(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)
    first = pay(client, ana, request_id)

    second = pay(client, ana, request_id)

    assert second.status_code == 201
    assert second.headers["Idempotent-Replayed"] == "true"
    assert second.json()["transaction"] == first.json()["transaction"]
    assert count_transactions(db) == 1
    assert balance(client, ana) == 99_000
    assert balance(client, luis) == 1_000


def test_same_key_with_another_request_is_422(client, db, ana, luis) -> None:
    first_request = create_request(db, wallet_id(client, luis), 1_000)
    other_request = create_request(db, wallet_id(client, luis), 2_000)
    pay(client, ana, first_request)

    response = pay(client, ana, other_request)

    assert response.status_code == 422
    assert error_code(response) == "idempotency_key_reused"
    assert count_transactions(db) == 1


def test_a_failed_attempt_does_not_use_up_the_key(client, db, ana, luis) -> None:
    expensive = create_request(db, wallet_id(client, luis), 200_000)
    assert error_code(pay(client, ana, expensive, key="retry-key-01")) == "insufficient_funds"
    fund(client, ana, 100_000)

    response = pay(client, ana, expensive, key="retry-key-01")

    assert response.status_code == 201


# ---------- concurrency (real commits from several connections) ----------


def test_double_tap_with_the_same_key_creates_one_payment(client, db, ana, luis) -> None:
    request_id = create_request(db, wallet_id(client, luis), 1_000)

    def send():
        return pay(TestClient(app), ana, request_id, key="double-tap-01")

    first, second = run_at_the_same_time(send, send)

    assert first.status_code == second.status_code == 201
    assert first.json()["transaction"]["id"] == second.json()["transaction"]["id"]
    replayed = [r.headers.get("Idempotent-Replayed") for r in (first, second)]
    assert replayed.count("true") == 1
    assert count_transactions(db) == 1
    assert balance(client, ana) == 99_000


def test_two_people_paying_the_same_request_at_once(client, db, ana, luis) -> None:
    carla = register(client, "carla@example.com", "Carla Ruiz")
    fund(client, carla, 100_000)
    request_id = create_request(db, wallet_id(client, luis), 5_000)

    results = run_at_the_same_time(
        lambda: pay(TestClient(app), ana, request_id, key="ana-key-0001"),
        lambda: pay(TestClient(app), carla, request_id, key="carla-key-001"),
    )

    assert sorted(r.status_code for r in results) == [201, 409]
    assert count_transactions(db) == 1
    assert balance(client, luis) == 5_000
    assert ledger_total(db) == 0


def test_two_payments_cannot_spend_the_same_money(client, db, luis) -> None:
    pedro = register(client, "pedro@example.com", "Pedro")
    fund(client, pedro, 10_000)  # $100
    first = create_request(db, wallet_id(client, luis), 6_000)  # $60
    second = create_request(db, wallet_id(client, luis), 6_000)  # $60

    results = run_at_the_same_time(
        lambda: pay(TestClient(app), pedro, first, key="sixty-key-a"),
        lambda: pay(TestClient(app), pedro, second, key="sixty-key-b"),
    )

    assert sorted(r.status_code for r in results) == [201, 422]
    assert [error_code(r) for r in results if r.status_code == 422] == ["insufficient_funds"]
    assert balance(client, pedro) == 4_000
    assert balance(client, luis) == 6_000
    assert ledger_total(db) == 0


def test_crossed_payments_at_the_same_time_both_succeed(client, db, ana, luis) -> None:
    """Ana pays Luis while Luis pays Ana. Neither may wait forever for the other."""
    fund(client, luis, 100_000)
    ana_to_luis = create_request(db, wallet_id(client, luis), 1_000)
    luis_to_ana = create_request(db, wallet_id(client, ana), 2_000)

    results = run_at_the_same_time(
        lambda: pay(TestClient(app), ana, ana_to_luis, key="cross-key-a"),
        lambda: pay(TestClient(app), luis, luis_to_ana, key="cross-key-b"),
    )

    assert [r.status_code for r in results] == [201, 201]
    assert balance(client, ana) == 100_000 - 1_000 + 2_000
    assert balance(client, luis) == 100_000 + 1_000 - 2_000
    assert ledger_total(db) == 0
