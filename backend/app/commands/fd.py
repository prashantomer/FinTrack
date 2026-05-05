from datetime import date, datetime

from app.config import TZ
from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.term_account import TermAccount
from app.models.transaction import LinkedAccountType, Transaction, TransactionType


def _gen_public_id() -> str:
    return f"FD-Tx-{int(datetime.now(TZ).timestamp() * 1_000_000)}"


def fd_open(
    db: Session,
    ta: TermAccount,
    parent: Account,
    amount: float,
    open_date: date,
    user_id: int,
) -> None:
    """Debit parent savings account and credit FD. Runs within caller's transaction."""
    ref = _gen_public_id()
    parent.debit(amount)
    db.add(Transaction(
        user_id=user_id,
        linked_account_type=LinkedAccountType.account,
        linked_account_id=parent.id,
        type=TransactionType.debit,
        amount=amount,
        date=open_date,
        description=f"FD created: {ta.account_number or ta.id}",
        tags=["FD Withdraw"],
        public_id=ref,
    ))
    db.add(Transaction(
        user_id=user_id,
        linked_account_type=LinkedAccountType.term_account,
        linked_account_id=ta.id,
        type=TransactionType.credit,
        amount=amount,
        date=open_date,
        description="FD opened",
        tags=["FD Deposit"],
        bank_ref=ref,
    ))


def fd_close(
    db: Session,
    ta: TermAccount,
    parent: Account,
    closed_amount: float,
    closed_date: date,
    user_id: int,
) -> None:
    """Debit FD and credit proceeds to parent savings account. Runs within caller's transaction."""
    ref = _gen_public_id()
    db.add(Transaction(
        user_id=user_id,
        linked_account_type=LinkedAccountType.term_account,
        linked_account_id=ta.id,
        type=TransactionType.debit,
        amount=closed_amount,
        date=closed_date,
        description=f"FD closed: {ta.account_number or ta.id}",
        tags=["FD Maturity"],
        public_id=ref,
    ))
    db.add(Transaction(
        user_id=user_id,
        linked_account_type=LinkedAccountType.account,
        linked_account_id=parent.id,
        type=TransactionType.credit,
        amount=closed_amount,
        date=closed_date,
        description=f"FD matured: {ta.account_number or ta.id}",
        tags=["FD Maturity"],
        bank_ref=ref,
    ))
    parent.credit(closed_amount)
    ta.close(closed_date, closed_amount)
