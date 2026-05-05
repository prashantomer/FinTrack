from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.instrument import Instrument, InvestmentType, user_instruments
from app.schemas.instrument import InstrumentCreate, InstrumentUpdate


def list_instruments(
    db: Session,
    type: InvestmentType | None = None,
    search: str | None = None,
) -> list[Instrument]:
    q = db.query(Instrument)
    if type:
        q = q.filter(Instrument.type == type)
    if search:
        q = q.filter(Instrument.name.ilike(f"%{search}%"))
    return q.order_by(Instrument.name).all()


def get_instrument(db: Session, instrument_id: int) -> Instrument:
    inst = db.get(Instrument, instrument_id)
    if not inst:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Instrument not found")
    return inst


def create_instrument(db: Session, data: InstrumentCreate) -> Instrument:
    inst = Instrument(**data.model_dump())
    db.add(inst)
    db.commit()
    db.refresh(inst)
    return inst


def update_instrument(db: Session, instrument_id: int, data: InstrumentUpdate) -> Instrument:
    inst = get_instrument(db, instrument_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(inst, field, value)
    db.commit()
    db.refresh(inst)
    return inst


def track_instrument(db: Session, instrument_id: int, user_id: int) -> None:
    get_instrument(db, instrument_id)
    exists = db.execute(
        user_instruments.select().where(
            user_instruments.c.user_id == user_id,
            user_instruments.c.instrument_id == instrument_id,
        )
    ).first()
    if not exists:
        db.execute(
            user_instruments.insert().values(user_id=user_id, instrument_id=instrument_id)
        )
        db.commit()


def untrack_instrument(db: Session, instrument_id: int, user_id: int) -> None:
    db.execute(
        user_instruments.delete().where(
            user_instruments.c.user_id == user_id,
            user_instruments.c.instrument_id == instrument_id,
        )
    )
    db.commit()


def list_tracked_instruments(db: Session, user_id: int) -> list[Instrument]:
    return (
        db.query(Instrument)
        .join(user_instruments, Instrument.id == user_instruments.c.instrument_id)
        .filter(user_instruments.c.user_id == user_id)
        .order_by(Instrument.name)
        .all()
    )
