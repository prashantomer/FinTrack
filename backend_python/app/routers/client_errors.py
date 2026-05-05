import logging

from fastapi import APIRouter, Request
from pydantic import BaseModel

router = APIRouter(prefix="/api/v1/errors", tags=["errors"])
_logger = logging.getLogger("client")


class ClientError(BaseModel):
    message: str
    stack: str | None = None
    component_stack: str | None = None
    url: str | None = None


@router.post("", status_code=204)
async def log_client_error(body: ClientError, request: Request):
    _logger.error(
        "CLIENT ERROR [%s] %s\nstack: %s\ncomponent_stack: %s",
        request.client.host if request.client else "unknown",
        body.message,
        body.stack or "(none)",
        body.component_stack or "(none)",
    )
