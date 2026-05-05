from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.investment import InvestmentType


class UserInstrument(Base):
    """A user's tracked instrument — bridges User ↔ Instrument and is referenced
    by Follio and Investment rows."""

    __tablename__ = "user_instruments"
    __table_args__ = (
        UniqueConstraint("user_id", "instrument_id", name="uq_user_instruments_user_instrument"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    instrument_id: Mapped[int] = mapped_column(
        ForeignKey("instruments.id", ondelete="CASCADE"), nullable=False
    )
    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user = relationship("User", back_populates="user_instruments")
    instrument = relationship("Instrument", back_populates="user_instruments")
    follios = relationship("Follio", back_populates="user_instrument")
    investments = relationship("Investment", back_populates="user_instrument")


class Instrument(Base):
    __tablename__ = "instruments"
    __mapper_args__ = {"order_by": ["name", "ticker_symbol"]}

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    type: Mapped[InvestmentType] = mapped_column(
        Enum(InvestmentType, name="investment_type"), nullable=False, index=True
    )
    ticker_symbol: Mapped[str | None] = mapped_column(String(20), nullable=True)
    isin: Mapped[str | None] = mapped_column(String(20), nullable=True)
    exchange: Mapped[str | None] = mapped_column(String(20), nullable=True)
    fund_house: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user_instruments = relationship("UserInstrument", back_populates="instrument")
