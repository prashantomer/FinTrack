from sqlalchemy.orm import Session

from app.models.audit import AuditLog
from app.models.transaction import Transaction
from app.schemas.audit import AuditLogRead, TransactionRef


def _build_audit_logs(db: Session, table_name: str, record_id: int, linked_account_type: str) -> list[AuditLogRead]:
    logs = (
        db.query(AuditLog)
        .filter(AuditLog.table_name == table_name, AuditLog.record_id == record_id)
        .order_by(AuditLog.changed_at.desc())
        .all()
    )
    result = []
    for log in logs:
        txn = (
            db.query(Transaction)
            .filter(
                Transaction.linked_account_type == linked_account_type,
                Transaction.linked_account_id == record_id,
                Transaction.created_at <= log.changed_at,
            )
            .order_by(Transaction.created_at.desc(), Transaction.id.desc())
            .first()
        )
        result.append(AuditLogRead(
            id=log.id,
            table_name=log.table_name,
            record_id=log.record_id,
            column_name=log.column_name,
            old_value=log.old_value,
            new_value=log.new_value,
            changed_at=log.changed_at,
            transaction=TransactionRef.model_validate(txn) if txn else None,
        ))
    return result


def list_account_audit_logs(db: Session, account_id: int) -> list[AuditLogRead]:
    return _build_audit_logs(db, "accounts", account_id, "account")


def list_term_account_audit_logs(db: Session, term_account_id: int) -> list[AuditLogRead]:
    return _build_audit_logs(db, "term_accounts", term_account_id, "term_account")
