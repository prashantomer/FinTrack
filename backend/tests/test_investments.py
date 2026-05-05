import pytest

STOCK_PAYLOAD = {
    "type": "stock",
    "name": "Reliance Industries",
    "amount_invested": 50000.0,
    "current_value": 55000.0,
    "purchase_date": "2026-01-15",
    "ticker_symbol": "RELIANCE",
    "quantity": 10.0,
    "avg_buy_price": 5000.0,
    "exchange": "NSE",
}

FD_PAYLOAD = {
    "type": "fixed_deposit",
    "name": "SBI FD",
    "amount_invested": 100000.0,
    "purchase_date": "2026-02-01",
    "bank_name": "SBI",
    "interest_rate": 7.5,
    "tenure_months": 12,
    "maturity_date": "2027-02-01",
    "maturity_amount": 107500.0,
    "compounding": "quarterly",
}


@pytest.mark.asyncio
async def test_create_stock_investment(auth_client):
    client, user = auth_client
    resp = await client.post("/api/v1/investments/", json=STOCK_PAYLOAD)
    assert resp.status_code == 201
    body = resp.json()
    assert body["type"] == "stock"
    assert body["ticker_symbol"] == "RELIANCE"
    assert body["user_id"] == user.id


@pytest.mark.asyncio
async def test_create_fd_investment(auth_client):
    client, _ = auth_client
    resp = await client.post("/api/v1/investments/", json=FD_PAYLOAD)
    assert resp.status_code == 201
    body = resp.json()
    assert body["type"] == "fixed_deposit"
    assert body["bank_name"] == "SBI"
    assert body["interest_rate"] == 7.5


@pytest.mark.asyncio
async def test_list_investments(auth_client):
    client, _ = auth_client
    await client.post("/api/v1/investments/", json=STOCK_PAYLOAD)
    await client.post("/api/v1/investments/", json=FD_PAYLOAD)
    resp = await client.get("/api/v1/investments/")
    assert resp.status_code == 200
    assert resp.json()["total"] >= 2


@pytest.mark.asyncio
async def test_filter_by_type(auth_client):
    client, _ = auth_client
    await client.post("/api/v1/investments/", json=STOCK_PAYLOAD)
    await client.post("/api/v1/investments/", json=FD_PAYLOAD)
    resp = await client.get("/api/v1/investments/?type=stock")
    assert resp.status_code == 200
    assert all(i["type"] == "stock" for i in resp.json()["items"])


@pytest.mark.asyncio
async def test_get_investment(auth_client):
    client, _ = auth_client
    created = (await client.post("/api/v1/investments/", json=STOCK_PAYLOAD)).json()
    resp = await client.get(f"/api/v1/investments/{created['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == created["id"]


@pytest.mark.asyncio
async def test_update_investment(auth_client):
    client, _ = auth_client
    created = (await client.post("/api/v1/investments/", json=STOCK_PAYLOAD)).json()
    resp = await client.put(
        f"/api/v1/investments/{created['id']}", json={"current_value": 60000.0}
    )
    assert resp.status_code == 200
    assert resp.json()["current_value"] == 60000.0


@pytest.mark.asyncio
async def test_delete_investment(auth_client):
    client, _ = auth_client
    created = (await client.post("/api/v1/investments/", json=STOCK_PAYLOAD)).json()
    resp = await client.delete(f"/api/v1/investments/{created['id']}")
    assert resp.status_code == 204
    assert (await client.get(f"/api/v1/investments/{created['id']}")).status_code == 404


@pytest.mark.asyncio
async def test_isolation_other_user_gets_404(client, db):
    from app.services.auth_service import create_access_token, create_user
    from app.services.investment_service import create_investment
    from app.schemas.investment import InvestmentCreate
    from app.models.investment import InvestmentType
    from datetime import date

    other = create_user(db, email="inv_other@example.com", full_name="Other", password="pw")
    inv = create_investment(db, InvestmentCreate(
        type=InvestmentType.gold, name="Gold Bar",
        amount_invested=10000, purchase_date=date(2026, 1, 1),
    ), other.id)

    create_user(db, email="inv_me@example.com", full_name="Me", password="pw")
    token = create_access_token({"sub": "inv_me@example.com"})

    resp = await client.get(
        f"/api/v1/investments/{inv.id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404
