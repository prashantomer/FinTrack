import enum
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models._audit_registry import auditable


class AccountType(str, enum.Enum):
    savings = "savings"
    current = "current"
    salary = "salary"
    nre = "nre"
    nro = "nro"


@auditable("balance")
class Account(Base):
    """A user's account at a specific bank — the many-to-many junction."""

    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    bank_id: Mapped[int] = mapped_column(
        ForeignKey("banks.id", ondelete="RESTRICT"), nullable=False
    )
    nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    account_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    account_type: Mapped[AccountType] = mapped_column(
        Enum(AccountType, name="account_type"), nullable=False, default=AccountType.savings
    )
    balance: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False, default=0, server_default="0")
    open_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    closed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    closed_amount: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    def debit(self, amount: float) -> None:
        if self.closed_date:
            raise ValueError(f"Account '{self.nickname}' is closed")
        if float(self.balance) < amount:
            raise ValueError(
                f"Insufficient balance in '{self.nickname}' (available: {self.balance}, required: {amount})"
            )
        self.balance = float(self.balance) - amount

    def credit(self, amount: float) -> None:
        if self.closed_date:
            raise ValueError(f"Account '{self.nickname}' is closed")
        self.balance = float(self.balance) + amount

    bank = relationship("Bank", back_populates="accounts")
    user = relationship("User", back_populates="accounts")
    transactions = relationship(
        "Transaction",
        primaryjoin="and_(Account.id == foreign(Transaction.linked_account_id), Transaction.linked_account_type == 'account')",
        viewonly=True,
    )
    audit_logs = relationship(
        "AuditLog",
        primaryjoin="and_(Account.id == foreign(AuditLog.record_id), AuditLog.table_name == 'accounts')",
        viewonly=True,
    )
