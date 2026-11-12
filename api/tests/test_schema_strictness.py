"""Confirms the design doc's open question (section 3): through FastAPI, strict amounts reject
non-integers while UUID fields still accept JSON strings."""

from uuid import UUID, uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.schemas.common import AmountCents, RequestModel


class AmountBody(RequestModel):
    amount_cents: AmountCents


class PaymentLikeBody(RequestModel):
    payment_request_id: UUID


probe = FastAPI()


@probe.post("/amount")
def amount_endpoint(body: AmountBody) -> dict[str, int]:
    return {"amount_cents": body.amount_cents}


@probe.post("/payment")
def payment_endpoint(body: PaymentLikeBody) -> dict[str, str]:
    return {"payment_request_id": str(body.payment_request_id)}


client = TestClient(probe)


@pytest.mark.parametrize("bad_amount", [100.0, "100", True, 0, -5, 1_000_001, None])
def test_amount_rejects_non_strict_or_out_of_range(bad_amount: object) -> None:
    response = client.post("/amount", json={"amount_cents": bad_amount})

    assert response.status_code == 422


@pytest.mark.parametrize("good_amount", [1, 10_000, 1_000_000])
def test_amount_accepts_integers_in_range(good_amount: int) -> None:
    response = client.post("/amount", json={"amount_cents": good_amount})

    assert response.status_code == 200
    assert response.json() == {"amount_cents": good_amount}


def test_uuid_field_accepts_json_string() -> None:
    payment_request_id = str(uuid4())

    response = client.post("/payment", json={"payment_request_id": payment_request_id})

    assert response.status_code == 200
    assert response.json() == {"payment_request_id": payment_request_id}


def test_extra_fields_are_rejected() -> None:
    response = client.post(
        "/payment", json={"payment_request_id": str(uuid4()), "amount_cents": 100}
    )

    assert response.status_code == 422
