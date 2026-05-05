from fastapi import HTTPException, status
from sqlalchemy.orm import Session

import app.models  # noqa: F401 — ensures all mappers are registered
from app.models.account import Account
from app.models.bank import Bank
from app.schemas.account import AccountClose, AccountCreate, AccountUpdate, BalanceAdjust


def list_banks(db: Session) -> list[Bank]:
    return db.query(Bank).order_by(Bank.name).all()


def get_bank(db: Session, bank_id: int) -> Bank:
    bank = db.get(Bank, bank_id)
    if not bank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank not found")
    return bank


def create_bank(db: Session, name: str, short_name: str, is_system: bool = False) -> Bank:
    bank = Bank(name=name, short_name=short_name, is_system=is_system)
    db.add(bank)
    db.commit()
    db.refresh(bank)
    return bank


def list_accounts(db: Session, user_id: int) -> list[Account]:
    return (
        db.query(Account)
        .filter(Account.user_id == user_id)
        .order_by(Account.nickname)
        .all()
    )


def get_account(db: Session, account_id: int, user_id: int) -> Account:
    acct = db.query(Account).filter(
        Account.id == account_id, Account.user_id == user_id
    ).first()
    if not acct:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")
    return acct


def create_account(db: Session, data: AccountCreate, user_id: int) -> Account:
    get_bank(db, data.bank_id)
    acct = Account(**data.model_dump(), user_id=user_id)
    db.add(acct)
    db.commit()
    db.refresh(acct)
    return acct


def update_account(db: Session, account_id: int, data: AccountUpdate, user_id: int) -> Account:
    acct = get_account(db, account_id, user_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(acct, field, value)
    db.commit()
    db.refresh(acct)
    return acct


def close_account(db: Session, account_id: int, data: AccountClose, user_id: int) -> Account:
    acct = get_account(db, account_id, user_id)
    if acct.closed_date is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Account already closed")
    acct.closed_date = data.closed_date
    acct.closed_amount = data.closed_amount
    db.commit()
    db.refresh(acct)
    return acct


def adjust_account_balance(db: Session, account_id: int, data: BalanceAdjust, user_id: int) -> Account:
    acct = get_account(db, account_id, user_id)
    acct.balance = data.balance
    db.commit()
    db.refresh(acct)
    return acct


def delete_account(db: Session, account_id: int, user_id: int) -> None:
    acct = get_account(db, account_id, user_id)
    db.delete(acct)
    db.commit()
