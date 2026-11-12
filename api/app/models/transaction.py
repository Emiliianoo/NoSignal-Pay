import uuid
from datetime import datetime

from sqlalchemy import (
    CHAR,
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

TOP_UP = "top_up"
PAYMENT = "payment"


class Transaction(Base):
    """Immutable ledger header. Only services/ledger.py inserts here; never UPDATE or DELETE."""

    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("type IN ('top_up', 'payment')", name="type_valid"),
        CheckConstraint("amount_cents > 0", name="amount_positive"),
        CheckConstraint(
            "char_length(idempotency_key) BETWEEN 8 AND 128", name="idempotency_key_length"
        ),
        CheckConstraint(
            "(type = 'payment') = (payment_request_id IS NOT NULL)", name="payment_has_request"
        ),
        # The payment service tells these two apart by name, so they are named by hand.
        UniqueConstraint(
            "initiator_user_id", "idempotency_key", name="uq_transactions_idempotency"
        ),
        UniqueConstraint("payment_request_id", name="uq_transactions_payment_request"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    type: Mapped[str] = mapped_column(Text)
    amount_cents: Mapped[int] = mapped_column(BigInteger)
    initiator_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    idempotency_key: Mapped[str] = mapped_column(Text)
    request_hash: Mapped[str] = mapped_column(CHAR(64))
    payment_request_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("payment_requests.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
