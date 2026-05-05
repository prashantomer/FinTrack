from datetime import date

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.transaction import TransactionType
from app.models.user import User
from app.schemas.transaction import TransactionCreate, TransactionListResponse, TransactionRead
from app.services.transaction_service import create_transaction, get_transaction, list_transactions
from app.utils.pagination import PaginationParams

router = APIRouter(prefix="/api/v1/transactions", tags=["transactions"])


@router.get("", response_model=TransactionListResponse)
def list_txns(
    type: TransactionType | None = Query(None),
    date_from: date | None = Query(None),
    date_to: date | None = Query(None),
    search: str | None = Query(None),
    cursor: str | None = Query(None, description="Opaque cursor for keyset pagination"),
    pagination: PaginationParams = Depends(),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items, total, next_cursor = list_transactions(
        db, current_user.id, pagination, type, date_from, date_to, search, cursor
    )
    return TransactionListResponse(
        items=items, total=total, page=pagination.page, page_size=pagination.page_size,
        next_cursor=next_cursor,
    )


@router.post("", response_model=TransactionRead, status_code=status.HTTP_201_CREATED)
def create_txn(
    body: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_transaction(db, body, current_user.id)


@router.get("/{transaction_id}", response_model=TransactionRead)
def get_txn(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_transaction(db, transaction_id, current_user.id)
