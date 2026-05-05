from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.investment import Investment, InvestmentType
from app.schemas.investment import InvestmentCreate, InvestmentUpdate


def list_investments(
    db: Session,
    user_id: int,
    types: list[InvestmentType] | None = None,
) -> list[Investment]:
    q = db.query(Investment).filter(Investment.user_id == user_id)
    if types:
        q = q.filter(Investment.type.in_(types))
    return q.order_by(Investment.purchase_date.desc()).all()


def get_investment(db: Session, investment_id: int, user_id: int) -> Investment:
    inv = db.query(Investment).filter(
        Investment.id == investment_id, Investment.user_id == user_id
    ).first()
    if not inv:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Investment not found")
    return inv


def create_investment(db: Session, data: InvestmentCreate, user_id: int) -> Investment:
    inv = Investment(**data.model_dump(), user_id=user_id)
    db.add(inv)
    db.commit()
    db.refresh(inv)
    return inv


def update_investment(
    db: Session, investment_id: int, data: InvestmentUpdate, user_id: int
) -> Investment:
    inv = get_investment(db, investment_id, user_id)
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(inv, field, value)
    db.commit()
    db.refresh(inv)
    return inv


def delete_investment(db: Session, investment_id: int, user_id: int) -> None:
    inv = get_investment(db, investment_id, user_id)
    db.delete(inv)
    db.commit()
