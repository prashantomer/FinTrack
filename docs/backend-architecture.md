# FinTrack Backend Architecture

## Table of Contents

1. [High-Level Design (HLD)](#1-high-level-design)
   - 1.1 [System Overview](#11-system-overview)
   - 1.2 [Component Architecture](#12-component-architecture)
   - 1.3 [Request Lifecycle](#13-request-lifecycle)
   - 1.4 [Deployment Architecture](#14-deployment-architecture)
   - 1.5 [Tech Stack Rationale](#15-tech-stack-rationale)
2. [Low-Level Design (LLD)](#2-low-level-design)
   - 2.1 [Directory Structure](#21-directory-structure)
   - 2.2 [Database Schema](#22-database-schema)
   - 2.3 [API Contract](#23-api-contract)
   - 2.4 [Authentication Flow](#24-authentication-flow)
   - 2.5 [Layer Responsibilities](#25-layer-responsibilities)
   - 2.6 [Service Layer Design](#26-service-layer-design)
   - 2.7 [Report Queries](#27-report-queries)
   - 2.8 [Pagination](#28-pagination)
   - 2.9 [Error Handling](#29-error-handling)
   - 2.10 [Configuration Management](#210-configuration-management)
   - 2.11 [Database Migrations](#211-database-migrations)
   - 2.12 [Testing Strategy](#212-testing-strategy)

---

## 1. High-Level Design

### 1.1 System Overview

FinTrack is a **monolithic** personal finance tracker. A single FastAPI process is the entire backend — it owns the REST API, business logic, data access, and (in production) also serves the compiled React frontend as static files.

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Browser                          │
│          http://localhost:5173 (dev)                        │
│          http://localhost:8000 (prod)                       │
└───────────────────┬─────────────────────────────────────────┘
                    │
          ┌─────────▼──────────┐
          │   Vite Dev Server  │  (development only, port 5173)
          │   Proxy /api →     │
          │   localhost:8000   │
          └─────────┬──────────┘
                    │
┌───────────────────▼─────────────────────────────────────────┐
│                  FastAPI Process (port 8000)                 │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  /api/v1/*   │  │  /assets/*   │  │  /* (catch-all)  │  │
│  │  REST API    │  │  Static JS/  │  │  Serves          │  │
│  │  Routers     │  │  CSS files   │  │  index.html      │  │
│  └──────┬───────┘  └──────────────┘  └──────────────────┘  │
│         │               (production only — frontend/dist/)  │
│  ┌──────▼───────┐                                           │
│  │   Services   │  Business logic, aggregations             │
│  └──────┬───────┘                                           │
│         │                                                   │
│  ┌──────▼───────┐                                           │
│  │  SQLAlchemy  │  ORM, query building                      │
│  │    ORM       │                                           │
│  └──────┬───────┘                                           │
└─────────┼───────────────────────────────────────────────────┘
          │
┌─────────▼───────────────┐
│      PostgreSQL          │
│  (fintrack_db database)  │
└──────────────────────────┘
```

### 1.2 Component Architecture

```
backend/app/
│
├── main.py          ← Entry point: app factory, router wiring, SPA serving
│
├── config.py        ← Single source of truth for all settings
├── database.py      ← DB engine, session factory, declarative Base
├── dependencies.py  ← Shared FastAPI Depends(): get_db, get_current_user
│
├── models/          ← SQLAlchemy ORM table definitions
│   ├── user.py
│   ├── transaction.py
│   ├── investment.py
│   ├── bank.py          ← Bank, Account
│   ├── platform.py      ← Platform, PlatformAccount
│   └── instrument.py    ← Instrument, UserInstrument
│
├── schemas/         ← Pydantic v2 I/O contracts (validation + serialization)
│   ├── user.py
│   ├── transaction.py
│   ├── investment.py
│   ├── reports.py
│   ├── bank.py
│   ├── platform.py
│   └── instrument.py
│
├── routers/         ← HTTP routing only; no business logic
│   ├── auth.py
│   ├── transactions.py
│   ├── investments.py
│   ├── reports.py
│   ├── banks.py
│   ├── accounts.py
│   ├── platforms.py
│   ├── platform_accounts.py
│   └── instruments.py
│
├── services/        ← All business logic and DB queries live here
│   ├── auth_service.py
│   ├── transaction_service.py
│   ├── investment_service.py
│   ├── report_service.py
│   ├── bank_service.py
│   ├── platform_service.py
│   └── instrument_service.py
│
└── utils/
    └── pagination.py  ← Reusable page/offset helper
```

**Data flow**: HTTP Request → Router (validates schema) → Service (business logic + DB) → Response schema (serialized) → HTTP Response.

Routers are intentionally thin. They handle HTTP concerns (status codes, path params, query params) and delegate everything else to services. Services are plain Python — no FastAPI imports — making them independently testable.

### 1.3 Request Lifecycle

**Authenticated API call (e.g. GET /api/v1/transactions)**

```
Browser
  │
  ├─► FastAPI middleware stack
  │     └─ CORS middleware (dev: allows localhost:5173)
  │
  ├─► Router: GET /api/v1/transactions
  │     ├─ Query params parsed + validated by Pydantic
  │     └─ Dependencies resolved:
  │           ├─ get_db()         → yields SQLAlchemy Session
  │           └─ get_current_user() → decodes JWT → loads User from DB
  │
  ├─► transaction_service.list_transactions(db, user, filters)
  │     ├─ Builds SQLAlchemy query with WHERE user_id = :uid
  │     ├─ Applies filters (type, category, date range)
  │     ├─ Applies ORDER BY + LIMIT/OFFSET (pagination)
  │     └─ Returns (items: list[Transaction], total: int)
  │
  ├─► Router serializes result → TransactionListResponse (Pydantic)
  │
  └─► HTTP 200 JSON response
```

**Error path**: any `HTTPException` raised in services or dependencies short-circuits to the error response. SQLAlchemy errors bubble up and are caught by a global exception handler in `main.py`.

### 1.4 Deployment Architecture

#### Development

```
Terminal 1                          Terminal 2
──────────────────────────────────  ──────────────────────────────────
uvicorn app.main:app                npm run dev
  --reload                          (Vite, port 5173)
  --port 8000
                                    vite.config.ts proxy:
FastAPI serves /api/v1/* only         /api → http://localhost:8000
(no static files — dist/ absent)
```

React's Vite dev server has Hot Module Replacement. All `/api` requests are transparently proxied to FastAPI — so the browser sees a single origin (port 5173) and no CORS issues arise.

#### Production

```
Single process, single port
──────────────────────────────────────────────────────────
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4

FastAPI serves:
  /api/v1/*          → REST API routers
  /assets/*          → StaticFiles(frontend/dist/assets/)
  /* (catch-all)     → FileResponse(frontend/dist/index.html)
                       (enables React Router client-side routing)
```

`frontend/dist/` is produced by `npm run build` before starting the server. When `main.py` detects the `dist/` directory exists, it auto-mounts the static file handler and catch-all route.

### 1.5 Tech Stack Rationale

| Component | Choice | Why |
|-----------|--------|-----|
| Web framework | FastAPI 0.136 | Async-native, Pydantic v2 built-in, auto Swagger UI at `/docs` |
| ORM | SQLAlchemy 2.0 | Mature, Alembic migration tooling, explicit SQL control |
| DB driver | psycopg3 (`psycopg[binary]`) | Python 3.13 compatible; async-capable; replaces legacy psycopg2 |
| Migrations | Alembic | Native SQLAlchemy integration; autogenerate from model changes |
| Validation | Pydantic v2 | ~10× faster than v1; discriminated unions for investment subtypes |
| Auth tokens | python-jose (JWT HS256) | Stateless; no session storage needed for personal app scale |
| Password hash | passlib bcrypt | Industry standard; slow-hash by design |
| HTTP client (tests) | httpx + ASGI transport | Tests run against real app instance, no mocking required |

---

## 2. Low-Level Design

### 2.1 Directory Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── dependencies.py
│   ├── models/
│   │   ├── __init__.py          ← imports ALL models (required: populates mapper registry before string-referenced relationships resolve)
│   │   ├── user.py
│   │   ├── transaction.py
│   │   ├── investment.py
│   │   ├── bank.py              ← Bank, Account
│   │   ├── platform.py          ← Platform, PlatformAccount
│   │   └── instrument.py        ← Instrument, UserInstrument (M2M)
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── transaction.py
│   │   ├── investment.py
│   │   ├── reports.py
│   │   ├── bank.py
│   │   ├── platform.py
│   │   └── instrument.py
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── transactions.py
│   │   ├── investments.py
│   │   ├── reports.py
│   │   ├── banks.py
│   │   ├── accounts.py
│   │   ├── platforms.py
│   │   ├── platform_accounts.py
│   │   └── instruments.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── transaction_service.py
│   │   ├── investment_service.py
│   │   ├── report_service.py
│   │   ├── bank_service.py
│   │   ├── platform_service.py
│   │   └── instrument_service.py
│   └── utils/
│       ├── __init__.py
│       └── pagination.py
├── alembic/
│   ├── env.py                   ← imports models; sets target_metadata
│   ├── script.py.mako
│   └── versions/                ← auto-generated migration files
├── tests/
│   ├── __init__.py
│   ├── conftest.py              ← test DB, async client fixture
│   ├── test_auth.py
│   ├── test_transactions.py
│   ├── test_investments.py
│   └── test_reports.py
├── alembic.ini
├── requirements.txt
└── .env                         ← gitignored
```

### 2.2 Database Schema

#### `users` table

```sql
CREATE TABLE users (
    id              SERIAL          PRIMARY KEY,
    email           VARCHAR         NOT NULL UNIQUE,
    full_name       VARCHAR         NOT NULL,
    hashed_password VARCHAR         NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX ix_users_email ON users (email);
```

#### `banks` table

```sql
CREATE TABLE banks (
    id          SERIAL      PRIMARY KEY,
    name        VARCHAR     NOT NULL UNIQUE,
    short_name  VARCHAR,
    is_system   BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Admin-managed via CLI (`uv run python -m app.cli banks seed/create/list`). Not user-editable through the API. Seeded with 10 common Indian banks: HDFC, SBI, ICICI, Axis, Kotak, PNB, BOB, Canara, IndusInd, Yes Bank.

#### `accounts` table

```sql
CREATE TYPE account_type AS ENUM ('savings', 'current', 'salary', 'nre', 'nro');

CREATE TABLE accounts (
    id             SERIAL       PRIMARY KEY,
    user_id        INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_id        INTEGER      NOT NULL REFERENCES banks(id) ON DELETE RESTRICT,
    nickname       VARCHAR      NOT NULL,
    account_number VARCHAR,
    account_type   account_type NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_accounts_user_id ON accounts (user_id);
```

#### `platforms` table

```sql
CREATE TYPE platform_type AS ENUM ('broker', 'mf_platform', 'direct', 'other');

CREATE TABLE platforms (
    id          SERIAL        PRIMARY KEY,
    name        VARCHAR       NOT NULL UNIQUE,
    short_name  VARCHAR,
    type        platform_type NOT NULL,
    is_system   BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
```

Admin-managed via CLI (`uv run python -m app.cli platforms seed/create/list`). Seeded with 11 investment platforms: Zerodha, Groww, Kite, Upstox, Angel One, HDFC Securities, ICICI Direct, Coin, MF Central, Paytm Money, Direct (AMC).

#### `platform_accounts` table

```sql
CREATE TABLE platform_accounts (
    id          SERIAL      PRIMARY KEY,
    user_id     INTEGER     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform_id INTEGER     NOT NULL REFERENCES platforms(id) ON DELETE RESTRICT,
    nickname    VARCHAR     NOT NULL,
    account_id  VARCHAR,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_platform_accounts_user_id ON platform_accounts (user_id);
```

#### `instruments` table

```sql
CREATE TABLE instruments (
    id            SERIAL          PRIMARY KEY,
    name          VARCHAR         NOT NULL,
    type          investment_type NOT NULL,
    ticker_symbol VARCHAR(20),
    isin          VARCHAR(12),
    exchange      VARCHAR(20),
    fund_house    VARCHAR(100),
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
```

Global catalogue of investable instruments (stocks, mutual funds, ETFs, etc.). Uses the existing `investment_type` enum as the type discriminator.

#### `user_instruments` table

```sql
CREATE TABLE user_instruments (
    user_id       INTEGER     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    instrument_id INTEGER     NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    added_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, instrument_id)
);
```

Many-to-many junction: tracks which instruments a user watches/holds.

#### `transactions` table

```sql
CREATE TYPE transaction_type AS ENUM ('inbound', 'outbound');

CREATE TABLE transactions (
    id            SERIAL           PRIMARY KEY,
    user_id       INTEGER          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount        NUMERIC(12, 2)   NOT NULL,
    type          transaction_type NOT NULL,
    description   VARCHAR(500),
    date          DATE             NOT NULL,
    notes         TEXT,
    account_id    INTEGER          REFERENCES accounts(id) ON DELETE SET NULL,
    instrument_id INTEGER          REFERENCES instruments(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX ix_transactions_user_id ON transactions (user_id);
CREATE INDEX ix_transactions_date    ON transactions (date);
```

**Breaking changes from prior schema**: `type` enum values renamed from `income/expense` → `inbound/outbound`; `category` column and `transaction_category` enum removed; `account_id` and `instrument_id` FK columns added (both nullable, SET NULL on delete).

#### `investments` table (single-table inheritance)

All investment types share one table. Type-specific columns are nullable and only populated for their relevant subtype. The `type` column is the discriminator.

```sql
-- investment_type enum was created by a prior migration; subsequent migrations
-- use postgresql.ENUM(..., create_type=False) to avoid duplicate-type errors.
CREATE TYPE investment_type AS ENUM (
    'stock', 'mutual_fund', 'fixed_deposit',
    'gold', 'crypto', 'ppf', 'nps', 'real_estate'
);

CREATE TABLE investments (
    id                  SERIAL          PRIMARY KEY,
    user_id             INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                investment_type NOT NULL,
    name                VARCHAR(255)    NOT NULL,
    amount_invested     NUMERIC(14, 2)  NOT NULL,
    current_value       NUMERIC(14, 2),
    purchase_date       DATE            NOT NULL,
    notes               TEXT,
    platform_account_id INTEGER         REFERENCES platform_accounts(id) ON DELETE SET NULL,
    instrument_id       INTEGER         REFERENCES instruments(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ,

    -- Stock / ETF
    ticker_symbol   VARCHAR(20),
    quantity        NUMERIC(12, 4),
    avg_buy_price   NUMERIC(12, 2),
    exchange        VARCHAR(20),            -- NSE / BSE / NASDAQ

    -- Mutual Fund
    folio_number    VARCHAR(50),
    units           NUMERIC(12, 4),
    nav_at_purchase NUMERIC(12, 4),
    fund_house      VARCHAR(100),

    -- Fixed Deposit
    bank_name       VARCHAR(100),
    fd_number       VARCHAR(50),
    interest_rate   NUMERIC(5, 2),          -- annual %
    tenure_months   INTEGER,
    maturity_date   DATE,
    maturity_amount NUMERIC(14, 2),
    compounding     VARCHAR(20),            -- monthly / quarterly / yearly

    -- Gold
    gold_form       VARCHAR(30),            -- physical / sgb / etf / digital
    weight_grams    NUMERIC(10, 3),
    purity          VARCHAR(10)             -- 24K / 22K / 999
);

CREATE INDEX ix_investments_user_id ON investments (user_id);
CREATE INDEX ix_investments_type    ON investments (type);
```

**Why single-table over joined-table inheritance**: At personal-finance scale (hundreds to low thousands of rows), the simplicity of one table outweighs the nullable column overhead. All reporting queries (SUM, GROUP BY) stay on a single table with no JOINs.

#### Entity Relationship

```
users 1──────────────────────* transactions
  │                               (user_id FK)
  │                               account_id FK ──────────────┐
  │                               instrument_id FK ──────────┐│
  │                                                           ││
  ├──────────────────────────* investments                    ││
  │                               (user_id FK)               ││
  │                               platform_account_id FK ──┐ ││
  │                               instrument_id FK ────────│─┘│
  │                                                        │   │
  ├──────────────────────────* accounts ───────────────────│───┘
  │                               (user_id FK)             │
  │                               bank_id FK → banks       │
  │                                                        │
  ├──────────────────────────* platform_accounts ──────────┘
  │                               (user_id FK)
  │                               platform_id FK → platforms
  │
  └──────────────────────────* user_instruments (M2M)
                                  (user_id FK)
                                  instrument_id FK → instruments

banks        (global, admin-managed)
platforms    (global, admin-managed)
instruments  (global catalogue)
```

### 2.3 API Contract

All routes prefixed with `/api/v1`. Protected routes require `Authorization: Bearer <jwt>`.

---

#### Auth — `/api/v1/auth`

**POST `/register`** — public

Request:
```json
{
  "email": "user@example.com",
  "full_name": "Jane Doe",
  "password": "minlength8"
}
```
Response `201`:
```json
{
  "id": 1,
  "email": "user@example.com",
  "full_name": "Jane Doe",
  "is_active": true,
  "created_at": "2026-04-28T10:00:00Z"
}
```
Errors: `422` validation, `409` email already registered.

---

**POST `/login`** — public

Request:
```json
{ "email": "user@example.com", "password": "minlength8" }
```
Response `200`:
```json
{ "access_token": "<jwt>", "token_type": "bearer" }
```
Errors: `401` invalid credentials.

---

**GET `/me`** — protected

Response `200`:
```json
{
  "id": 1,
  "email": "user@example.com",
  "full_name": "Jane Doe",
  "is_active": true,
  "created_at": "2026-04-28T10:00:00Z"
}
```

---

**PUT `/me`** — protected

Request (all fields optional):
```json
{ "full_name": "Jane Smith", "password": "newpassword" }
```
Response `200`: Updated `UserRead`.

---

#### Transactions — `/api/v1/transactions`

**GET `/`** — protected

Query params:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | int | 1 | Page number |
| `page_size` | int | 20 | Max 100 |
| `type` | enum | — | `inbound` or `outbound` |
| `start_date` | date | — | ISO 8601 `YYYY-MM-DD` |
| `end_date` | date | — | ISO 8601 `YYYY-MM-DD` |
| `sort_by` | str | `date` | `date`, `amount`, `created_at` |
| `order` | str | `desc` | `asc` or `desc` |

Note: `category` filter has been removed (category column no longer exists).

Response `200`:
```json
{
  "items": [
    {
      "id": 1,
      "user_id": 1,
      "amount": "1500.00",
      "type": "outbound",
      "description": "Groceries",
      "date": "2026-04-01",
      "notes": null,
      "account_id": 2,
      "instrument_id": null,
      "created_at": "2026-04-01T08:00:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "page_size": 20
}
```

---

**POST `/`** — protected

Request:
```json
{
  "amount": "1500.00",
  "type": "outbound",
  "description": "Groceries",
  "date": "2026-04-01",
  "notes": null,
  "account_id": 2,
  "instrument_id": null
}
```
Response `201`: `TransactionRead`.
Errors: `422` validation.

---

**GET `/{id}`** — protected
Response `200`: `TransactionRead`. Errors: `404` not found, `403` not owner.

**PUT `/{id}`** — protected
Request: any subset of `TransactionCreate` fields.
Response `200`: Updated `TransactionRead`.

**DELETE `/{id}`** — protected
Response `204` no content.

---

#### Investments — `/api/v1/investments`

**GET `/`** — protected

Query params:
| Param | Type | Description |
|-------|------|-------------|
| `type` | enum (multi) | Filter by investment type(s); repeat param for multiple |
| `page` | int | Default 1 |
| `page_size` | int | Default 20, max 100 |

Response `200`:
```json
{
  "items": [ { ...InvestmentRead } ],
  "total": 5,
  "page": 1,
  "page_size": 20
}
```

---

**POST `/`** — protected

The request body is a **discriminated union** on the `type` field. Only relevant fields need to be provided per type:

Stock example:
```json
{
  "type": "stock",
  "name": "Reliance Industries",
  "amount_invested": "50000.00",
  "purchase_date": "2025-01-15",
  "ticker_symbol": "RELIANCE",
  "quantity": "10.0000",
  "avg_buy_price": "5000.00",
  "exchange": "NSE"
}
```

Fixed Deposit example:
```json
{
  "type": "fixed_deposit",
  "name": "SBI 1-Year FD",
  "amount_invested": "100000.00",
  "purchase_date": "2025-06-01",
  "bank_name": "State Bank of India",
  "interest_rate": "6.75",
  "tenure_months": 12,
  "maturity_date": "2026-06-01",
  "maturity_amount": "106750.00",
  "compounding": "quarterly"
}
```

Gold example:
```json
{
  "type": "gold",
  "name": "Sovereign Gold Bond 2025",
  "amount_invested": "75000.00",
  "purchase_date": "2025-03-10",
  "gold_form": "sgb",
  "weight_grams": "10.000",
  "purity": "999"
}
```

Mutual Fund example:
```json
{
  "type": "mutual_fund",
  "name": "HDFC Nifty 50 Index Fund",
  "amount_invested": "25000.00",
  "purchase_date": "2025-02-01",
  "folio_number": "1234567890",
  "units": "892.8571",
  "nav_at_purchase": "28.00",
  "fund_house": "HDFC AMC"
}
```

Generic (crypto, ppf, nps, real_estate):
```json
{
  "type": "ppf",
  "name": "PPF Account - SBI",
  "amount_invested": "150000.00",
  "purchase_date": "2020-04-01",
  "notes": "Annual contribution for FY 2025-26"
}
```

Response `201`: `InvestmentRead` (all fields returned; unused type-specific fields are `null`).

---

**GET `/{id}`** — protected — Response `200`: `InvestmentRead`.
**PUT `/{id}`** — protected — Partial update; commonly used to update `current_value`.
**DELETE `/{id}`** — protected — Response `204`.

---

#### Reports — `/api/v1/reports`

**GET `/dashboard`** — protected

Response `200`:
```json
{
  "total_inbound": "250000.00",
  "total_outbound": "85000.00",
  "net_balance": "165000.00",
  "total_invested": "400000.00",
  "current_portfolio_value": "432000.00",
  "investment_gain_loss": "32000.00"
}
```
Computes totals for the current calendar year by default. Fields renamed from `total_income`/`total_expense` → `total_inbound`/`total_outbound`.

---

**GET `/spending-trends`** — protected

Query: `?months=6` (default 6, max 24)

Response `200`:
```json
{
  "period_start": "2025-11-01",
  "period_end": "2026-04-30",
  "monthly_trends": [
    { "month": "2025-11", "inbound": "50000.00", "outbound": "18000.00", "net": "32000.00" },
    { "month": "2025-12", "inbound": "50000.00", "outbound": "22000.00", "net": "28000.00" }
  ]
}
```
`MonthlyTrend` fields renamed from `income`/`expense` → `inbound`/`outbound`; `net` field added.

---

~~**GET `/category-breakdown`**~~ — **removed**. The `category` column no longer exists on transactions; this endpoint has been deleted.

---

**GET `/investment-summary`** — protected

Response `200`:
```json
{
  "total_invested": "400000.00",
  "total_current_value": "432000.00",
  "total_gain_loss": "32000.00",
  "total_gain_loss_pct": 8.0,
  "by_type": [
    {
      "type": "stock",
      "amount_invested": "150000.00",
      "current_value": "172000.00",
      "gain_loss": "22000.00",
      "count": 4
    }
  ]
}
```

---

#### Banks — `/api/v1/banks`

**GET `/`** — protected — list all banks (read-only from API; managed via CLI).

Response `200`: `{ "items": [ { "id": 1, "name": "HDFC Bank", "short_name": "HDFC", "is_system": true } ], "total": 10 }`

---

#### Accounts — `/api/v1/accounts`

**GET `/`** — protected — list current user's bank accounts.
**POST `/`** — protected — create a bank account.

Request:
```json
{ "bank_id": 1, "nickname": "HDFC Salary", "account_number": "XXXX1234", "account_type": "salary" }
```
Response `201`: `AccountRead`.

**GET `/{id}`** — protected — Response `200`: `AccountRead`.
**PUT `/{id}`** — protected — partial update; Response `200`: `AccountRead`.
**DELETE `/{id}`** — protected — Response `204`.

---

#### Platforms — `/api/v1/platforms`

**GET `/`** — protected — list all platforms (read-only from API; managed via CLI).

Response `200`: `{ "items": [ { "id": 1, "name": "Zerodha", "short_name": "ZERODHA", "type": "broker", "is_system": true } ], "total": 11 }`

---

#### Platform Accounts — `/api/v1/platform-accounts`

**GET `/`** — protected — list current user's platform accounts.
**POST `/`** — protected — create a platform account.

Request:
```json
{ "platform_id": 1, "nickname": "Zerodha Main", "account_id": "AB1234" }
```
Response `201`: `PlatformAccountRead`.

**GET `/{id}`** — protected — Response `200`: `PlatformAccountRead`.
**PUT `/{id}`** — protected — partial update; Response `200`: `PlatformAccountRead`.
**DELETE `/{id}`** — protected — Response `204`.

---

#### Instruments — `/api/v1/instruments`

**GET `/`** — protected — list all instruments.

Query params:
| Param | Type | Description |
|-------|------|-------------|
| `type` | investment_type enum | Filter by instrument type |
| `search` | str | Full-text search on name / ticker / ISIN |

Response `200`: paginated list of `InstrumentRead`.

**POST `/`** — protected — create an instrument.

Request:
```json
{ "name": "Reliance Industries", "type": "stock", "ticker_symbol": "RELIANCE", "isin": "INE002A01018", "exchange": "NSE" }
```
Response `201`: `InstrumentRead`.

**GET `/tracked`** — protected — list instruments tracked by the current user.
**GET `/{id}`** — protected — Response `200`: `InstrumentRead`.
**PUT `/{id}`** — protected — partial update; Response `200`: `InstrumentRead`.
**POST `/{id}/track`** — protected — add instrument to current user's watchlist; Response `200`.
**DELETE `/{id}/track`** — protected — remove instrument from watchlist; Response `204`.

---

### 2.4 Authentication Flow

#### Registration

```
Client                           FastAPI                        DB
  │                                │                             │
  ├─POST /auth/register ──────────►│                             │
  │  {email, full_name, password}  │                             │
  │                                ├─SELECT users WHERE email──►│
  │                                │◄── [] (not found) ──────────┤
  │                                │                             │
  │                                │ hash_password(password)     │
  │                                │ bcrypt, cost factor 12      │
  │                                │                             │
  │                                ├─INSERT INTO users ─────────►│
  │                                │◄── User(id=1) ──────────────┤
  │                                │                             │
  │◄── 201 UserRead ───────────────┤                             │
```

#### Login + Subsequent Requests

```
Client                           FastAPI                        DB
  │                                │                             │
  ├─POST /auth/login ─────────────►│                             │
  │  {email, password}             │                             │
  │                                ├─SELECT users WHERE email──►│
  │                                │◄── User record ─────────────┤
  │                                │                             │
  │                                │ verify_password()           │
  │                                │ (bcrypt comparison)         │
  │                                │                             │
  │                                │ create_access_token(        │
  │                                │   {"sub": user.id},         │
  │                                │   expires=7 days            │
  │                                │ )                           │
  │                                │                             │
  │◄── 200 {access_token, ...} ────┤                             │
  │                                │                             │
  │ (stores token in localStorage) │                             │
  │                                │                             │
  ├─GET /transactions ────────────►│                             │
  │  Authorization: Bearer <jwt>   │                             │
  │                                │ decode_access_token(jwt)    │
  │                                │ → {sub: 1, exp: ...}        │
  │                                │                             │
  │                                ├─SELECT users WHERE id=1 ───►│
  │                                │◄── User(id=1, active=T) ────┤
  │                                │                             │
  │                                │ [proceeds to handler]       │
  │                                │                             │
  │◄── 200 TransactionList ────────┤                             │
```

#### JWT Structure

```
Header:  { "alg": "HS256", "typ": "JWT" }
Payload: { "sub": "<user_id>", "exp": <unix_timestamp> }
Secret:  SECRET_KEY from .env (32-byte random hex)
Expiry:  10080 minutes (7 days)
```

Token is never stored server-side. Logout is purely client-side (clear localStorage).

### 2.5 Layer Responsibilities

#### `routers/` — HTTP Layer

```python
# routers/transactions.py
router = APIRouter()

@router.get("/", response_model=TransactionListResponse)
def list_transactions(
    filters: TransactionFilters = Depends(),  # query params as dataclass
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return transaction_service.list_transactions(db, current_user.id, filters)
```

Routers only: parse HTTP params, call one service function, return the result. No DB calls, no business logic.

#### `services/` — Business Layer

```python
# services/transaction_service.py
def list_transactions(
    db: Session,
    user_id: int,
    filters: TransactionFilters,
) -> TransactionListResponse:
    query = db.query(Transaction).filter(Transaction.user_id == user_id)

    if filters.type:
        query = query.filter(Transaction.type == filters.type)
    if filters.category:
        query = query.filter(Transaction.category == filters.category)
    if filters.start_date:
        query = query.filter(Transaction.date >= filters.start_date)
    if filters.end_date:
        query = query.filter(Transaction.date <= filters.end_date)

    total = query.count()
    items = (
        query
        .order_by(get_sort_column(filters.sort_by, filters.order))
        .offset((filters.page - 1) * filters.page_size)
        .limit(filters.page_size)
        .all()
    )
    return TransactionListResponse(items=items, total=total, **filters.page_info())
```

Services: own query logic, enforce ownership (`user_id` filter is always applied), raise `HTTPException` for business rule violations.

#### `dependencies.py` — Shared Deps

```python
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    payload = auth_service.decode_access_token(token)   # raises 401 if invalid
    user = db.get(User, payload.user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user
```

### 2.6 Service Layer Design

#### `auth_service.py`

```python
# Key functions
def hash_password(password: str) -> str
def verify_password(plain: str, hashed: str) -> bool
def create_access_token(data: dict) -> str        # adds exp, signs with SECRET_KEY
def decode_access_token(token: str) -> TokenData  # raises HTTP 401 on failure

def register_user(db: Session, data: UserCreate) -> User
def authenticate_user(db: Session, email: str, password: str) -> User  # raises 401
def update_user(db: Session, user: User, data: UserUpdate) -> User
```

#### `transaction_service.py`

```python
def list_transactions(db, user_id, filters) -> TransactionListResponse
    # filters.type accepts 'inbound'/'outbound'; category filter removed
def get_transaction(db, user_id, transaction_id) -> Transaction   # raises 404/403
def create_transaction(db, user_id, data: TransactionCreate) -> Transaction
def update_transaction(db, user_id, transaction_id, data: TransactionUpdate) -> Transaction
def delete_transaction(db, user_id, transaction_id) -> None
```

All functions enforce `user_id` ownership. `get_transaction` raises `404` if not found, `403` if found but owned by another user.

#### `investment_service.py`

```python
def list_investments(db, user_id, type_filter: list[InvestmentType] | None, page_params) -> InvestmentListResponse
def get_investment(db, user_id, investment_id) -> Investment
def create_investment(db, user_id, data: InvestmentCreate) -> Investment
    # data is a discriminated union; service maps all fields from the subtype schema
    # onto the flat Investment model columns
def update_investment(db, user_id, investment_id, data: InvestmentUpdate) -> Investment
def delete_investment(db, user_id, investment_id) -> None
```

Creating an investment: the discriminated union schema is fully validated by Pydantic before reaching the service. The service then builds the `Investment` ORM object, setting only the columns relevant to that type (others remain `None`).

#### `report_service.py`

```python
def get_dashboard_summary(db, user_id) -> DashboardSummary
    # returns total_inbound/total_outbound (formerly total_income/total_expense)
def get_spending_trends(db, user_id, months: int) -> SpendingTrendsResponse
    # MonthlyTrend now has inbound/outbound/net fields
def get_investment_summary(db, user_id) -> InvestmentSummaryResponse
    # get_category_breakdown removed — category column gone
```

All report functions use SQLAlchemy `func.sum()`, `func.date_trunc()`, and `group_by()` to aggregate in the database — no Python-side aggregation.

#### `bank_service.py`

```python
def list_banks(db) -> list[Bank]
def get_bank(db, bank_id) -> Bank                                          # raises 404
def create_bank(db, data: BankCreate) -> Bank
def list_accounts(db, user_id) -> list[Account]
def get_account(db, user_id, account_id) -> Account                       # raises 404/403
def create_account(db, user_id, data: AccountCreate) -> Account
def update_account(db, user_id, account_id, data: AccountUpdate) -> Account
def delete_account(db, user_id, account_id) -> None
```

#### `platform_service.py`

```python
def list_platforms(db) -> list[Platform]
def get_platform(db, platform_id) -> Platform                              # raises 404
def create_platform(db, data: PlatformCreate) -> Platform
def list_platform_accounts(db, user_id) -> list[PlatformAccount]
def get_platform_account(db, user_id, pa_id) -> PlatformAccount           # raises 404/403
def create_platform_account(db, user_id, data: PlatformAccountCreate) -> PlatformAccount
def update_platform_account(db, user_id, pa_id, data: PlatformAccountUpdate) -> PlatformAccount
def delete_platform_account(db, user_id, pa_id) -> None
```

#### `instrument_service.py`

```python
def list_instruments(db, type_filter: InvestmentType | None, search: str | None) -> list[Instrument]
def get_instrument(db, instrument_id) -> Instrument                        # raises 404
def create_instrument(db, data: InstrumentCreate) -> Instrument
def update_instrument(db, instrument_id, data: InstrumentUpdate) -> Instrument
def track_instrument(db, user_id, instrument_id) -> None
def untrack_instrument(db, user_id, instrument_id) -> None
def list_tracked_instruments(db, user_id) -> list[Instrument]
```

### 2.7 Report Queries

#### Dashboard Summary

```python
# Income and expense totals (current year)
year_start = date(date.today().year, 1, 1)

income_total = (
    db.query(func.sum(Transaction.amount))
    .filter(
        Transaction.user_id == user_id,
        Transaction.type == TransactionType.income,
        Transaction.date >= year_start,
    )
    .scalar() or Decimal(0)
)

# Investment totals
portfolio = (
    db.query(
        func.sum(Investment.amount_invested).label("total_invested"),
        func.sum(Investment.current_value).label("total_current_value"),
    )
    .filter(Investment.user_id == user_id)
    .one()
)
```

#### Monthly Spending Trends

```python
# Uses date_trunc to group by month
results = (
    db.query(
        func.date_trunc("month", Transaction.date).label("month"),
        Transaction.type,
        func.sum(Transaction.amount).label("total"),
    )
    .filter(
        Transaction.user_id == user_id,
        Transaction.date >= period_start,
        Transaction.date <= period_end,
    )
    .group_by("month", Transaction.type)
    .order_by("month")
    .all()
)
```

#### Category Breakdown

```python
results = (
    db.query(
        Transaction.category,
        func.sum(Transaction.amount).label("total"),
    )
    .filter(
        Transaction.user_id == user_id,
        Transaction.type == TransactionType.expense,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
    )
    .group_by(Transaction.category)
    .order_by(func.sum(Transaction.amount).desc())
    .all()
)

grand_total = sum(r.total for r in results)
breakdown = [
    CategoryBreakdown(
        category=r.category,
        amount=r.total,
        percentage=float(r.total / grand_total * 100) if grand_total else 0.0,
    )
    for r in results
]
```

### 2.8 Pagination

`utils/pagination.py` provides a reusable helper used consistently across all list endpoints:

```python
from dataclasses import dataclass
from fastapi import Query

@dataclass
class PaginationParams:
    page: int = Query(default=1, ge=1)
    page_size: int = Query(default=20, ge=1, le=100)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size

    def page_info(self) -> dict:
        return {"page": self.page, "page_size": self.page_size}
```

Usage in service:
```python
query.offset(pagination.offset).limit(pagination.page_size)
```

### 2.9 Error Handling

#### Standard HTTP errors raised in services

| Situation | Exception |
|-----------|-----------|
| Resource not found | `HTTPException(status_code=404)` |
| Authenticated but not owner | `HTTPException(status_code=403)` |
| Invalid credentials | `HTTPException(status_code=401)` |
| Duplicate email on register | `HTTPException(status_code=409)` |
| Business rule violation | `HTTPException(status_code=422, detail="message")` |

#### Global exception handler in `main.py`

```python
@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # Log the full traceback
    logger.exception("Unhandled error", exc_info=exc)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )
```

SQLAlchemy `IntegrityError` (e.g. duplicate key) is caught in service functions and translated to the appropriate `HTTPException` before reaching this handler.

#### Validation errors

FastAPI automatically returns `422 Unprocessable Entity` with field-level details when Pydantic validation fails on request schemas. No extra handling needed.

### 2.10 Configuration Management

`app/config.py`:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 10080  # 7 days
    environment: str = "development"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

settings = Settings()
```

`backend/.env`:
```
DATABASE_URL=postgresql+psycopg://fintrack_user:password@localhost:5432/fintrack_db
SECRET_KEY=<output of: python3 -c "import secrets; print(secrets.token_hex(32))">
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
ENVIRONMENT=development
```

`settings` is a module-level singleton. Import it anywhere with `from app.config import settings`. Do not instantiate `Settings()` more than once.

### 2.11 Database Migrations

`alembic/env.py` critical section:

```python
# Must import all models so Alembic's autogenerate sees their metadata
from app.models.user import User            # noqa: F401
from app.models.transaction import Transaction  # noqa: F401
from app.models.investment import Investment    # noqa: F401
from app.database import Base
from app.config import settings

config.set_main_option("sqlalchemy.url", settings.database_url)
target_metadata = Base.metadata
```

Workflow for schema changes:
1. Edit the SQLAlchemy model
2. `alembic revision --autogenerate -m "add column X to investments"`
3. Review the generated migration in `alembic/versions/`
4. `alembic upgrade head`

Always review autogenerated migrations before running them — Alembic cannot detect column renames (it sees a drop + add) and will not generate data migrations.

### 2.12 Testing Strategy

`tests/conftest.py` sets up an isolated test database using SQLite in-memory (or a separate PostgreSQL test DB) and an `httpx.AsyncClient` pointed at the ASGI app:

```python
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database import Base
from app.dependencies import get_db

TEST_DATABASE_URL = "sqlite:///./test.db"  # or separate postgres test DB

@pytest.fixture(scope="session")
def engine():
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)

@pytest.fixture
def db(engine):
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.rollback()
    session.close()

@pytest.fixture
async def client(db):
    app.dependency_overrides[get_db] = lambda: db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture
async def auth_client(client):
    """Client with a pre-registered and logged-in user."""
    await client.post("/api/v1/auth/register", json={
        "email": "test@example.com", "full_name": "Test", "password": "password123"
    })
    resp = await client.post("/api/v1/auth/login", json={
        "email": "test@example.com", "password": "password123"
    })
    token = resp.json()["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"
    return client
```

Test example:
```python
# tests/test_transactions.py
@pytest.mark.asyncio
async def test_create_transaction(auth_client):
    resp = await auth_client.post("/api/v1/transactions", json={
        "amount": "500.00",
        "type": "expense",
        "category": "food",
        "date": "2026-04-01",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["amount"] == "500.00"
    assert data["category"] == "food"
```

Tests call the real ASGI app with a real DB session — no mocks. This catches ORM mapping errors, constraint violations, and serialization issues that unit tests with mocks would miss.
