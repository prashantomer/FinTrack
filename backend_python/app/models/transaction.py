import enum
from datetime import date, datetime

from app.config import TZ

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Index, Integer, Numeric, String, Text, desc, event, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TransactionType(str, enum.Enum):
    credit = "credit"
    debit = "debit"


class LinkedAccountType(str, enum.Enum):
    account = "account"
    term_account = "term_account"


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        Index("ix_transactions_date_id", "date", "id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    linked_account_type: Mapped[LinkedAccountType | None] = mapped_column(
        Enum(LinkedAccountType, name="linked_account_type", create_type=False),
        nullable=True,
        index=True,
    )
    linked_account_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    instrument_id: Mapped[int | None] = mapped_column(
        ForeignKey("instruments.id", ondelete="SET NULL"), nullable=True, index=True
    )
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    type: Mapped[TransactionType] = mapped_column(
        Enum(TransactionType, name="transaction_type", create_type=False), nullable=False
    )
    tags: Mapped[list[str] | None] = mapped_column(ARRAY(Text), nullable=True)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    bank_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    public_id: Mapped[str | None] = mapped_column(String(100), nullable=True, unique=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    instrument = relationship("Instrument", foreign_keys=[instrument_id])

    account = relationship(
        "Account",
        primaryjoin="and_(foreign(Transaction.linked_account_id)==Account.id, "
        "Transaction.linked_account_type=='account')",
        viewonly=True,
    )
    term_account = relationship(
        "TermAccount",
        primaryjoin="and_(foreign(Transaction.linked_account_id)==TermAccount.id, "
        "Transaction.linked_account_type=='term_account')",
        viewonly=True,
    )

    user = relationship("User", back_populates="transactions")

    @property
    def linked_account(self) -> "Account | TermAccount | None":
        if self.linked_account_type == LinkedAccountType.account:
            return self.account
        elif self.linked_account_type == LinkedAccountType.term_account:
            return self.term_account
        return None


Transaction.DEFAULT_ORDER = [desc(Transaction.date), desc(Transaction.id)]


@event.listens_for(Transaction, "before_insert")
def _set_defaults(mapper, connection, target: Transaction) -> None:
    now = datetime.now(TZ)
    if target.public_id is None:
        target.public_id = f"AccTx-{int(now.timestamp() * 1_000_000)}"
    if not target.bank_ref:
        target.bank_ref = target.public_id
