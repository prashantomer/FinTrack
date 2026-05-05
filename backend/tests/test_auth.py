import pytest


@pytest.mark.asyncio
async def test_login(client, db):
    from app.services.auth_service import create_user

    create_user(db, email="login@example.com", full_name="Login User", password="pass1234")

    resp = await client.post(
        "/api/v1/auth/login",
        data={"username": "login@example.com", "password": "pass1234"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_wrong_password(client, db):
    from app.services.auth_service import create_user

    create_user(db, email="wrongpass@example.com", full_name="Wrong Pass", password="correct")

    resp = await client.post(
        "/api/v1/auth/login",
        data={"username": "wrongpass@example.com", "password": "incorrect"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_login_unknown_email(client):
    resp = await client.post(
        "/api/v1/auth/login",
        data={"username": "nobody@example.com", "password": "whatever"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_get_me(auth_client):
    client, user = auth_client
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 200
    body = resp.json()
    assert body["email"] == user.email
    assert body["full_name"] == user.full_name
    assert "hashed_password" not in body


@pytest.mark.asyncio
async def test_get_me_no_token(client):
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_update_me(auth_client):
    client, user = auth_client
    resp = await client.put("/api/v1/auth/me", json={"full_name": "Updated Name"})
    assert resp.status_code == 200
    assert resp.json()["full_name"] == "Updated Name"
