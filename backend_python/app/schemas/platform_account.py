from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.platform import PlatformRead


class PlatformAccountCreate(BaseModel):
    platform_id: int
    nickname: str = Field(max_length=100)
    account_id: str | None = Field(None, max_length=50)


class PlatformAccountRead(BaseModel):
    id: int
    user_id: int
    platform_id: int
    nickname: str
    account_id: str | None
    created_at: datetime
    platform: PlatformRead

    model_config = {"from_attributes": True}


class PlatformAccountUpdate(BaseModel):
    nickname: str | None = Field(None, max_length=100)
    account_id: str | None = None
