from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_idempotency_key
from app.db.session import get_db
from app.models import User
from app.schemas.payment import PaymentCreate
from app.schemas.wallet import MoneyOperationResponse, TransactionOut
from app.services import payments
from app.services.ledger import get_balance
from app.services.wallet import get_wallet

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("", response_model=MoneyOperationResponse, status_code=status.HTTP_201_CREATED)
def create_payment(
    body: PaymentCreate,
    response: Response,
    current_user: User = Depends(get_current_user),
    idempotency_key: str = Depends(get_idempotency_key),
    db: Session = Depends(get_db),
) -> MoneyOperationResponse:
    result = payments.pay(
        db,
        payer_id=current_user.id,
        payment_request_id=body.payment_request_id,
        idempotency_key=idempotency_key,
    )
    if result.replayed:
        response.headers["Idempotent-Replayed"] = "true"

    transaction = result.transaction
    payee_name, description = payments.describe(db, transaction)
    return MoneyOperationResponse(
        transaction=TransactionOut(
            id=transaction.id,
            type=transaction.type,
            direction="out",  # the payer is the one asking, so money goes out
            amount_cents=transaction.amount_cents,
            counterparty_name=payee_name,
            description=description,
            created_at=transaction.created_at,
        ),
        # Current balance, also on a replay.
        balance_cents=get_balance(db, get_wallet(db, current_user.id).id),
    )
