from datetime import datetime

from pydantic import BaseModel

from app.models.platform import PlatformType


class PlatformRead(BaseModel):
    id: int
    name: str
    short_name: str
    type: PlatformType
    is_system: bool
    created_at: datetime

    model_config = {"from_attributes": True}
