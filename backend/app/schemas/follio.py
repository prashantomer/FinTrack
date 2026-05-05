from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.instrument import InstrumentRead
from app.schemas.platform import PlatformRead


class FollioCreate(BaseModel):
    follio_id: str = Field(max_length=100)
    platform_id: int
    instrument_id: int


class FollioRead(BaseModel):
    id: int
    follio_id: str
    user_id: int
    platform_id: int
    instrument_id: int
    created_at: datetime
    platform: PlatformRead
    instrument: InstrumentRead

    model_config = {"from_attributes": True}


class FollioUpdate(BaseModel):
    follio_id: str | None = Field(None, max_length=100)
