import uuid
from datetime import date as Date, datetime

from pydantic import BaseModel, Field

from app.models.investment import InvestmentType


class InvestmentCreate(BaseModel):
    type: InvestmentType
    name: str = Field(max_length=255)
    amount_invested: float = Field(gt=0)
    current_value: float | None = Field(None, ge=0)
    purchase_date: Date
    notes: str | None = None
    platform_account_id: int | None = None
    user_instrument_id: int | None = None
    # Stock
    quantity: float | None = Field(None, gt=0)
    buy_price: float | None = Field(None, gt=0)
    # Mutual Fund
    folio_number: str | None = Field(None, max_length=50)
    units: float | None = Field(None, gt=0)
    nav_at_purchase: float | None = Field(None, gt=0)
    # Traceability
    transaction_public_id: uuid.UUID | None = None


class InvestmentRead(BaseModel):
    id: int
    user_id: int
    type: InvestmentType
    name: str
    amount_invested: float
    current_value: float | None
    purchase_date: Date
    notes: str | None
    platform_account_id: int | None
    user_instrument_id: int | None
    created_at: datetime
    # Stock
    quantity: float | None
    buy_price: float | None
    # Mutual Fund
    folio_number: str | None
    units: float | None
    nav_at_purchase: float | None
    # Traceability
    transaction_public_id: uuid.UUID | None

    model_config = {"from_attributes": True}


class InvestmentUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    amount_invested: float | None = Field(None, gt=0)
    current_value: float | None = Field(None, ge=0)
    purchase_date: Date | None = None
    notes: str | None = None
    platform_account_id: int | None = None
    user_instrument_id: int | None = None
    quantity: float | None = None
    buy_price: float | None = None
    folio_number: str | None = None
    units: float | None = None
    nav_at_purchase: float | None = None
    transaction_public_id: uuid.UUID | None = None


class InvestmentListResponse(BaseModel):
    items: list[InvestmentRead]
    total: int
