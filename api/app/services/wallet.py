from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account
from app.models.account import SYSTEM_FUNDING, USER_WALLET


def get_wallet(db: Session, user_id: UUID, *, lock: bool = False) -> Account:
    """The user's wallet. With lock=True it is read with SELECT ... FOR UPDATE.

    FOR UPDATE makes other transactions that want to lock the same row wait until this one
    commits or rolls back, so two money operations on one wallet run one after the other.
    """
    query = select(Account).where(Account.user_id == user_id, Account.type == USER_WALLET)
    if lock:
        query = query.with_for_update()
    return db.scalars(query).one()


def get_system_account(db: Session) -> Account:
    return db.scalars(select(Account).where(Account.type == SYSTEM_FUNDING)).one()
