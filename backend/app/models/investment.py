import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InvestmentType(str, enum.Enum):
    stock = "stock"
    mutual_fund = "mutual_fund"
    fixed_deposit = "fixed_deposit"
    gold = "gold"
    crypto = "crypto"
    ppf = "ppf"
    nps = "nps"
    real_estate = "real_estate"


class Investment(Base):
    __tablename__ = "investments"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    platform_account_id: Mapped[int | None] = mapped_column(
        ForeignKey("platform_accounts.id", ondelete="SET NULL"), nullable=True, index=True
    )
    instrument_id: Mapped[int | None] = mapped_column(
        ForeignKey("instruments.id", ondelete="SET NULL"), nullable=True, index=True
    )
    type: Mapped[InvestmentType] = mapped_column(
        Enum(InvestmentType, name="investment_type"), index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    amount_invested: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    current_value: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    purchase_date: Mapped[date] = mapped_column(Date, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # Stock / ETF  (ticker, exchange → on Instrument)
    quantity: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    avg_buy_price: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)

    # Mutual Fund  (fund_house → on Instrument)
    folio_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    units: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    nav_at_purchase: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)

    # Fixed Deposit
    bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    fd_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    interest_rate: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)
    tenure_months: Mapped[int | None] = mapped_column(Integer, nullable=True)
    maturity_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    maturity_amount: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    compounding: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Gold
    gold_form: Mapped[str | None] = mapped_column(String(30), nullable=True)
    weight_grams: Mapped[float | None] = mapped_column(Numeric(10, 3), nullable=True)
    purity: Mapped[str | None] = mapped_column(String(10), nullable=True)

    # Traceability — links back to Transaction.public_id (soft reference, no FK constraint)
    transaction_public_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True, index=True
    )

    platform_account = relationship("PlatformAccount", back_populates="investments")
    instrument = relationship("Instrument", foreign_keys=[instrument_id])
