import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import auth, banks, investments, platforms, reports, transactions
from app.routers import audit as audit_router
from app.routers import follio as follio_router
from app.routers import instruments as instruments_router
from app.routers import term_accounts as term_accounts_router

_level = settings.log_level.upper()
logging.basicConfig(level=_level)

_DIST = Path(__file__).parent.parent.parent / "frontend" / "dist"


def create_app() -> FastAPI:
    app = FastAPI(title="FinTrack API", version="0.1.0")

    @app.get("/api/v1/health", tags=["health"])
    def health_check():
        return {"status": "ok"}

    app.include_router(auth.router)
    app.include_router(transactions.router)
    app.include_router(investments.router)
    app.include_router(reports.router)
    app.include_router(instruments_router.router)
    app.include_router(banks.router)
    app.include_router(term_accounts_router.router)
    app.include_router(platforms.router)
    app.include_router(audit_router.router)
    app.include_router(follio_router.router)

    if _DIST.exists():
        app.mount("/assets", StaticFiles(directory=_DIST / "assets"), name="assets")

        @app.get("/{full_path:path}", include_in_schema=False)
        def serve_spa(full_path: str):  # noqa: ARG001
            return FileResponse(_DIST / "index.html")

    return app


app = create_app()
