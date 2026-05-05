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
    instrument_id: int | None = None
    # Stock / ETF  (ticker, exchange → read from linked Instrument)
    quantity: float | None = Field(None, gt=0)
    avg_buy_price: float | None = Field(None, gt=0)
    # Mutual Fund  (fund_house → read from linked Instrument)
    folio_number: str | None = Field(None, max_length=50)
    units: float | None = Field(None, gt=0)
    nav_at_purchase: float | None = Field(None, gt=0)
    # Fixed Deposit
    bank_name: str | None = Field(None, max_length=100)
    fd_number: str | None = Field(None, max_length=50)
    interest_rate: float | None = Field(None, gt=0)
    tenure_months: int | None = Field(None, gt=0)
    maturity_date: Date | None = None
    maturity_amount: float | None = Field(None, gt=0)
    compounding: str | None = Field(None, max_length=20)
    # Gold
    gold_form: str | None = Field(None, max_length=30)
    weight_grams: float | None = Field(None, gt=0)
    purity: str | None = Field(None, max_length=10)
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
    instrument_id: int | None
    created_at: datetime
    # Stock / ETF
    quantity: float | None
    avg_buy_price: float | None
    # Mutual Fund
    folio_number: str | None
    units: float | None
    nav_at_purchase: float | None
    # Fixed Deposit
    bank_name: str | None
    fd_number: str | None
    interest_rate: float | None
    tenure_months: int | None
    maturity_date: Date | None
    maturity_amount: float | None
    compounding: str | None
    # Gold
    gold_form: str | None
    weight_grams: float | None
    purity: str | None
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
    instrument_id: int | None = None
    quantity: float | None = None
    avg_buy_price: float | None = None
    folio_number: str | None = None
    units: float | None = None
    nav_at_purchase: float | None = None
    bank_name: str | None = None
    fd_number: str | None = None
    interest_rate: float | None = None
    tenure_months: int | None = None
    maturity_date: Date | None = None
    maturity_amount: float | None = None
    compounding: str | None = None
    gold_form: str | None = None
    weight_grams: float | None = None
    purity: str | None = None
    transaction_public_id: uuid.UUID | None = None


class InvestmentListResponse(BaseModel):
    items: list[InvestmentRead]
    total: int
