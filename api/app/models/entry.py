import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Entry(Base):
    """One signed movement: positive money enters the account, negative leaves it."""

    __tablename__ = "entries"
    __table_args__ = (
        CheckConstraint("amount_cents <> 0", name="amount_nonzero"),
        UniqueConstraint("transaction_id", "account_id", name="uq_entries_transaction_account"),
        # Used by the balance SUM and by history pagination (newest first).
        Index("ix_entries_account_id_id_desc", "account_id", text("id DESC")),
    )

    # Increasing integer id gives a stable order for cursor pagination.
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    transaction_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("transactions.id"))
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id"))
    amount_cents: Mapped[int] = mapped_column(BigInteger)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
