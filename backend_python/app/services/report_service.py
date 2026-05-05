from collections import defaultdict
from datetime import date, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.models.account import Account
from app.models.investment import Investment, InvestmentType
from app.models.term_account import TermAccount
from app.models.transaction import Transaction, TransactionType
from app.schemas.report import (
    AccountSummary,
    DashboardReport,
    InvestmentSummaryReport,
    InvestmentTypeBreakdown,
    MonthlyTrend,
    RecentTransaction,
    SpendingTrendsReport,
    TermAccountSummary,
)


def get_dashboard(db: Session, user_id: int) -> DashboardReport:
    today = date.today()
    first_of_month = today.replace(day=1)
    first_of_prev_month = (first_of_month - timedelta(days=1)).replace(day=1)
    last_of_prev_month = first_of_month - timedelta(days=1)

    def _sum(txn_type: TransactionType, from_date: date | None = None, to_date: date | None = None) -> float:
        q = db.query(func.sum(Transaction.amount)).filter(
            Transaction.user_id == user_id,
            Transaction.type == txn_type,
            Transaction.is_active.is_(True),
        )
        if from_date:
            q = q.filter(Transaction.date >= from_date)
        if to_date:
            q = q.filter(Transaction.date <= to_date)
        return float(q.scalar() or 0)

    total_inbound = _sum(TransactionType.credit)
    total_outbound = _sum(TransactionType.debit)
    this_month_inbound = _sum(TransactionType.credit, from_date=first_of_month)
    this_month_outbound = _sum(TransactionType.debit, from_date=first_of_month)
    prev_month_inbound = _sum(TransactionType.credit, from_date=first_of_prev_month, to_date=last_of_prev_month)
    prev_month_outbound = _sum(TransactionType.debit, from_date=first_of_prev_month, to_date=last_of_prev_month)

    # Active bank accounts sorted by balance descending
    accounts = (
        db.query(Account)
        .options(joinedload(Account.bank))
        .filter(Account.user_id == user_id, Account.closed_date.is_(None))
        .order_by(Account.balance.desc())
        .all()
    )
    accounts_balance = sum(float(a.balance) for a in accounts)

    # Active term accounts
    active_term = (
        db.query(TermAccount)
        .options(joinedload(TermAccount.parent_account).joinedload(Account.bank))
        .filter(TermAccount.user_id == user_id, TermAccount.is_active.is_(True))
        .all()
    )
    term_accounts_balance = sum(float(ta.balance) for ta in active_term)

    # Upcoming maturities within 90 days
    cutoff = today + timedelta(days=90)
    upcoming = sorted(
        [ta for ta in active_term if ta.maturity_date <= cutoff],
        key=lambda x: x.maturity_date,
    )

    # Investments grouped by type
    investments = db.query(Investment).filter(Investment.user_id == user_id).all()
    by_type: dict[InvestmentType, dict] = defaultdict(lambda: {"invested": 0.0, "current": 0.0, "count": 0})
    for inv in investments:
        by_type[inv.type]["invested"] += float(inv.amount_invested)
        cv = float(inv.current_value) if inv.current_value is not None else float(inv.amount_invested)
        by_type[inv.type]["current"] += cv
        by_type[inv.type]["count"] += 1

    investment_holdings = [
        InvestmentTypeBreakdown(
            type=t,
            total_invested=d["invested"],
            current_value=d["current"],
            unrealized_gain=d["current"] - d["invested"],
            count=d["count"],
        )
        for t, d in sorted(by_type.items(), key=lambda x: x[1]["current"], reverse=True)
    ]
    total_invested = sum(h.total_invested for h in investment_holdings)
    portfolio_value = sum(h.current_value for h in investment_holdings)
    unrealized_gain = portfolio_value - total_invested

    # Recent transactions (last 8)
    recent = (
        db.query(Transaction)
        .filter(Transaction.user_id == user_id, Transaction.is_active.is_(True))
        .order_by(Transaction.date.desc(), Transaction.id.desc())
        .limit(8)
        .all()
    )

    net_worth = accounts_balance + term_accounts_balance + portfolio_value

    return DashboardReport(
        net_worth=net_worth,
        accounts_balance=accounts_balance,
        term_accounts_balance=term_accounts_balance,
        portfolio_value=portfolio_value,
        total_invested=total_invested,
        unrealized_gain=unrealized_gain,
        total_inbound=total_inbound,
        total_outbound=total_outbound,
        net_balance=total_inbound - total_outbound,
        this_month_inbound=this_month_inbound,
        this_month_outbound=this_month_outbound,
        this_month_net=this_month_inbound - this_month_outbound,
        prev_month_inbound=prev_month_inbound,
        prev_month_outbound=prev_month_outbound,
        accounts=[
            AccountSummary(
                id=a.id,
                nickname=a.nickname,
                bank_short_name=a.bank.short_name,
                account_type=a.account_type.value,
                balance=float(a.balance),
            )
            for a in accounts
        ],
        upcoming_maturities=[
            TermAccountSummary(
                id=ta.id,
                account_number=ta.account_number,
                type=ta.type.value,
                bank_short_name=ta.parent_account.bank.short_name,
                balance=float(ta.balance),
                maturity_date=ta.maturity_date,
                maturity_amount=float(ta.maturity_amount) if ta.maturity_amount else None,
                days_remaining=(ta.maturity_date - today).days,
            )
            for ta in upcoming
        ],
        investment_holdings=investment_holdings,
        recent_transactions=[
            RecentTransaction(
                id=t.id,
                date=t.date,
                type=t.type.value,
                amount=float(t.amount),
                description=t.description,
                tags=t.tags or [],
            )
            for t in recent
        ],
    )


