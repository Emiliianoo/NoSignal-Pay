import threading

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.main import app
from app.models import Entry, Transaction

REGISTER = "/api/v1/auth/register"
WALLET = "/api/v1/wallet"
TOP_UPS = "/api/v1/wallet/top-ups"


def register(client: TestClient, email: str = "ana@example.com") -> dict[str, str]:
    body = {"email": email, "password": "correct-horse", "display_name": "Ana"}
    token = client.post(REGISTER, json=body).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def top_up(client: TestClient, auth: dict[str, str], amount, key: str | None = "key-00000001"):
    headers = dict(auth)
    if key is not None:
        headers["Idempotency-Key"] = key
    return client.post(TOP_UPS, json={"amount_cents": amount}, headers=headers)


def balance(client: TestClient, auth: dict[str, str]) -> int:
    return client.get(WALLET, headers=auth).json()["balance_cents"]


def count_transactions(db: Session) -> int:
    db.expire_all()  # Read what other connections committed.
    return db.scalar(select(func.count()).select_from(Transaction))


def error_code(response) -> str:
    return response.json()["error"]["code"]


# ---------- GET /wallet ----------


def test_new_wallet_is_empty(client: TestClient) -> None:
    auth = register(client)

    response = client.get(WALLET, headers=auth)

    assert response.status_code == 200
    body = response.json()
    assert body["balance_cents"] == 0
    assert body["currency"] == "MXN"
    assert body["account_id"]


def test_wallet_requires_token(client: TestClient) -> None:
    response = client.get(WALLET)

    assert response.status_code == 401
    assert error_code(response) == "not_authenticated"


# ---------- POST /wallet/top-ups ----------


@pytest.mark.parametrize("amount", [10_000, 50_000, 100_000])
def test_allowed_top_up_adds_money(client: TestClient, amount: int) -> None:
    auth = register(client)

    response = top_up(client, auth, amount)

    assert response.status_code == 201
    assert "Idempotent-Replayed" not in response.headers
    body = response.json()
    assert body["balance_cents"] == amount
    assert body["transaction"]["type"] == "top_up"
    assert body["transaction"]["direction"] == "in"
    assert body["transaction"]["amount_cents"] == amount
    assert body["transaction"]["counterparty_name"] is None
    assert balance(client, auth) == amount


def test_top_up_amount_not_allowed_is_rejected_and_not_saved(
    client: TestClient, db: Session
) -> None:
    auth = register(client)

    response = top_up(client, auth, 12_345)

    assert response.status_code == 422
    assert error_code(response) == "top_up_amount_not_allowed"
    assert count_transactions(db) == 0


@pytest.mark.parametrize("bad_amount", [100.0, "10000", True, 0, -5])
def test_top_up_amount_must_be_a_strict_positive_integer(client: TestClient, bad_amount) -> None:
    auth = register(client)

    response = top_up(client, auth, bad_amount)

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


def test_top_up_requires_token(client: TestClient) -> None:
    response = top_up(client, {}, 10_000)

    assert response.status_code == 401


def test_top_up_without_idempotency_key_is_400(client: TestClient) -> None:
    auth = register(client)

    response = top_up(client, auth, 10_000, key=None)

    assert response.status_code == 400
    assert error_code(response) == "idempotency_key_required"


@pytest.mark.parametrize("bad_key", ["short", "x" * 129])
def test_top_up_with_badly_sized_key_is_400(client: TestClient, bad_key: str) -> None:
    auth = register(client)

    response = top_up(client, auth, 10_000, key=bad_key)

    assert response.status_code == 400
    assert error_code(response) == "idempotency_key_invalid"


def test_key_does_not_have_to_be_a_uuid(client: TestClient) -> None:
    auth = register(client)

    response = top_up(client, auth, 10_000, key="allowance-42:7")

    assert response.status_code == 201


# ---------- idempotency ----------


