from datetime import datetime
from typing import Literal
from uuid import UUID

from app.schemas.common import AmountCents, RequestModel, ResponseModel


class WalletOut(ResponseModel):
    account_id: UUID
    balance_cents: int
    currency: Literal["MXN"]


class TopUpRequest(RequestModel):
    amount_cents: AmountCents  # the allowed values are checked in the service


class TransactionOut(ResponseModel):
    id: UUID
    type: Literal["top_up", "payment"]
    direction: Literal["in", "out"]
    amount_cents: int  # always positive; direction carries the sign
    counterparty_name: str | None  # None for top-ups
    description: str | None
    created_at: datetime


class MoneyOperationResponse(ResponseModel):
    transaction: TransactionOut
    balance_cents: int
