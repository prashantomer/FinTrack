from datetime import datetime

from sqlalchemy import Column, DateTime, Enum, ForeignKey, Integer, String, Table, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.investment import InvestmentType

# Many-to-many junction table
user_instruments = Table(
    "user_instruments",
    Base.metadata,
    Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("instrument_id", Integer, ForeignKey("instruments.id", ondelete="CASCADE"), primary_key=True),
    Column("added_at", DateTime(timezone=True), server_default=func.now()),
)


class Instrument(Base):
    __tablename__ = "instruments"

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

    trackers = relationship("User", secondary=user_instruments, back_populates="instruments")
