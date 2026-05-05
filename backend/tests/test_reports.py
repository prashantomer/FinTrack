import pytest

INBOUND = {"amount": 80000.0, "type": "inbound", "date": "2026-01-15"}
OUTBOUND = {"amount": 3000.0, "type": "outbound", "date": "2026-01-20"}

STOCK = {
    "type": "stock", "name": "Reliance", "amount_invested": 50000.0, "current_value": 55000.0,
    "purchase_date": "2026-01-10", "ticker_symbol": "RELIANCE", "quantity": 10.0,
    "avg_buy_price": 5000.0, "exchange": "NSE",
}
GOLD = {
    "type": "gold", "name": "Gold ETF", "amount_invested": 20000.0, "current_value": 22000.0,
    "purchase_date": "2026-01-05",
}


@pytest.mark.asyncio
async def test_dashboard_empty(auth_client):
    client, _ = auth_client
    resp = await client.get("/api/v1/reports/dashboard")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_inbound"] == 0.0
    assert body["total_outbound"] == 0.0
    assert body["net_worth"] == 0.0


@pytest.mark.asyncio
async def test_dashboard_with_data(auth_client):
    client, _ = auth_client
    await client.post("/api/v1/transactions/", json=INBOUND)
    await client.post("/api/v1/transactions/", json=OUTBOUND)
    await client.post("/api/v1/investments/", json=STOCK)

    resp = await client.get("/api/v1/reports/dashboard")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_inbound"] == 80000.0
    assert body["total_outbound"] == 3000.0
    assert body["net_balance"] == 77000.0
    assert body["portfolio_value"] == 55000.0
    assert body["unrealized_gain"] == 5000.0


@pytest.mark.asyncio
async def test_spending_trends(auth_client):
    client, _ = auth_client
    await client.post("/api/v1/transactions/", json=INBOUND)
    await client.post("/api/v1/transactions/", json=OUTBOUND)
    resp = await client.get("/api/v1/reports/spending-trends?months=6")
    assert resp.status_code == 200
    months = resp.json()["months"]
    assert len(months) >= 1
    jan = next((m for m in months if m["month"] == "2026-01"), None)
    assert jan is not None
    assert jan["inbound"] == 80000.0
    assert jan["outbound"] == 3000.0
    assert jan["net"] == 77000.0


@pytest.mark.asyncio
async def test_investment_summary(auth_client):
    client, _ = auth_client
    await client.post("/api/v1/investments/", json=STOCK)
    await client.post("/api/v1/investments/", json=GOLD)
    resp = await client.get("/api/v1/reports/investment-summary")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_invested"] == 70000.0
    assert body["total_current_value"] == 77000.0
    assert body["total_unrealized_gain"] == 7000.0
    types = {h["type"] for h in body["holdings"]}
    assert "stock" in types
    assert "gold" in types


@pytest.mark.asyncio
async def test_investment_summary_empty(auth_client):
    client, _ = auth_client
    resp = await client.get("/api/v1/reports/investment-summary")
    assert resp.status_code == 200
    body = resp.json()
    assert body["holdings"] == []
    assert body["total_invested"] == 0.0
