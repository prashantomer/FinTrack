from datetime import date, datetime

from pydantic import BaseModel, Field

from app.models.account import AccountType
from app.schemas.bank import BankRead


class AccountCreate(BaseModel):
    bank_id: int
    nickname: str = Field(max_length=100)
    account_number: str | None = Field(None, max_length=50)
    account_type: AccountType = AccountType.savings
    balance: float = Field(0, ge=0)
    open_date: date | None = None


class AccountRead(BaseModel):
    id: int
    user_id: int
    bank_id: int
    nickname: str
    account_number: str | None
    account_type: AccountType
    balance: float
    open_date: date | None
    closed_date: date | None
    closed_amount: float | None
    created_at: datetime
    bank: BankRead

    model_config = {"from_attributes": True}


class AccountUpdate(BaseModel):
    nickname: str | None = Field(None, max_length=100)
    account_number: str | None = None
    account_type: AccountType | None = None
    balance: float | None = Field(None, ge=0)
    open_date: date | None = None


class AccountClose(BaseModel):
    closed_date: date
    closed_amount: float = Field(gt=0)


class BalanceAdjust(BaseModel):
    balance: float = Field(ge=0)
