from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings

engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,       # drop stale connections before checkout
    pool_recycle=1800,        # recycle connections after 30 min
    connect_args={
        # kill the connection if it sits idle-in-transaction for > 30 s
        "options": "-c idle_in_transaction_session_timeout=30000"
    },
)


@event.listens_for(engine, "connect")
def _set_search_path(dbapi_conn, _):
    """Ensure every new connection has the timeout set (belt-and-suspenders)."""
    with dbapi_conn.cursor() as cur:
        cur.execute("SET idle_in_transaction_session_timeout = '30s'")


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass
