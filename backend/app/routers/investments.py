from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.investment import InvestmentType
from app.models.user import User
from app.schemas.investment import (
    InvestmentCreate,
    InvestmentListResponse,
    InvestmentRead,
    InvestmentUpdate,
)
from app.services.investment_service import (
    create_investment,
    get_investment,
    list_investments,
    update_investment,
)

router = APIRouter(prefix="/api/v1/investments", tags=["investments"])


@router.get("/", response_model=InvestmentListResponse)
def list_inv(
    type: list[InvestmentType] | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = list_investments(db, current_user.id, type)
    return InvestmentListResponse(items=items, total=len(items))


@router.post("/", response_model=InvestmentRead, status_code=status.HTTP_201_CREATED)
def create_inv(
    body: InvestmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_investment(db, body, current_user.id)


@router.get("/{investment_id}", response_model=InvestmentRead)
def get_inv(
    investment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_investment(db, investment_id, current_user.id)


@router.put("/{investment_id}", response_model=InvestmentRead)
def update_inv(
    investment_id: int,
    body: InvestmentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_investment(db, investment_id, body, current_user.id)


## DELETE /investments disabled
