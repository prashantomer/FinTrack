from datetime import date

from fastapi import HTTPException, status
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.term_account import TermAccount, TermAccountType
from app.models.transaction import LinkedAccountType, Transaction, TransactionType
from app.schemas.transaction import TransactionCreate
from app.utils.cursor import decode_cursor, encode_cursor
from app.utils.pagination import PaginationParams


def _apply_balance_delta(db: Session, txn: Transaction, factor: float = 1.0) -> None:
    """Credit increases balance; debit decreases. factor=-1 reverses the effect."""
    if txn.linked_account_type is None or txn.linked_account_id is None:
        return
    delta = float(txn.amount) * factor
    if txn.type == TransactionType.debit:
        delta = -delta

    if txn.linked_account_type == LinkedAccountType.account:
        acct = db.get(Account, txn.linked_account_id)
        if acct:
            acct.balance = float(acct.balance) + delta
    elif txn.linked_account_type == LinkedAccountType.term_account:
        ta = db.get(TermAccount, txn.linked_account_id)
        # FD balance is not transaction-driven; only PPF balance is tracked
        if ta and ta.type != TermAccountType.fd:
            ta.balance = float(ta.balance) + delta


def list_transactions(
    db: Session,
    user_id: int,
    pagination: PaginationParams,
    type: TransactionType | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    search: str | None = None,
    cursor: str | None = None,
) -> tuple[list[Transaction], int, str | None]:
    q = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.is_active.is_(True),
    )
    if type:
        q = q.filter(Transaction.type == type)
    if date_from:
        q = q.filter(Transaction.date >= date_from)
    if date_to:
        q = q.filter(Transaction.date <= date_to)
    if search:
        term = f"%{search}%"
        q = q.filter(or_(
            Transaction.description.ilike(term),
            Transaction.bank_ref.ilike(term),
            func.array_to_string(Transaction.tags, ",").ilike(term),
        ))

    total = q.count()
    q = q.order_by(*Transaction.DEFAULT_ORDER)

    if cursor:
        cursor_date, cursor_id = decode_cursor(cursor)
        q = q.filter(or_(
            Transaction.date < cursor_date,
            and_(Transaction.date == cursor_date, Transaction.id < cursor_id),
        ))
        items = q.limit(pagination.page_size).all()
    else:
        items = q.offset(pagination.offset).limit(pagination.page_size).all()

    next_cursor = None
    if len(items) == pagination.page_size:
        last = items[-1]
        next_cursor = encode_cursor(last.date, last.id)

    return items, total, next_cursor


def get_transaction(db: Session, transaction_id: int, user_id: int) -> Transaction:
    t = db.query(Transaction).filter(
        Transaction.id == transaction_id, Transaction.user_id == user_id
    ).first()
    if not t:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")
    return t


def create_transaction(db: Session, data: TransactionCreate, user_id: int) -> Transaction:
    payload = data.model_dump()
    t = Transaction(**payload, user_id=user_id)
    db.add(t)
    db.flush()
    _apply_balance_delta(db, t)
    db.commit()
    db.refresh(t)
    return t


def correct_transaction(
    db: Session,
    transaction_id: int,
    amount: float,
    txn_type: TransactionType,
    user_id: int,
) -> Transaction:
    """CLI-only: correct amount/type and recalculate balance."""
    t = get_transaction(db, transaction_id, user_id)
    _apply_balance_delta(db, t, factor=-1.0)  # reverse old delta
    t.amount = amount
    t.type = txn_type
    db.flush()
    _apply_balance_delta(db, t, factor=1.0)   # apply new delta
    db.commit()
    db.refresh(t)
    return t


def deactivate_transaction(db: Session, transaction_id: int, user_id: int) -> Transaction:
    """CLI-only: mark inactive and reverse balance impact."""
    t = get_transaction(db, transaction_id, user_id)
    if not t.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Transaction already inactive")
    _apply_balance_delta(db, t, factor=-1.0)
    t.is_active = False
    db.commit()
    db.refresh(t)
    return t
