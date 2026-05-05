import logging
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import auth, client_errors, investments, reports, transactions
from app.routers import audit as audit_router
from app.routers import banks as banks_module
from app.routers import follio as follio_router
from app.routers import instruments as instruments_router
from app.routers import platforms as platforms_module
from app.routers import term_accounts as term_accounts_router

_level = settings.log_level.upper()
_LOG_DIR = Path(__file__).parent.parent.parent / "logs"
_LOG_DIR.mkdir(exist_ok=True)
logging.basicConfig(
    level=_level,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(_LOG_DIR / "app.log", encoding="utf-8"),
    ],
)
_logger = logging.getLogger(__name__)

_DIST = Path(__file__).parent.parent.parent / "frontend" / "dist"


def create_app() -> FastAPI:
    app = FastAPI(title="FinTrack API", version="0.1.0", redirect_slashes=False)

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        _logger.exception("Unhandled error on %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content={"detail": "An unexpected error occurred. Please try again."},
        )

    @app.get("/api/v1/health", tags=["health"])
    def health_check():
        return {"status": "ok"}

    app.include_router(auth.router)
    app.include_router(client_errors.router)
    app.include_router(transactions.router)
    app.include_router(investments.router)
    app.include_router(reports.router)
    app.include_router(instruments_router.router)
    app.include_router(banks_module.banks_router)
    app.include_router(banks_module.accounts_router)
    app.include_router(term_accounts_router.router)
    app.include_router(platforms_module.platforms_router)
    app.include_router(platforms_module.platform_accounts_router)
    app.include_router(audit_router.router)
    app.include_router(follio_router.router)

    if settings.environment == "production" and _DIST.exists():
        app.mount("/assets", StaticFiles(directory=_DIST / "assets"), name="assets")

        @app.get("/{full_path:path}", include_in_schema=False)
        def serve_spa(full_path: str):  # noqa: ARG001
            return FileResponse(_DIST / "index.html")

    return app


app = create_app()
