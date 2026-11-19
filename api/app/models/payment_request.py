import uuid
from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class PaymentRequest(Base):
    """A QR charge. Its status is derived (paid / expired / pending), never stored."""

    __tablename__ = "payment_requests"
    __table_args__ = (
        CheckConstraint("amount_cents BETWEEN 1 AND 1000000", name="amount_range"),
        CheckConstraint("char_length(description) <= 140", name="description_length"),
        CheckConstraint("expires_at > created_at", name="expires_after_created"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    payee_account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id"))
    amount_cents: Mapped[int] = mapped_column(BigInteger)
    description: Mapped[str | None] = mapped_column(Text)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
