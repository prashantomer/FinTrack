import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PlatformType(str, enum.Enum):
    broker = "broker"
    mf_platform = "mf_platform"
    direct = "direct"
    other = "other"


class Platform(Base):
    __tablename__ = "platforms"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    short_name: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    type: Mapped[PlatformType] = mapped_column(
        Enum(PlatformType, name="platform_type"), nullable=False
    )
    is_system: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    platform_accounts = relationship("PlatformAccount", back_populates="platform")
