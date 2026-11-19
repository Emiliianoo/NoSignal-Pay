"""Every error, from any source, leaves the API with the same shape."""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.errors import ApiError, register_error_handlers
from app.main import app


def assert_error_shape(response, status_code: int, code: str) -> None:
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message", "details"}
    assert body["error"]["code"] == code


def test_unknown_route_uses_error_format() -> None:
    response = TestClient(app).get("/api/v1/does-not-exist")

    assert_error_shape(response, 404, "not_found")


def test_api_error_and_unexpected_error_use_error_format() -> None:
    probe = FastAPI()
    register_error_handlers(probe)

    @probe.get("/known")
    def known() -> None:
        raise ApiError(422, "insufficient_funds", "Not enough money.", {"balance_cents": 5})

    @probe.get("/boom")
    def boom() -> None:
        raise RuntimeError("database password is hunter2")

    client = TestClient(probe, raise_server_exceptions=False)

    known_response = client.get("/known")
    assert_error_shape(known_response, 422, "insufficient_funds")
    assert known_response.json()["error"]["details"] == {"balance_cents": 5}

    boom_response = client.get("/boom")
    assert_error_shape(boom_response, 500, "internal_error")
    assert "hunter2" not in boom_response.text
