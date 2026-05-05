from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.follio import Follio
from app.models.instrument import user_instruments
from app.schemas.follio import FollioCreate, FollioUpdate


def _verify_instrument_tracked(db: Session, user_id: int, instrument_id: int) -> None:
    row = db.query(user_instruments).filter_by(user_id=user_id, instrument_id=instrument_id).first()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Instrument must be tracked before creating a follio. Track it first via /instruments/{id}/track.",
        )


def list_follios(db: Session, user_id: int) -> list[Follio]:
    return db.query(Follio).filter(Follio.user_id == user_id).order_by(Follio.created_at.desc()).all()


def get_follio(db: Session, follio_id: int, user_id: int) -> Follio:
    f = db.query(Follio).filter(Follio.id == follio_id, Follio.user_id == user_id).first()
    if not f:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Follio not found")
    return f


def create_follio(db: Session, data: FollioCreate, user_id: int) -> Follio:
    _verify_instrument_tracked(db, user_id, data.instrument_id)
    f = Follio(**data.model_dump(), user_id=user_id)
    db.add(f)
    db.commit()
    db.refresh(f)
    return f


def update_follio(db: Session, follio_id: int, data: FollioUpdate, user_id: int) -> Follio:
    f = get_follio(db, follio_id, user_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(f, field, value)
    db.commit()
    db.refresh(f)
    return f


def delete_follio(db: Session, follio_id: int, user_id: int) -> None:
    f = get_follio(db, follio_id, user_id)
    db.delete(f)
    db.commit()
