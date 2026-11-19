import uuid
from datetime import datetime

from sqlalchemy import (
    CHAR,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

USER_WALLET = "user_wallet"
SYSTEM_FUNDING = "system_funding"


class Account(Base):
    __tablename__ = "accounts"
    __table_args__ = (
        CheckConstraint("type IN ('user_wallet', 'system_funding')", name="type_valid"),
        CheckConstraint("currency = 'MXN'", name="currency_mxn"),
        # Only the system account has no owner.
        CheckConstraint("(type = 'system_funding') = (user_id IS NULL)", name="owner_matches_type"),
        # One wallet per user.
        UniqueConstraint("user_id", "type", name="uq_accounts_user_type"),
        # Exactly one system account.
        Index(
            "uq_accounts_single_system",
            "type",
            unique=True,
            postgresql_where=text("user_id IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    type: Mapped[str] = mapped_column(Text)
    currency: Mapped[str] = mapped_column(CHAR(3), server_default="MXN")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
