from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_idempotency_key
from app.db.session import get_db
from app.models import User
from app.schemas.wallet import MoneyOperationResponse, TopUpRequest, TransactionOut, WalletOut
from app.services import top_ups
from app.services.ledger import get_balance
from app.services.wallet import get_wallet

router = APIRouter(prefix="/wallet", tags=["wallet"])


@router.get("", response_model=WalletOut)
def read_wallet(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> WalletOut:
    wallet = get_wallet(db, current_user.id)
    return WalletOut(
        account_id=wallet.id, balance_cents=get_balance(db, wallet.id), currency=wallet.currency
    )


@router.post("/top-ups", response_model=MoneyOperationResponse, status_code=status.HTTP_201_CREATED)
def create_top_up(
    body: TopUpRequest,
    response: Response,
    current_user: User = Depends(get_current_user),
    idempotency_key: str = Depends(get_idempotency_key),
    db: Session = Depends(get_db),
) -> MoneyOperationResponse:
    result = top_ups.top_up(
        db,
        user_id=current_user.id,
        amount_cents=body.amount_cents,
        idempotency_key=idempotency_key,
    )
    if result.replayed:
        response.headers["Idempotent-Replayed"] = "true"

    transaction = result.transaction
    return MoneyOperationResponse(
        transaction=TransactionOut(
            id=transaction.id,
            type=transaction.type,
            direction="in",  # a top-up always adds money to the wallet
            amount_cents=transaction.amount_cents,
            counterparty_name=None,
            description=None,
            created_at=transaction.created_at,
        ),
        # Current balance, also on a replay (documented in the design doc, section 2).
        balance_cents=get_balance(db, get_wallet(db, current_user.id).id),
    )
