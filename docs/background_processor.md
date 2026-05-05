# Dashboard Cache

FinTrack uses **Redis** to cache the dashboard report. There is no background processor — the cache is populated on manual refresh only.

---

## How it works

```
GET /api/v1/reports/dashboard
    ├── Cache hit  → return cached data instantly
    └── Cache miss → compute from DB, return result (does not write cache)

POST /api/v1/reports/dashboard/refresh
    └── Compute from DB → write to Redis → client refetches (hits fresh cache)
```

Cache TTL is **1 hour**. After expiry the next request computes from DB until the user manually refreshes again.

---

## Manual Refresh

**From the UI:** Click the **Refresh** button in the dashboard header.

**From the API:**
```bash
curl -X POST /api/v1/reports/dashboard/refresh \
  -H "Authorization: Bearer <token>"
```

---

## Cache Status

The dot indicator in the dashboard header shows:
- **Green** — cache warm (shows minutes remaining)
- **Yellow** — cache cold (next request hits DB)
- **Grey** — Redis not connected (all requests hit DB)

Full status via API:
```
GET /api/v1/reports/dashboard/cache-status
```

Response:
```json
{
  "redis_connected": true,
  "cache_warm": true,
  "cache_ttl_seconds": 3245
}
```

---

## Configuration

`backend/.env`:
```env
REDIS_URL=redis://localhost:6379/0
```

If `REDIS_URL` is unset or Redis is unavailable, the app falls back gracefully to direct DB queries on every request.

---

## Relevant Files

| File | Purpose |
|------|---------|
| `app/cache.py` | Redis helpers — get/set/TTL for dashboard cache |
| `app/routers/reports.py` | `GET /dashboard`, `POST /dashboard/refresh`, `GET /dashboard/cache-status` |
| `backend/.env` | `REDIS_URL` |