def test_same_key_and_body_replays_the_same_transaction(client: TestClient, db: Session) -> None:
    auth = register(client)
    first = top_up(client, auth, 50_000, key="retry-key-1")

    second = top_up(client, auth, 50_000, key="retry-key-1")

    assert second.status_code == 201
    assert second.headers["Idempotent-Replayed"] == "true"
    assert second.json()["transaction"] == first.json()["transaction"]
    assert count_transactions(db) == 1
    assert balance(client, auth) == 50_000


def test_same_key_with_another_body_is_rejected(client: TestClient, db: Session) -> None:
    auth = register(client)
    top_up(client, auth, 50_000, key="retry-key-1")

    response = top_up(client, auth, 100_000, key="retry-key-1")

    assert response.status_code == 422
    assert error_code(response) == "idempotency_key_reused"
    assert count_transactions(db) == 1


def test_failed_attempt_is_not_saved_so_the_key_can_be_retried(client: TestClient) -> None:
    auth = register(client)
    top_up(client, auth, 12_345, key="retry-key-1")  # rejected: amount not allowed

    response = top_up(client, auth, 10_000, key="retry-key-1")

    assert response.status_code == 201
    assert "Idempotent-Replayed" not in response.headers


def test_same_key_from_two_users_does_not_collide(client: TestClient, db: Session) -> None:
    ana = register(client, "ana@example.com")
    luis = register(client, "luis@example.com")

    top_up(client, ana, 10_000, key="shared-key-1")
    response = top_up(client, luis, 50_000, key="shared-key-1")

    assert response.status_code == 201
    assert "Idempotent-Replayed" not in response.headers
    assert count_transactions(db) == 2


# ---------- 24-hour limit ----------


def test_top_ups_are_capped_at_10000_pesos_in_24_hours(client: TestClient) -> None:
    auth = register(client)
    for i in range(10):
        assert top_up(client, auth, 100_000, key=f"limit-key-{i}").status_code == 201

    response = top_up(client, auth, 10_000, key="limit-key-over")

    assert response.status_code == 422
    assert error_code(response) == "top_up_limit_exceeded"
    assert response.json()["error"]["details"] == {
        "limit_cents": 1_000_000,
        "used_cents": 1_000_000,
    }
    assert balance(client, auth) == 1_000_000


def test_limit_is_per_user(client: TestClient) -> None:
    ana = register(client, "ana@example.com")
    luis = register(client, "luis@example.com")
    for i in range(10):
        top_up(client, ana, 100_000, key=f"limit-key-{i}")

    response = top_up(client, luis, 100_000, key="limit-key-0")

    assert response.status_code == 201


# ---------- concurrency (real commits from two connections) ----------


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


def test_concurrent_requests_with_the_same_key_create_one_transaction(
    client: TestClient, db: Session
) -> None:
    auth = register(client)

    def send():
        return top_up(TestClient(app), auth, 50_000, key="double-tap-1")

    first, second = run_at_the_same_time(send, send)

    assert first.status_code == second.status_code == 201
    assert first.json()["transaction"]["id"] == second.json()["transaction"]["id"]
    replayed = [r.headers.get("Idempotent-Replayed") for r in (first, second)]
    assert replayed.count("true") == 1  # one request created it, the other replayed it
    assert count_transactions(db) == 1
    assert balance(client, auth) == 50_000


def test_concurrent_top_ups_cannot_exceed_the_limit(client: TestClient, db: Session) -> None:
    auth = register(client)
    for i in range(9):
        top_up(client, auth, 100_000, key=f"limit-key-{i}")  # 900,000 used

    def send(key):
        return lambda: top_up(TestClient(app), auth, 100_000, key=key)

    results = run_at_the_same_time(send("race-key-a"), send("race-key-b"))

    assert sorted(r.status_code for r in results) == [201, 422]
    assert balance(client, auth) == 1_000_000
    db.expire_all()
    assert db.scalar(select(func.sum(Entry.amount_cents))) == 0
