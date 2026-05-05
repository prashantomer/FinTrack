from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.cache import get_dashboard_cache, get_dashboard_cache_ttl, get_redis, set_dashboard_cache
from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.report import (
    DashboardCacheStatus,
    DashboardReport,
    InvestmentSummaryReport,
    PortfolioReport,
    SpendingTrendsReport,
)
from app.services.portfolio_service import get_portfolio
from app.services.report_service import (
    get_dashboard,
    get_investment_summary,
    get_spending_trends,
)

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])


@router.get("/dashboard", response_model=DashboardReport)
def dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    cached = get_dashboard_cache(current_user.id)
    if cached:
        return DashboardReport.model_validate(cached)
    # Cache miss (first load or expired) — compute once, write to cache.
    # After this, all requests serve from cache until manual refresh.
    report = get_dashboard(db, current_user.id)
    set_dashboard_cache(current_user.id, report.model_dump(mode="json"))
    return report


@router.post("/dashboard/refresh", status_code=204)
def refresh_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Recompute the dashboard and write to cache."""
    report = get_dashboard(db, current_user.id)
    set_dashboard_cache(current_user.id, report.model_dump(mode="json"))


@router.get("/dashboard/cache-status", response_model=DashboardCacheStatus)
def dashboard_cache_status(current_user: User = Depends(get_current_user)):
    ttl = get_dashboard_cache_ttl(current_user.id)
    return DashboardCacheStatus(
        redis_connected=get_redis() is not None,
        cache_warm=ttl is not None,
        cache_ttl_seconds=ttl,
    )


@router.get("/spending-trends", response_model=SpendingTrendsReport)
def spending_trends(
    months: int = Query(6, ge=1, le=24),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_spending_trends(db, current_user.id, months)


@router.get("/investment-summary", response_model=InvestmentSummaryReport)
def investment_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_investment_summary(db, current_user.id)


@router.get("/portfolio", response_model=PortfolioReport)
def portfolio(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_portfolio(db, current_user.id)
