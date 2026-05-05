from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserRead(BaseModel):
    id: int
    email: EmailStr
    first_name: str
    last_name: str
    full_name: str
    is_active: bool
    is_superuser: bool
    currency_code: str
    currency_locale: str
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    password: str | None = None
    currency_code: str | None = None
    currency_locale: str | None = None
