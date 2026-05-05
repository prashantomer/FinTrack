from datetime import date, datetime

from pydantic import BaseModel

from app.models.transaction import TransactionType


class TransactionRef(BaseModel):
    id: int
    public_id: str | None
    amount: float
    type: TransactionType
    date: date
    description: str | None
    bank_ref: str | None

    model_config = {"from_attributes": True}


class AuditLogRead(BaseModel):
    id: int
    table_name: str
    record_id: int
    column_name: str
    old_value: str | None
    new_value: str | None
    changed_at: datetime
    transaction: TransactionRef | None

    model_config = {"from_attributes": True}
