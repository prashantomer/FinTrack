from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Follio(Base):
    """A user's folio — links a tracked instrument (UserInstrument) to a
    specific platform account where it is held."""

    __tablename__ = "follios"
    __table_args__ = (
        UniqueConstraint(
            "user_instrument_id", "platform_account_id",
            name="uq_follio_user_instrument_account",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    follio_id: Mapped[str] = mapped_column(String(100), nullable=False)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_instrument_id: Mapped[int] = mapped_column(
        ForeignKey("user_instruments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    platform_account_id: Mapped[int] = mapped_column(
        ForeignKey("platform_accounts.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    user = relationship("User")
    user_instrument = relationship("UserInstrument", back_populates="follios")
    platform_account = relationship("PlatformAccount")
