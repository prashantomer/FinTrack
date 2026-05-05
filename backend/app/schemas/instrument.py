from datetime import datetime

from pydantic import BaseModel, Field

from app.models.instrument import InvestmentType


class InstrumentCreate(BaseModel):
    name: str = Field(max_length=255)
    type: InvestmentType
    ticker_symbol: str | None = Field(None, max_length=20)
    isin: str | None = Field(None, max_length=20)
    exchange: str | None = Field(None, max_length=20)
    fund_house: str | None = Field(None, max_length=100)


class InstrumentRead(BaseModel):
    id: int
    name: str
    type: InvestmentType
    ticker_symbol: str | None
    isin: str | None
    exchange: str | None
    fund_house: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class InstrumentUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    ticker_symbol: str | None = None
    isin: str | None = None
    exchange: str | None = None
    fund_house: str | None = None
