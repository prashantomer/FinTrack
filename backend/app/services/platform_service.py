from fastapi import HTTPException, status
from sqlalchemy.orm import Session

import app.models  # noqa: F401 — ensures all mappers are registered
from app.models.platform import Platform
from app.models.platform_account import PlatformAccount
from app.schemas.platform_account import PlatformAccountCreate, PlatformAccountUpdate


def list_platforms(db: Session) -> list[Platform]:
    return db.query(Platform).order_by(Platform.name).all()


def get_platform(db: Session, platform_id: int) -> Platform:
    p = db.get(Platform, platform_id)
    if not p:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Platform not found")
    return p


def create_platform(db: Session, name: str, short_name: str, type: str, is_system: bool = False) -> Platform:
    from app.models.platform import PlatformType
    p = Platform(name=name, short_name=short_name, type=PlatformType(type), is_system=is_system)
    db.add(p)
    db.commit()
    db.refresh(p)
    return p


def list_platform_accounts(db: Session, user_id: int) -> list[PlatformAccount]:
    return (
        db.query(PlatformAccount)
        .filter(PlatformAccount.user_id == user_id)
        .order_by(PlatformAccount.nickname)
        .all()
    )


def get_platform_account(db: Session, account_id: int, user_id: int) -> PlatformAccount:
    pa = db.query(PlatformAccount).filter(
        PlatformAccount.id == account_id, PlatformAccount.user_id == user_id
    ).first()
    if not pa:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Platform account not found")
    return pa


def create_platform_account(db: Session, data: PlatformAccountCreate, user_id: int) -> PlatformAccount:
    get_platform(db, data.platform_id)
    pa = PlatformAccount(**data.model_dump(), user_id=user_id)
    db.add(pa)
    db.commit()
    db.refresh(pa)
    return pa


def update_platform_account(
    db: Session, account_id: int, data: PlatformAccountUpdate, user_id: int
) -> PlatformAccount:
    pa = get_platform_account(db, account_id, user_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(pa, field, value)
    db.commit()
    db.refresh(pa)
    return pa


def delete_platform_account(db: Session, account_id: int, user_id: int) -> None:
    pa = get_platform_account(db, account_id, user_id)
    db.delete(pa)
    db.commit()
