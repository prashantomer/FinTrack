from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.account import Account, AccountType
from app.models.term_account import TermAccount, TermAccountType
from app.schemas.account import BalanceAdjust
from app.schemas.term_account import PPFDeposit, TermAccountClose, TermAccountCreate, TermAccountUpdate


def list_term_accounts(db: Session, user_id: int) -> list[TermAccount]:
    return db.query(TermAccount).filter(TermAccount.user_id == user_id).order_by(TermAccount.created_at.desc()).all()


def get_term_account(db: Session, term_account_id: int, user_id: int) -> TermAccount:
    ta = db.query(TermAccount).filter(
        TermAccount.id == term_account_id, TermAccount.user_id == user_id
    ).first()
    if not ta:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Term account not found")
    return ta


def create_term_account(db: Session, data: TermAccountCreate, user_id: int) -> TermAccount:
    allowed_types = (
        [AccountType.savings]
        if data.type == TermAccountType.ppf
        else [AccountType.savings, AccountType.current]
    )
    parent = db.query(Account).filter(
        Account.id == data.parent_account_id,
        Account.user_id == user_id,
        Account.account_type.in_(allowed_types),
    ).first()
    if not parent:
        detail = (
            "PPF account requires a savings account as parent"
            if data.type == TermAccountType.ppf
            else "parent_account_id must be a savings/current account you own"
        )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)

    if data.type == TermAccountType.ppf:
        existing_ppf = db.query(TermAccount).filter(
            TermAccount.user_id == user_id,
            TermAccount.parent_account_id == data.parent_account_id,
            TermAccount.type == TermAccountType.ppf,
        ).first()
        if existing_ppf:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"A PPF account already exists for this bank account (id={existing_ppf.id})",
            )

    initial_balance = float(data.amount) if data.type == TermAccountType.fd else (data.balance or 0)
    ta = TermAccount(
        user_id=user_id,
        parent_account_id=data.parent_account_id,
        type=data.type,
        account_number=data.account_number,
        amount=data.amount,
        open_date=data.open_date,
        tenure_days=data.tenure_days,
        interest_rate=data.interest_rate,
        maturity_amount=data.maturity_amount,
        balance=initial_balance,
    )
    db.add(ta)
    db.flush()

    if ta.type == TermAccountType.fd:
        from app.commands.fd import fd_open
        try:
            fd_open(db, ta, parent, float(ta.amount), ta.open_date, user_id)
        except ValueError as e:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    db.commit()
    db.refresh(ta)
    return ta


def update_term_account(db: Session, term_account_id: int, data: TermAccountUpdate, user_id: int) -> TermAccount:
    ta = get_term_account(db, term_account_id, user_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(ta, field, value)
    if not ta.balance or float(ta.balance) == 0:
        ta.balance = float(ta.amount)
    db.commit()
    db.refresh(ta)
    return ta


def deposit_ppf_account(db: Session, term_account_id: int, data: PPFDeposit, user_id: int) -> TermAccount:
    from app.commands.ppf import ppf_deposit
    ta = get_term_account(db, term_account_id, user_id)
    if ta.type != TermAccountType.ppf:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Deposit is only available for PPF accounts")
    if not ta.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Term account is closed")
    parent = db.get(Account, ta.parent_account_id)
    if not parent:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Parent account not found")
    try:
        ppf_deposit(db, ta, parent, float(data.amount), data.date, user_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    db.commit()
    db.refresh(ta)
    return ta


def close_term_account(db: Session, term_account_id: int, data: TermAccountClose, user_id: int) -> TermAccount:
    from app.commands.fd import fd_close
    from app.commands.ppf import ppf_close

    ta = get_term_account(db, term_account_id, user_id)
    if not ta.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Term account already closed")

    parent = db.get(Account, ta.parent_account_id)
    if not parent:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Parent account not found")

    close_cmd = fd_close if ta.type == TermAccountType.fd else ppf_close
    close_cmd(db, ta, parent, float(data.closed_amount), data.closed_date, user_id)

    db.commit()
    db.refresh(ta)
    return ta


def adjust_term_account_balance(db: Session, term_account_id: int, data: BalanceAdjust, user_id: int) -> TermAccount:
    ta = get_term_account(db, term_account_id, user_id)
    ta.balance = data.balance
    db.commit()
    db.refresh(ta)
    return ta
