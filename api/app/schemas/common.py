from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

# Strict integer cents: rejects 100.0, "100" and true. Strict is set on this field only:
# a fully strict model would reject UUIDs sent as JSON strings.
AmountCents = Annotated[int, Field(strict=True, gt=0, le=1_000_000)]


class RequestModel(BaseModel):
    """Base for request bodies: unknown fields (e.g. an amount on a payment) are a 422."""

    model_config = ConfigDict(extra="forbid")


class ResponseModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)
