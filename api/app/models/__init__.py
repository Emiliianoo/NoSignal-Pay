# Importing every model here registers all tables on Base.metadata (Alembic and tests rely on it).
from app.models.account import Account
from app.models.entry import Entry
from app.models.payment_request import PaymentRequest
from app.models.transaction import Transaction
from app.models.user import User

__all__ = ["Account", "Entry", "PaymentRequest", "Transaction", "User"]
