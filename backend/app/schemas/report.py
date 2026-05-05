from datetime import date

from pydantic import BaseModel

from app.models.investment import InvestmentType


class AccountSummary(BaseModel):
    id: int
    nickname: str
    bank_short_name: str
    account_type: str
    balance: float


class TermAccountSummary(BaseModel):
    id: int
    account_number: str | None
    type: str
    bank_short_name: str
    balance: float
    maturity_date: date
    maturity_amount: float | None
    days_remaining: int


class RecentTransaction(BaseModel):
    id: int
    date: date
    type: str
    amount: float
    description: str | None
    tags: list[str]


class InvestmentTypeBreakdown(BaseModel):
    type: InvestmentType
    total_invested: float
    current_value: float
    unrealized_gain: float
    count: int


class DashboardReport(BaseModel):
    # Net worth
    net_worth: float
    accounts_balance: float
    term_accounts_balance: float
    portfolio_value: float
    total_invested: float
    unrealized_gain: float

    # All-time cash flow (kept for backward compat)
    total_inbound: float
    total_outbound: float
    net_balance: float

    # Current month
    this_month_inbound: float
    this_month_outbound: float
    this_month_net: float
    prev_month_inbound: float
    prev_month_outbound: float

    # Breakdowns
    accounts: list[AccountSummary]
    upcoming_maturities: list[TermAccountSummary]
    investment_holdings: list[InvestmentTypeBreakdown]
    recent_transactions: list[RecentTransaction]


class MonthlyTrend(BaseModel):
    month: str  # "YYYY-MM"
    inbound: float
    outbound: float
    net: float


class SpendingTrendsReport(BaseModel):
    months: list[MonthlyTrend]


class InvestmentSummaryReport(BaseModel):
    holdings: list[InvestmentTypeBreakdown]
    total_invested: float
    total_current_value: float
    total_unrealized_gain: float


class DashboardCacheStatus(BaseModel):
    redis_connected: bool
    cache_warm: bool
    cache_ttl_seconds: int | None