def get_spending_trends(db: Session, user_id: int, months: int = 6) -> SpendingTrendsReport:
    rows = (
        db.query(
            func.to_char(Transaction.date, "YYYY-MM").label("month"),
            Transaction.type,
            func.sum(Transaction.amount).label("total"),
        )
        .filter(Transaction.user_id == user_id, Transaction.is_active.is_(True))
        .group_by("month", Transaction.type)
        .order_by("month")
        .all()
    )

    by_month: dict[str, dict] = defaultdict(lambda: {"inbound": 0.0, "outbound": 0.0})
    for row in rows:
        if row.type == TransactionType.credit:
            by_month[row.month]["inbound"] += float(row.total)
        else:
            by_month[row.month]["outbound"] += float(row.total)

    sorted_months = sorted(by_month.keys())[-months:]
    trends = [
        MonthlyTrend(
            month=m,
            inbound=by_month[m]["inbound"],
            outbound=by_month[m]["outbound"],
            net=by_month[m]["inbound"] - by_month[m]["outbound"],
        )
        for m in sorted_months
    ]
    return SpendingTrendsReport(months=trends)


def get_investment_summary(db: Session, user_id: int) -> InvestmentSummaryReport:
    investments = db.query(Investment).filter(Investment.user_id == user_id).all()

    by_type: dict[InvestmentType, dict] = defaultdict(
        lambda: {"invested": 0.0, "current": 0.0, "count": 0}
    )
    for inv in investments:
        t = inv.type
        by_type[t]["invested"] += float(inv.amount_invested)
        cv = float(inv.current_value) if inv.current_value is not None else float(inv.amount_invested)
        by_type[t]["current"] += cv
        by_type[t]["count"] += 1

    holdings = [
        InvestmentTypeBreakdown(
            type=t,
            total_invested=d["invested"],
            current_value=d["current"],
            unrealized_gain=d["current"] - d["invested"],
            count=d["count"],
        )
        for t, d in by_type.items()
    ]
    total_invested = sum(h.total_invested for h in holdings)
    total_current = sum(h.current_value for h in holdings)
    return InvestmentSummaryReport(
        holdings=holdings,
        total_invested=total_invested,
        total_current_value=total_current,
        total_unrealized_gain=total_current - total_invested,
    )
