from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.audit import AuditLogRead
from app.services.audit_service import list_account_audit_logs
from app.services.bank_service import get_account

router = APIRouter(tags=["audit"])


@router.get("/api/v1/accounts/{account_id}/audit-logs", response_model=list[AuditLogRead])
def get_account_audit_logs(
    account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_account(db, account_id, current_user.id)
    return list_account_audit_logs(db, account_id)
