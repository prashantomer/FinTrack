from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.instrument import InvestmentType
from app.models.user import User
from app.schemas.instrument import InstrumentCreate, InstrumentRead, InstrumentUpdate
from app.services.instrument_service import (
    create_instrument,
    get_instrument,
    list_instruments,
    list_tracked_instruments,
    track_instrument,
    untrack_instrument,
    update_instrument,
)

router = APIRouter(prefix="/api/v1/instruments", tags=["instruments"])


@router.get("/", response_model=list[InstrumentRead])
def list_all(
    type: InvestmentType | None = Query(None),
    search: str | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return list_instruments(db, type, search)


@router.post("/", response_model=InstrumentRead, status_code=status.HTTP_201_CREATED)
def create(
    body: InstrumentCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return create_instrument(db, body)


@router.get("/tracked", response_model=list[InstrumentRead])
def list_tracked(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_tracked_instruments(db, current_user.id)


@router.get("/{instrument_id}", response_model=InstrumentRead)
def get_one(
    instrument_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return get_instrument(db, instrument_id)


@router.put("/{instrument_id}", response_model=InstrumentRead)
def update(
    instrument_id: int,
    body: InstrumentUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return update_instrument(db, instrument_id, body)


@router.post("/{instrument_id}/track", status_code=status.HTTP_204_NO_CONTENT)
def track(
    instrument_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    track_instrument(db, instrument_id, current_user.id)


@router.delete("/{instrument_id}/track", status_code=status.HTTP_204_NO_CONTENT)
def untrack(
    instrument_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    untrack_instrument(db, instrument_id, current_user.id)
