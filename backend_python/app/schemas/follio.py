from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.instrument import UserInstrumentRead
from app.schemas.platform_account import PlatformAccountRead


class FollioCreate(BaseModel):
    follio_id: str = Field(max_length=100)
    user_instrument_id: int
    platform_account_id: int


class FollioRead(BaseModel):
    id: int
    follio_id: str
    user_id: int
    user_instrument_id: int
    platform_account_id: int
    created_at: datetime
    user_instrument: UserInstrumentRead
    platform_account: PlatformAccountRead

    model_config = {"from_attributes": True}


class FollioUpdate(BaseModel):
    follio_id: str | None = Field(None, max_length=100)
