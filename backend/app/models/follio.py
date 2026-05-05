from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Follio(Base):
    """User's position account for a specific instrument on a specific platform."""

    __tablename__ = "follios"
    __table_args__ = (
        UniqueConstraint("user_id", "platform_id", "instrument_id", name="uq_follio_user_platform_instrument"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    follio_id: Mapped[str] = mapped_column(String(100), nullable=False)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    platform_id: Mapped[int] = mapped_column(
        ForeignKey("platforms.id", ondelete="RESTRICT"), nullable=False
    )
    instrument_id: Mapped[int] = mapped_column(
        ForeignKey("instruments.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    user = relationship("User")
    platform = relationship("Platform")
    instrument = relationship("Instrument")
