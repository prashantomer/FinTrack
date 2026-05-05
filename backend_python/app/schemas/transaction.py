from datetime import date as Date, datetime as DateTime

from pydantic import BaseModel, Field

from app.models.transaction import LinkedAccountType, TransactionType


class TransactionCreate(BaseModel):
    amount: float = Field(gt=0)
    type: TransactionType
    linked_account_type: LinkedAccountType | None = None
    linked_account_id: int | None = None
    instrument_id: int | None = None
    description: str | None = Field(None, max_length=500)
    tags: list[str] | None = None
    bank_ref: str | None = Field(None, max_length=100)
    date: Date
    public_id: str | None = None


class TransactionRead(BaseModel):
    id: int
    user_id: int
    amount: float
    type: TransactionType
    linked_account_type: LinkedAccountType | None
    linked_account_id: int | None
    instrument_id: int | None
    description: str | None
    tags: list[str] | None
    bank_ref: str | None
    date: Date
    public_id: str | None
    is_active: bool
    created_at: DateTime

    model_config = {"from_attributes": True}


class TransactionListResponse(BaseModel):
    items: list[TransactionRead]
    total: int
    page: int
    page_size: int
    next_cursor: str | None = None
