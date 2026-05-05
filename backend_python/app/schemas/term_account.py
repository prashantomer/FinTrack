from datetime import date, datetime
from math import pow as math_pow

from pydantic import BaseModel, Field, model_validator

from app.models.term_account import TermAccountType
from app.schemas.bank import BankRead


class TermAccountCreate(BaseModel):
    parent_account_id: int
    type: TermAccountType
    account_number: str | None = Field(None, max_length=100)
    amount: float = Field(gt=0)
    open_date: date
    tenure_days: int | None = Field(None, gt=0)
    interest_rate: float = Field(gt=0, le=100)
    maturity_amount: float | None = Field(None, gt=0)
    balance: float = Field(0, ge=0)

    @model_validator(mode="after")
    def validate_type_fields(self) -> "TermAccountCreate":
        if self.type == TermAccountType.fd and not self.tenure_days:
            raise ValueError("tenure_days is required for FD accounts")
        if self.type == TermAccountType.ppf and self.tenure_days is not None:
            raise ValueError("tenure_days must not be set for PPF (always 15 years)")
        return self


class TermAccountRead(BaseModel):
    id: int
    user_id: int
    parent_account_id: int
    type: TermAccountType
    account_number: str | None
    amount: float
    open_date: date
    tenure_days: int | None
    interest_rate: float
    maturity_date: date
    maturity_amount: float
    balance: float
    closed_date: date | None
    closed_amount: float | None
    is_active: bool
    created_at: datetime
    bank: BankRead

    model_config = {"from_attributes": True}


class TermAccountUpdate(BaseModel):
    account_number: str | None = Field(None, max_length=100)
    amount: float | None = Field(None, gt=0)
    open_date: date | None = None
    interest_rate: float | None = Field(None, gt=0, le=100)
    maturity_date: date | None = None
    maturity_amount: float | None = Field(None, gt=0)
    balance: float | None = Field(None, ge=0)


class PPFDeposit(BaseModel):
    amount: float = Field(gt=0)
    date: date


class TermAccountClose(BaseModel):
    closed_date: date
    closed_amount: float = Field(gt=0)
