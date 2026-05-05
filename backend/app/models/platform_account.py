from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PlatformAccount(Base):
    """A user's account on an investment platform — user ↔ platform junction."""

    __tablename__ = "platform_accounts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    platform_id: Mapped[int] = mapped_column(
        ForeignKey("platforms.id", ondelete="RESTRICT"), nullable=False
    )
    nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    account_id: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    platform = relationship("Platform", back_populates="platform_accounts")
    user = relationship("User", back_populates="platform_accounts")
    investments = relationship("Investment", back_populates="platform_account")
