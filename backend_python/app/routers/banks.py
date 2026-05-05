from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.account import AccountClose, AccountCreate, AccountRead, AccountUpdate, BalanceAdjust
from app.schemas.bank import BankRead
from app.services.bank_service import (
    adjust_account_balance,
    close_account,
    create_account,
    get_account,
    list_accounts,
    list_banks,
    update_account,
)

banks_router = APIRouter(prefix="/api/v1/banks", tags=["banks"])
accounts_router = APIRouter(prefix="/api/v1/accounts", tags=["accounts"])


@banks_router.get("", response_model=list[BankRead])
def get_banks(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return list_banks(db)


@accounts_router.get("", response_model=list[AccountRead])
def get_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_accounts(db, current_user.id)


@accounts_router.post("", response_model=AccountRead, status_code=status.HTTP_201_CREATED)
def create_acct(
    body: AccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_account(db, body, current_user.id)


@accounts_router.get("/{account_id}", response_model=AccountRead)
def get_acct(
    account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_account(db, account_id, current_user.id)


@accounts_router.put("/{account_id}", response_model=AccountRead)
def update_acct(
    account_id: int,
    body: AccountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_account(db, account_id, body, current_user.id)


@accounts_router.post("/{account_id}/close", response_model=AccountRead)
def close_acct(
    account_id: int,
    body: AccountClose,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return close_account(db, account_id, body, current_user.id)


@accounts_router.post("/{account_id}/adjust", response_model=AccountRead)
def adjust_acct(
    account_id: int,
    body: BalanceAdjust,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return adjust_account_balance(db, account_id, body, current_user.id)
