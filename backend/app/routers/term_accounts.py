from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.account import BalanceAdjust
from app.schemas.audit import AuditLogRead
from app.schemas.term_account import PPFDeposit, TermAccountClose, TermAccountCreate, TermAccountRead, TermAccountUpdate
from app.services.audit_service import list_term_account_audit_logs
from app.services.term_account_service import (
    adjust_term_account_balance,
    close_term_account,
    create_term_account,
    deposit_ppf_account,
    get_term_account,
    list_term_accounts,
    update_term_account,
)

router = APIRouter(prefix="/api/v1/term-accounts", tags=["term-accounts"])


@router.get("/", response_model=list[TermAccountRead])
def get_term_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_term_accounts(db, current_user.id)


@router.post("/", response_model=TermAccountRead, status_code=status.HTTP_201_CREATED)
def create_term_acct(
    body: TermAccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_term_account(db, body, current_user.id)


@router.get("/{term_account_id}", response_model=TermAccountRead)
def get_term_acct(
    term_account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_term_account(db, term_account_id, current_user.id)


@router.put("/{term_account_id}", response_model=TermAccountRead)
def update_term_acct(
    term_account_id: int,
    body: TermAccountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_term_account(db, term_account_id, body, current_user.id)


@router.get("/{term_account_id}/audit-logs", response_model=list[AuditLogRead])
def get_term_acct_audit_logs(
    term_account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_term_account(db, term_account_id, current_user.id)
    return list_term_account_audit_logs(db, term_account_id)


@router.post("/{term_account_id}/adjust", response_model=TermAccountRead)
def adjust_term_acct(
    term_account_id: int,
    body: BalanceAdjust,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return adjust_term_account_balance(db, term_account_id, body, current_user.id)


@router.post("/{term_account_id}/deposit", response_model=TermAccountRead)
def deposit_ppf_acct(
    term_account_id: int,
    body: PPFDeposit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return deposit_ppf_account(db, term_account_id, body, current_user.id)


@router.post("/{term_account_id}/close", response_model=TermAccountRead)
def close_term_acct(
    term_account_id: int,
    body: TermAccountClose,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return close_term_account(db, term_account_id, body, current_user.id)
