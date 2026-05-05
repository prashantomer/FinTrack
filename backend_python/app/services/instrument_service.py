from fastapi import HTTPException, status
from sqlalchemy import distinct, or_
from sqlalchemy.orm import Session, joinedload

from app.models.instrument import Instrument, InvestmentType, UserInstrument
from app.schemas.instrument import InstrumentCreate, InstrumentUpdate


def list_instrument_types(db: Session) -> list[InvestmentType]:
    rows = db.query(distinct(Instrument.type)).order_by(Instrument.type).all()
    return [r[0] for r in rows]


def list_instruments_paged(
    db: Session,
    type: InvestmentType | None = None,
    search: str | None = None,
    cursor: int | None = None,
    limit: int = 50,
) -> dict:
    offset = cursor or 0
    q = db.query(Instrument)
    if type:
        q = q.filter(Instrument.type == type)
    if search:
        term = f"%{search}%"
        q = q.filter(or_(
            Instrument.name.ilike(term),
            Instrument.ticker_symbol.ilike(term),
            Instrument.fund_house.ilike(term),
        ))
    total = q.count()
    items = q.offset(offset).limit(limit).all()
    next_offset = offset + limit
    return {
        "items": items,
        "next_cursor": next_offset if next_offset < total else None,
        "has_more": next_offset < total,
    }


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


def track_instrument(db: Session, instrument_id: int, user_id: int) -> UserInstrument:
    get_instrument(db, instrument_id)
    existing = db.query(UserInstrument).filter_by(
        user_id=user_id, instrument_id=instrument_id
    ).first()
    if existing:
        return existing
    ui = UserInstrument(user_id=user_id, instrument_id=instrument_id)
    db.add(ui)
    db.commit()
    db.refresh(ui)
    return ui


def untrack_instrument(db: Session, instrument_id: int, user_id: int) -> None:
    ui = db.query(UserInstrument).filter_by(
        user_id=user_id, instrument_id=instrument_id
    ).first()
    if ui:
        db.delete(ui)
        db.commit()


def list_tracked_instruments(db: Session, user_id: int) -> list[Instrument]:
    return (
        db.query(Instrument)
        .join(UserInstrument, Instrument.id == UserInstrument.instrument_id)
        .filter(UserInstrument.user_id == user_id)
        .order_by(Instrument.name)
        .all()
    )


def list_user_instruments(db: Session, user_id: int) -> list[UserInstrument]:
    return (
        db.query(UserInstrument)
        .options(joinedload(UserInstrument.instrument))
        .filter(UserInstrument.user_id == user_id)
        .order_by(UserInstrument.added_at.desc())
        .all()
    )
