import enum
from datetime import date, datetime, timedelta

from app.config import TZ

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, event, func
from sqlalchemy.ext.associationproxy import association_proxy
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models._audit_registry import auditable


class TermAccountType(str, enum.Enum):
    fd = "fd"
    ppf = "ppf"


@auditable("balance")
class TermAccount(Base):
    __tablename__ = "term_accounts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    parent_account_id: Mapped[int] = mapped_column(
        ForeignKey("accounts.id", ondelete="RESTRICT"), nullable=False
    )
    type: Mapped[TermAccountType] = mapped_column(
        Enum(TermAccountType, name="term_account_type", create_type=False), nullable=False
    )
    account_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    amount: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    open_date: Mapped[date] = mapped_column(Date, nullable=False)
    tenure_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    interest_rate: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    maturity_date: Mapped[date] = mapped_column(Date, nullable=False)
    maturity_amount: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    balance: Mapped[float] = mapped_column(
        Numeric(14, 2), nullable=False, default=0, server_default="0"
    )
    closed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    closed_amount: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    parent_account = relationship("Account", foreign_keys=[parent_account_id])
    user = relationship("User")
    bank = association_proxy("parent_account", "bank")
    transactions = relationship(
        "Transaction",
        primaryjoin="and_(TermAccount.id == foreign(Transaction.linked_account_id), Transaction.linked_account_type == 'term_account')",
        viewonly=True,
    )
    audit_logs = relationship(
        "AuditLog",
        primaryjoin="and_(TermAccount.id == foreign(AuditLog.record_id), AuditLog.table_name == 'term_accounts')",
        viewonly=True,
    )

    def deposit(self, amount: float) -> None:
        if not self.is_active:
            raise ValueError(f"Term account '{self.account_number or self.id}' is closed")
        self.balance = float(self.balance) + amount

    def close(self, closed_date: date, closed_amount: float) -> None:
        if not self.is_active:
            raise ValueError(f"Term account '{self.account_number or self.id}' is already closed")
        self.closed_date = closed_date
        self.closed_amount = closed_amount
        self.balance = 0
        self.is_active = False

    def apply_defaults(self) -> None:
        if not self.account_number:
            if self.type == TermAccountType.fd:
                self.account_number = datetime.now(TZ).strftime("FD#%Y%m%d%H%M")
            elif self.type == TermAccountType.ppf:
                self.account_number = datetime.now(TZ).strftime("PPF#%Y%m%d%H%M")

        if self.maturity_date is None:
            if self.type == TermAccountType.fd and self.tenure_days:
                self.maturity_date = self.open_date + timedelta(days=self.tenure_days)
            elif self.type == TermAccountType.ppf and self.open_date:
                self.maturity_date = self.open_date.replace(year=self.open_date.year + 15)

        if self.type == TermAccountType.fd:
            # Compound interest (quarterly) — only when not provided by caller
            if not self.maturity_amount and self.amount and self.interest_rate and self.tenure_days:
                years = float(self.tenure_days) / 365
                self.maturity_amount = round(
                    float(self.amount) * (1 + float(self.interest_rate) / 400) ** (4 * years), 2
                )


@event.listens_for(TermAccount, "before_insert")
def _set_term_account_defaults(mapper, connection, target: TermAccount) -> None:
    target.apply_defaults()


