import json
import logging
from typing import Any

import redis as _redis_lib

from app.config import settings

log = logging.getLogger(__name__)

_client: _redis_lib.Redis | None = None
_init_attempted = False

_DASHBOARD_KEY = "dashboard:{user_id}"
_DASHBOARD_TTL = 60 * 60  # 1 hour; background job refreshes more frequently


def get_redis() -> _redis_lib.Redis | None:
    global _client, _init_attempted
    if _init_attempted:
        return _client
    _init_attempted = True
    if not settings.redis_url:
        log.info("REDIS_URL not configured — dashboard caching disabled")
        return None
    try:
        r = _redis_lib.from_url(settings.redis_url, decode_responses=True)
        r.ping()
        _client = r
        log.info("Redis connected: %s", settings.redis_url)
    except Exception as exc:
        log.warning("Redis unavailable, caching disabled: %s", exc)
    return _client


def get_dashboard_cache(user_id: int) -> dict[str, Any] | None:
    r = get_redis()
    if r is None:
        return None
    try:
        raw = r.get(_DASHBOARD_KEY.format(user_id=user_id))
        return json.loads(raw) if raw else None
    except Exception as exc:
        log.warning("Cache get failed: %s", exc)
        return None


def set_dashboard_cache(user_id: int, data: dict[str, Any]) -> None:
    r = get_redis()
    if r is None:
        return
    try:
        r.setex(_DASHBOARD_KEY.format(user_id=user_id), _DASHBOARD_TTL, json.dumps(data, default=str))
    except Exception as exc:
        log.warning("Cache set failed: %s", exc)


def invalidate_dashboard_cache(user_id: int) -> None:
    r = get_redis()
    if r is None:
        return
    try:
        r.delete(_DASHBOARD_KEY.format(user_id=user_id))
    except Exception as exc:
        log.warning("Cache invalidate failed: %s", exc)


def get_dashboard_cache_ttl(user_id: int) -> int | None:
    """Return seconds remaining on the cache entry, or None if not cached / Redis unavailable."""
    r = get_redis()
    if r is None:
        return None
    try:
        ttl = r.ttl(_DASHBOARD_KEY.format(user_id=user_id))
        return ttl if ttl > 0 else None
    except Exception as exc:
        log.warning("Cache TTL check failed: %s", exc)
        return None


def get_cached_user_ids() -> list[int]:
    """Return user IDs that currently have an active dashboard cache entry."""
    r = get_redis()
    if r is None:
        return []
    try:
        keys = r.keys("dashboard:*")
        return [int(k.split(":")[1]) for k in keys]
    except Exception as exc:
        log.warning("Cache scan failed: %s", exc)
        return []
