from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, event, func
from sqlalchemy.orm import Mapped, attributes, mapped_column

from app.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    table_name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    record_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    column_name: Mapped[str] = mapped_column(String(100), nullable=False)
    old_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    new_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    @property
    def auditable_record(self):
        """Resolve the audited ORM record using table_name → model class from the registry."""
        from sqlalchemy import inspect as sa_inspect
        from app.models._audit_registry import _REGISTRY
        _table_map = {cls.__tablename__: cls for cls, _ in _REGISTRY}
        model_cls = _table_map.get(self.table_name)
        if model_cls is None:
            return None
        session = sa_inspect(self).session
        if session is None:
            return None
        return session.get(model_cls, self.record_id)


_SKIP = (attributes.NEVER_SET, attributes.NO_VALUE)


def _record(table_name: str, column_name: str, target, value, oldvalue) -> None:
    if oldvalue in _SKIP:
        return
    from sqlalchemy import inspect as sa_inspect
    session = sa_inspect(target).session
    if session is None or target.id is None:
        return
    session.add(AuditLog(
        table_name=table_name,
        record_id=target.id,
        column_name=column_name,
        old_value=str(oldvalue) if oldvalue is not None else None,
        new_value=str(value) if value is not None else None,
    ))


def register_audit(model_class, columns: list[str]) -> None:
    """Register attribute-set listeners for the given columns on a model class."""
    table_name = model_class.__tablename__
    for col_name in columns:
        attr = getattr(model_class, col_name)

        @event.listens_for(attr, "set")
        def _listener(target, value, oldvalue, initiator, _t=table_name, _c=col_name):
            _record(_t, _c, target, value, oldvalue)


def register_insert_audit(model_class, columns: list[str]) -> None:
    """Register after_insert listener to log the initial column values on record creation."""
    table_name = model_class.__tablename__

    @event.listens_for(model_class, "after_insert")
    def _insert_listener(mapper, connection, target, _t=table_name, _cols=columns):
        from sqlalchemy import inspect as sa_inspect
        session = sa_inspect(target).session
        if session is None:
            return
        for col_name in _cols:
            value = getattr(target, col_name, None)
            session.add(AuditLog(
                table_name=_t,
                record_id=target.id,
                column_name=col_name,
                old_value=None,
                new_value=str(value) if value is not None else None,
            ))


# Auto-register all models decorated with @auditable
from app.models._audit_registry import _REGISTRY

for _cls, _cols in _REGISTRY:
    register_audit(_cls, _cols)
    register_insert_audit(_cls, _cols)
