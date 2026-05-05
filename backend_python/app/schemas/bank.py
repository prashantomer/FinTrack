from datetime import datetime

from pydantic import BaseModel


class BankRead(BaseModel):
    id: int
    name: str
    short_name: str
    is_system: bool
    created_at: datetime

    model_config = {"from_attributes": True}
