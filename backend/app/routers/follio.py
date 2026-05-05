from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.follio import FollioCreate, FollioRead, FollioUpdate
from app.services.follio_service import (
    create_follio,
    get_follio,
    list_follios,
    update_follio,
)

router = APIRouter(prefix="/api/v1/follios", tags=["follios"])


@router.get("/", response_model=list[FollioRead])
def list_f(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return list_follios(db, current_user.id)


@router.post("/", response_model=FollioRead, status_code=status.HTTP_201_CREATED)
def create_f(
    body: FollioCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_follio(db, body, current_user.id)


@router.get("/{follio_id}", response_model=FollioRead)
def get_f(
    follio_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_follio(db, follio_id, current_user.id)


@router.put("/{follio_id}", response_model=FollioRead)
def update_f(
    follio_id: int,
    body: FollioUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_follio(db, follio_id, body, current_user.id)


## DELETE /follios disabled
