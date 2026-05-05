from collections import defaultdict

from sqlalchemy.orm import Session, joinedload

from app.models.instrument import UserInstrument
from app.models.investment import Investment, InvestmentType
from app.schemas.report import (
    InvestmentTypeBreakdown,
    LotRead,
    PortfolioPlatformBreakdown,
    PortfolioPosition,
    PortfolioReport,
)


def get_portfolio(db: Session, user_id: int) -> PortfolioReport:
    investments = (
        db.query(Investment)
        .options(
            joinedload(Investment.user_instrument).joinedload(UserInstrument.instrument),
            joinedload(Investment.platform_account),
        )
        .filter(
            Investment.user_id == user_id,
            Investment.user_instrument_id.isnot(None),
        )
        .order_by(Investment.purchase_date.asc())
        .all()
    )

    # Group lots by user_instrument_id
    by_instrument: dict[int, list[Investment]] = defaultdict(list)
    for inv in investments:
        by_instrument[inv.user_instrument_id].append(inv)

    positions: list[PortfolioPosition] = []
    by_type: dict[InvestmentType, dict] = defaultdict(lambda: {"invested": 0.0, "current": 0.0, "count": 0})
    by_platform: dict[str, dict] = defaultdict(lambda: {"invested": 0.0, "current": 0.0})

    for ui_id, lots in by_instrument.items():
        first = lots[0]
        instrument = first.user_instrument.instrument
        inv_type = first.type

        total_invested = sum(float(l.amount_invested) for l in lots)
        current_value = sum(
            float(l.current_value) if l.current_value is not None else float(l.amount_invested)
            for l in lots
        )
        unrealized_gain = current_value - total_invested
        unrealized_gain_pct = (unrealized_gain / total_invested * 100) if total_invested else 0.0

        # Units (stock → quantity, MF → units)
        if inv_type == InvestmentType.stock:
            total_units_vals = [float(l.quantity) for l in lots if l.quantity is not None]
            total_units = sum(total_units_vals) if total_units_vals else None
            # Weighted avg buy price: sum(buy_price * qty) / sum(qty)
            weighted = sum(
                float(l.buy_price) * float(l.quantity)
                for l in lots
                if l.buy_price is not None and l.quantity is not None
            )
            qty_sum = sum(float(l.quantity) for l in lots if l.quantity is not None)
            avg_buy_price = weighted / qty_sum if qty_sum else None
        elif inv_type == InvestmentType.mutual_fund:
            total_units_vals = [float(l.units) for l in lots if l.units is not None]
            total_units = sum(total_units_vals) if total_units_vals else None
            # Weighted avg NAV
            weighted = sum(
                float(l.nav_at_purchase) * float(l.units)
                for l in lots
                if l.nav_at_purchase is not None and l.units is not None
            )
            unit_sum = sum(float(l.units) for l in lots if l.units is not None)
            avg_buy_price = weighted / unit_sum if unit_sum else None
        else:
            total_units = None
            avg_buy_price = None

        # Platform accounts holding this position
        platform_names: list[str] = []
        for lot in lots:
            if lot.platform_account:
                name = lot.platform_account.nickname
                if name not in platform_names:
                    platform_names.append(name)
                # Aggregate by_platform
                pa_key = lot.platform_account.nickname
                by_platform[pa_key]["invested"] += float(lot.amount_invested)
                cv = float(lot.current_value) if lot.current_value is not None else float(lot.amount_invested)
                by_platform[pa_key]["current"] += cv

        lot_reads = [
            LotRead(
                id=l.id,
                purchase_date=l.purchase_date,
                amount_invested=float(l.amount_invested),
                current_value=float(l.current_value) if l.current_value is not None else None,
                quantity=float(l.quantity) if l.quantity is not None else None,
                buy_price=float(l.buy_price) if l.buy_price is not None else None,
                folio_number=l.folio_number,
                units=float(l.units) if l.units is not None else None,
                nav_at_purchase=float(l.nav_at_purchase) if l.nav_at_purchase is not None else None,
                platform_account_nickname=l.platform_account.nickname if l.platform_account else None,
                notes=l.notes,
            )
            for l in lots
        ]

        positions.append(
            PortfolioPosition(
                user_instrument_id=ui_id,
                instrument_name=instrument.name,
                instrument_ticker=instrument.ticker_symbol,
                instrument_exchange=instrument.exchange,
                type=inv_type,
                platform_accounts=platform_names,
                total_lots=len(lots),
                total_units=total_units,
                total_invested=total_invested,
                avg_buy_price=avg_buy_price,
                current_value=current_value,
                unrealized_gain=unrealized_gain,
                unrealized_gain_pct=unrealized_gain_pct,
                lots=lot_reads,
            )
        )

        by_type[inv_type]["invested"] += total_invested
        by_type[inv_type]["current"] += current_value
        by_type[inv_type]["count"] += len(lots)

    # Sort: by type (stock first), then by current_value desc within type
    type_order = {InvestmentType.stock: 0, InvestmentType.mutual_fund: 1}
    positions.sort(key=lambda p: (type_order.get(p.type, 99), -p.current_value))

    total_invested_all = sum(p.total_invested for p in positions)
    current_value_all = sum(p.current_value for p in positions)
    unrealized_all = current_value_all - total_invested_all
    unrealized_pct_all = (unrealized_all / total_invested_all * 100) if total_invested_all else 0.0

    type_breakdown = [
        InvestmentTypeBreakdown(
            type=t,
            total_invested=d["invested"],
            current_value=d["current"],
            unrealized_gain=d["current"] - d["invested"],
            count=d["count"],
        )
        for t, d in sorted(by_type.items(), key=lambda x: x[1]["current"], reverse=True)
    ]

    platform_breakdown = sorted(
        [
            PortfolioPlatformBreakdown(
                platform_name=name,
                total_invested=d["invested"],
                current_value=d["current"],
            )
            for name, d in by_platform.items()
        ],
        key=lambda x: x.current_value,
        reverse=True,
    )

    return PortfolioReport(
        total_invested=total_invested_all,
        current_value=current_value_all,
        unrealized_gain=unrealized_all,
        unrealized_gain_pct=unrealized_pct_all,
        by_type=type_breakdown,
        by_platform=platform_breakdown,
        positions=positions,
    )
