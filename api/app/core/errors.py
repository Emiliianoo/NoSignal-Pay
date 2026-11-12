"""One error format for the whole API: {"error": {"code", "message", "details"}}.

The app decides what to do by `code`, never by `message`.
"""

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class ApiError(Exception):
    """Raise this from services and dependencies to answer with a known error code."""

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def error_response(
    status_code: int, code: str, message: str, details: dict[str, Any] | None = None
) -> JSONResponse:
    body = {"error": {"code": code, "message": message, "details": details}}
    return JSONResponse(status_code=status_code, content=body)


async def _handle_api_error(request: Request, exc: ApiError) -> JSONResponse:
    return error_response(exc.status_code, exc.code, exc.message, exc.details)


async def _handle_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    # Replaces FastAPI's default 422 body, which has a different shape.
    errors = [
        {
            # loc looks like ("body", "amount_cents"); drop the "body"/"query" prefix.
            "field": ".".join(str(part) for part in error["loc"][1:]) or str(error["loc"][0]),
            "message": error["msg"],
            "type": error["type"],
        }
        for error in exc.errors()
    ]
    return error_response(422, "validation_error", "Invalid request.", {"errors": errors})


_HTTP_CODES = {404: "not_found", 405: "method_not_allowed"}


async def _handle_http_exception(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    # Errors raised by FastAPI itself, such as an unknown route.
    code = _HTTP_CODES.get(exc.status_code, "http_error")
    return error_response(exc.status_code, code, str(exc.detail))


async def _handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
    # Log the real cause for us; never send internal details to the client.
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return error_response(500, "internal_error", "Something went wrong.")


def register_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, _handle_api_error)
    app.add_exception_handler(RequestValidationError, _handle_validation_error)
    app.add_exception_handler(StarletteHTTPException, _handle_http_exception)
    app.add_exception_handler(Exception, _handle_unexpected_error)
