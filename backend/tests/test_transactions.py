import pytest


@pytest.mark.asyncio
async def test_create_transaction(auth_client):
    client, user = auth_client
    resp = await client.post("/api/v1/transactions/", json={
        "amount": 500.0,
        "type": "outbound",
        "description": "Groceries",
        "date": "2026-04-01",
    })
    assert resp.status_code == 201
    body = resp.json()
    assert body["amount"] == 500.0
    assert body["user_id"] == user.id


@pytest.mark.asyncio
async def test_list_transactions(auth_client):
    client, user = auth_client
    await client.post("/api/v1/transactions/", json={
        "amount": 1000.0, "type": "inbound", "date": "2026-04-01",
    })
    await client.post("/api/v1/transactions/", json={
        "amount": 200.0, "type": "outbound", "date": "2026-04-02",
    })
    resp = await client.get("/api/v1/transactions/")
    assert resp.status_code == 200
    assert resp.json()["total"] >= 2


@pytest.mark.asyncio
async def test_filter_by_type(auth_client):
    client, _ = auth_client
    await client.post("/api/v1/transactions/", json={
        "amount": 300.0, "type": "inbound", "date": "2026-04-03",
    })
    resp = await client.get("/api/v1/transactions/?type=inbound")
    assert resp.status_code == 200
    assert all(t["type"] == "inbound" for t in resp.json()["items"])


@pytest.mark.asyncio
async def test_get_transaction(auth_client):
    client, _ = auth_client
    created = (await client.post("/api/v1/transactions/", json={
        "amount": 99.0, "type": "outbound", "date": "2026-04-04",
    })).json()
    resp = await client.get(f"/api/v1/transactions/{created['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == created["id"]


@pytest.mark.asyncio
async def test_update_transaction(auth_client):
    client, _ = auth_client
    created = (await client.post("/api/v1/transactions/", json={
        "amount": 50.0, "type": "outbound", "date": "2026-04-05",
    })).json()
    resp = await client.put(f"/api/v1/transactions/{created['id']}", json={"amount": 75.0})
    assert resp.status_code == 200
    assert resp.json()["amount"] == 75.0


@pytest.mark.asyncio
async def test_delete_transaction(auth_client):
    client, _ = auth_client
    created = (await client.post("/api/v1/transactions/", json={
        "amount": 10.0, "type": "outbound", "date": "2026-04-06",
    })).json()
    resp = await client.delete(f"/api/v1/transactions/{created['id']}")
    assert resp.status_code == 204
    assert (await client.get(f"/api/v1/transactions/{created['id']}")).status_code == 404


@pytest.mark.asyncio
async def test_isolation_other_user_gets_404(client, db):
    from app.services.auth_service import create_access_token, create_user
    from app.services.transaction_service import create_transaction
    from app.schemas.transaction import TransactionCreate
    from app.models.transaction import TransactionType
    from datetime import date as d

    other = create_user(db, email="other@example.com", full_name="Other", password="pw")
    txn = create_transaction(db, TransactionCreate(
        amount=100, type=TransactionType.outbound, date=d(2026, 4, 1)
    ), other.id)

    token = create_access_token({"sub": "isolation_user@example.com"})
    create_user(db, email="isolation_user@example.com", full_name="Me", password="pw")

    resp = await client.get(
        f"/api/v1/transactions/{txn.id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404
