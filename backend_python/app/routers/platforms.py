from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.platform import PlatformRead
from app.schemas.platform_account import (
    PlatformAccountCreate,
    PlatformAccountRead,
    PlatformAccountUpdate,
)
from app.services.platform_service import (
    create_platform_account,
    get_platform_account,
    list_platform_accounts,
    list_platforms,
    update_platform_account,
)

platforms_router = APIRouter(prefix="/api/v1/platforms", tags=["platforms"])
platform_accounts_router = APIRouter(prefix="/api/v1/platform-accounts", tags=["platform-accounts"])


@platforms_router.get("", response_model=list[PlatformRead])
def get_platforms(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return list_platforms(db)


@platform_accounts_router.get("", response_model=list[PlatformAccountRead])
def get_platform_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_platform_accounts(db, current_user.id)


@platform_accounts_router.post("", response_model=PlatformAccountRead, status_code=status.HTTP_201_CREATED)
def create_pa(
    body: PlatformAccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_platform_account(db, body, current_user.id)


@platform_accounts_router.get("/{account_id}", response_model=PlatformAccountRead)
def get_pa(
    account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_platform_account(db, account_id, current_user.id)


@platform_accounts_router.put("/{account_id}", response_model=PlatformAccountRead)
def update_pa(
    account_id: int,
    body: PlatformAccountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_platform_account(db, account_id, body, current_user.id)
