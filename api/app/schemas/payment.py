from uuid import UUID

from app.schemas.common import RequestModel


class PaymentCreate(RequestModel):
    """Only the charge to pay. Never an amount: the server takes it from the payment request."""

    payment_request_id: UUID
