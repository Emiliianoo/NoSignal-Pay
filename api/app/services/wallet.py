from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account
from app.models.account import SYSTEM_FUNDING, USER_WALLET


def get_wallet(db: Session, user_id: UUID, *, lock: bool = False) -> Account:
    """The user's wallet. With lock=True it is read with SELECT ... FOR NO KEY UPDATE.

    The lock makes other transactions that want to lock the same row wait until this one
    commits or rolls back, so two money operations on one wallet run one after the other.

    Why NO KEY UPDATE and not FOR UPDATE: inserting an entry for an account takes a light
    KEY SHARE lock on that account (the foreign key check). FOR UPDATE conflicts with it, so
    "Ana pays Luis" and "Luis pays Ana" at the same moment would wait on each other forever
    (deadlock). NO KEY UPDATE still serializes balance checks but lets those inserts through.
    """
    query = select(Account).where(Account.user_id == user_id, Account.type == USER_WALLET)
    if lock:
        query = query.with_for_update(key_share=True)  # renders FOR NO KEY UPDATE
    return db.scalars(query).one()


def get_system_account(db: Session) -> Account:
    return db.scalars(select(Account).where(Account.type == SYSTEM_FUNDING)).one()
