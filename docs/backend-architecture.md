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

FinTrack is a **monolithic** personal finance tracker. A single Rails process is the entire backend — it owns the REST API, business logic, and data access. In production it sits behind Puma and serves JSON only; the compiled React frontend is served as static files from the same origin.

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
│              Rails / Puma Process (port 8000)               │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  /api/v1/*   │  │  /api-docs   │  │  /* (catch-all)  │  │
│  │  REST API    │  │  Swagger UI  │  │  React SPA       │  │
│  │  Controllers │  │  (rswag)     │  │  (prod only)     │  │
│  └──────┬───────┘  └──────────────┘  └──────────────────┘  │
│         │                                                   │
│  ┌──────▼───────┐                                           │
│  │   Services   │  Business logic, aggregations             │
│  └──────┬───────┘                                           │
│         │                                                   │
│  ┌──────▼───────┐                                           │
│  │    Redis     │  Dashboard report cache                   │
│  └──────────────┘                                           │
│         │                                                   │
│  ┌──────▼───────┐                                           │
│  │Active Record │  ORM, query building                      │
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
├── controllers/
│   └── api/v1/          ← One controller per domain (thin HTTP layer)
│       ├── auth_controller.rb
│       ├── banks_controller.rb
│       ├── accounts_controller.rb
│       ├── term_accounts_controller.rb
│       ├── transactions_controller.rb
│       ├── investments_controller.rb
│       ├── instruments_controller.rb
│       ├── platforms_controller.rb
│       ├── platform_accounts_controller.rb
│       ├── reports_controller.rb
│       ├── follios_controller.rb
│       └── client_errors_controller.rb
│
├── models/              ← ActiveRecord ORM models
│   ├── user.rb
│   ├── bank.rb
│   ├── account.rb
│   ├── term_account.rb
│   ├── transaction.rb
│   ├── investment.rb
│   ├── instrument.rb
│   ├── user_instrument.rb
│   ├── platform.rb
│   ├── platform_account.rb
│   └── follio.rb
│
├── services/            ← Business logic; controllers delegate here
│   ├── transactions/
│   │   ├── query_service.rb
│   │   └── create_service.rb
│   ├── investments/
│   │   └── query_service.rb
│   └── ...              ← other domain service modules
│
└── serializers/         ← JSON serialization (BaseSerializer + per-model)
    ├── base_serializer.rb
    ├── investment_serializer.rb
    └── ...
```

**Data flow**: HTTP Request → `Authenticatable` concern (JWT decode) → Controller (params, delegation) → Service (business logic + AR queries) → Serializer (JSON shape) → `Responder` concern (envelope) → HTTP Response.

Controllers are intentionally thin. They handle HTTP concerns (status codes, permitted params) and delegate everything else to services. Services are plain Ruby objects — no Rails controller coupling — making them independently testable.

### 1.3 Request Lifecycle

**Authenticated API call (e.g. GET /api/v1/transactions)**

```
Browser
  │
  ├─► Rack middleware stack
  │     └─ rack-cors (dev: allows localhost:5173)
  │
  ├─► Router: GET /api/v1/transactions
  │     └─ routes to Api::V1::TransactionsController#index
  │
  ├─► ApplicationController before_action :authenticate_user!
  │     ├─ extracts Bearer token from Authorization header
  │     ├─ JWT.decode(token, secret, "HS256")
  │     └─ loads @current_user from users table
  │
  ├─► TransactionsController#index
  │     ├─ builds filter params hash
  │     └─ delegates to Transactions::QueryService.call(user, filters)
  │
  ├─► Transactions::QueryService
  │     ├─ scopes to current_user's transactions
  │     ├─ applies filters (type, date range, tags)
  │     ├─ applies cursor-based pagination
  │     └─ returns { records:, next_cursor: }
  │
  ├─► Controller calls render_success(data, meta_data: {...})
  │     └─ Responder concern wraps into standard envelope
  │
  └─► HTTP 200 JSON response
```

**Error path**: `render_error` in the `Responder` concern formats the error envelope. `rescue_from` blocks in `ApplicationController` catch `ActiveRecord::RecordNotFound`, `JWT::DecodeError`, and other standard exceptions before they propagate.

### 1.4 Deployment Architecture

#### Development

```
Terminal 1                          Terminal 2
──────────────────────────────────  ──────────────────────────────────
bundle exec rails server -p 8000   npm run dev
                                    (Vite, port 5173)

                                    vite.config.ts proxy:
Rails serves /api/v1/* only           /api → http://localhost:8000
(no static files in dev)
```

Both processes are also managed together via `Procfile.dev` + foreman (`make dev`).

#### Production

```
Single process, single port
──────────────────────────────────────────────────────────
bundle exec rails server -p 8000 -e production

Rails / Puma serves:
  /api/v1/*          → REST API controllers
  /api-docs          → Rswag Swagger UI
  /* (catch-all)     → React SPA static files
                       (enables React Router client-side routing)
```

`frontend/dist/` is produced by `npm run build` before starting the server.

### 1.5 Tech Stack Rationale

| Component | Choice | Why |
|-----------|--------|-----|
| Web framework | Rails 8.1.3 | Convention over configuration; batteries-included routing, ORM, migrations |
| ORM | Active Record | Native Rails integration; callbacks for balance hooks; audited gem support |
| DB driver | `pg` gem | Official PostgreSQL adapter; native array/UUID type support |
| Migrations | Rails migrations | Schema versioning baked in; `schema.rb` as canonical truth |
| Auth tokens | `jwt` gem (HS256) | Stateless; no session storage needed for personal-app scale |
| Password hash | `bcrypt` via `has_secure_password` | Industry standard; built into Rails |
| Pagination | `kaminari` (page-based) + custom cursor (transactions/instruments) | Page-based for investments; cursor for high-frequency transaction feeds |
| Audit log | `audited` gem | Automatic change tracking on `balance` columns without hand-rolled triggers |
| Dashboard cache | Redis | Avoids re-running expensive aggregation queries on every page load |
| API docs | `rswag` (Swagger UI at `/api-docs`) | Spec-first docs generated from RSpec request specs |
| CORS | `rack-cors` | Standard Rack middleware; minimal config |

---

## 2. Low-Level Design

### 2.1 Directory Structure

```
backend/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb        ← includes Authenticatable, Responder
│   │   └── api/v1/
│   │       ├── auth_controller.rb
│   │       ├── banks_controller.rb
│   │       ├── accounts_controller.rb
│   │       ├── term_accounts_controller.rb
│   │       ├── transactions_controller.rb
│   │       ├── investments_controller.rb
│   │       ├── instruments_controller.rb
│   │       ├── platforms_controller.rb
│   │       ├── platform_accounts_controller.rb
│   │       ├── reports_controller.rb
│   │       ├── follios_controller.rb
│   │       └── client_errors_controller.rb
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── user.rb
│   │   ├── bank.rb
│   │   ├── account.rb              ← audited only: [:balance]; debit!/credit! guards
│   │   ├── term_account.rb         ← audited only: [:balance]; before_validation :apply_defaults
│   │   ├── transaction.rb          ← after_create :apply_balance_delta
│   │   ├── investment.rb
│   │   ├── instrument.rb
│   │   ├── user_instrument.rb
│   │   ├── platform.rb
│   │   ├── platform_account.rb
│   │   └── follio.rb
│   ├── services/
│   │   ├── transactions/
│   │   │   ├── query_service.rb
│   │   │   └── create_service.rb
│   │   └── investments/
│   │       └── query_service.rb
│   └── serializers/
│       ├── base_serializer.rb
│       └── investment_serializer.rb
├── config/
│   ├── routes.rb
│   └── ...
├── db/
│   ├── schema.rb                   ← canonical schema (auto-generated)
│   └── migrate/                    ← timestamped migration files
└── spec/
    ├── rails_helper.rb             ← RSpec + FactoryBot + DatabaseCleaner setup
    ├── spec_helper.rb
    ├── factories/                  ← factory_bot_rails factory definitions
    ├── requests/                   ← RSpec request specs (used by rswag for docs)
    │   ├── auth_spec.rb
    │   ├── transactions_spec.rb
    │   ├── investments_spec.rb
    │   └── ...
    └── models/                     ← unit specs for model validations and callbacks
```

### 2.2 Database Schema

Schema version: `2026_05_05_172129`. Managed by Active Record migrations; `db/schema.rb` is the authoritative source. Extensions: `plpgsql`, `pgcrypto` (for `gen_random_uuid()`).

#### `users` table

```sql
CREATE TABLE users (
    id               BIGSERIAL    PRIMARY KEY,
    email            VARCHAR      NOT NULL UNIQUE,
    first_name       VARCHAR      NOT NULL,
    last_name        VARCHAR      NOT NULL,
    -- full_name is a computed getter on the model, not a DB column
    password_digest  VARCHAR      NOT NULL,          -- bcrypt via has_secure_password
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    is_superuser     BOOLEAN      NOT NULL DEFAULT FALSE,
    currency_code    VARCHAR      NOT NULL DEFAULT 'INR',
    currency_locale  VARCHAR      NOT NULL DEFAULT 'en-IN',
    created_at       TIMESTAMPTZ  NOT NULL,
    updated_at       TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX index_users_on_email ON users (email);
```

No public registration endpoint. Users are created via `rails console` or admin scripts.

#### `banks` table

```sql
CREATE TABLE banks (
    id          BIGSERIAL    PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    short_name  VARCHAR(6)   NOT NULL UNIQUE,   -- max 6 chars, display code
    is_system   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL,
    updated_at  TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX index_banks_on_short_name ON banks (short_name);
```

Admin-managed via `rails console` or seed scripts. Read-only from the API.

#### `accounts` table

```sql
CREATE TABLE accounts (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_id         BIGINT           NOT NULL REFERENCES banks(id) ON DELETE RESTRICT,
    nickname        VARCHAR(100)     NOT NULL,
    account_number  VARCHAR(50),
    account_type    VARCHAR          NOT NULL DEFAULT 'savings',
                    -- enum: savings / current / salary / nre / nro
    balance         DECIMAL(14,2)    NOT NULL DEFAULT 0.0,
    open_date       DATE,
    closed_date     DATE,
    closed_amount   DECIMAL(14,2),
    created_at      TIMESTAMPTZ      NOT NULL,
    updated_at      TIMESTAMPTZ      NOT NULL
);

CREATE INDEX index_accounts_on_user_id ON accounts (user_id);
CREATE INDEX index_accounts_on_bank_id ON accounts (bank_id);
```

`balance` is audited by the `audited` gem (writes to `audits` table on every change).
The model exposes `debit!(amount)` and `credit!(amount)` methods with guard rails to prevent invalid balance operations.

#### `term_accounts` table

```sql
CREATE TABLE term_accounts (
    id                BIGSERIAL      PRIMARY KEY,
    user_id           BIGINT         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_account_id BIGINT         NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    account_type      VARCHAR        NOT NULL,   -- enum: fd / ppf
    account_number    VARCHAR(100),
    amount            DECIMAL(14,2)  NOT NULL,   -- principal
    balance           DECIMAL(14,2)  NOT NULL DEFAULT 0.0,
    interest_rate     DECIMAL(5,2)   NOT NULL,
    tenure_days       INTEGER,                   -- FD only
    open_date         DATE           NOT NULL,
    maturity_date     DATE           NOT NULL,   -- auto-calculated on create
    maturity_amount   DECIMAL(14,2)  NOT NULL,   -- auto-calculated on create
    notes             TEXT,
    is_active         BOOLEAN        NOT NULL DEFAULT TRUE,
    closed_date       DATE,
    closed_amount     DECIMAL(14,2),
    created_at        TIMESTAMPTZ    NOT NULL,
    updated_at        TIMESTAMPTZ    NOT NULL
);

CREATE INDEX index_term_accounts_on_user_id         ON term_accounts (user_id);
CREATE INDEX index_term_accounts_on_parent_account_id ON term_accounts (parent_account_id);
```

`before_validation :apply_defaults` auto-calculates `maturity_date` and `maturity_amount`:
- **FD**: `maturity_amount = amount * (1 + rate/400)^(tenure_days / 91.25)` (compound quarterly); `maturity_date = open_date + tenure_days`
- **PPF**: `maturity_date = open_date + 15 years`; `maturity_amount` is user-provided

`balance` is audited. Routes include `GET /{id}/audit-logs`.

#### `transactions` table

```sql
CREATE TABLE transactions (
    id                  BIGSERIAL      PRIMARY KEY,
    user_id             BIGINT         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_id           UUID           UNIQUE DEFAULT gen_random_uuid(),
    transaction_type    VARCHAR        NOT NULL,   -- enum: credit / debit
    amount              DECIMAL(12,2)  NOT NULL,
    description         VARCHAR(500),
    date                DATE           NOT NULL,
    linked_account_type VARCHAR,                   -- 'Account' or 'TermAccount'
    linked_account_id   INTEGER,                   -- polymorphic FK (no DB constraint)
    instrument_id       BIGINT         REFERENCES instruments(id) ON DELETE SET NULL,
    tags                VARCHAR[]      ,            -- PostgreSQL text array; nullable
    bank_ref            VARCHAR(100),              -- UTR/IMPS ref for credits
    is_active           BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ    NOT NULL,
    updated_at          TIMESTAMPTZ    NOT NULL
);

CREATE UNIQUE INDEX index_transactions_on_public_id      ON transactions (public_id);
CREATE INDEX        index_transactions_on_user_id        ON transactions (user_id);
CREATE INDEX        index_transactions_on_date_and_id    ON transactions (date, id);
CREATE INDEX        index_transactions_on_linked_account_id   ON transactions (linked_account_id);
CREATE INDEX        index_transactions_on_linked_account_type ON transactions (linked_account_type);
CREATE INDEX        index_transactions_on_instrument_id  ON transactions (instrument_id);
```

Key design decisions:
- **Immutable from the API**: no PUT or DELETE endpoints. Use Rails console / admin scripts for corrections.
- **Polymorphic linked account** (`linked_account_type` + `linked_account_id`): no DB-level FK; resolved in service layer. Type string is the AR class name (`'Account'` or `'TermAccount'`).
- **`after_create :apply_balance_delta`**: auto-updates the linked account balance. `credit` → `+amount`, `debit` → `−amount`. FD term accounts are skipped (FD balance tracks principal, not running deposits).
- **`public_id`**: UUID used as the stable external identifier for cross-referencing with investments (`investments.transaction_public_id`).
- **Cursor pagination** on `(date, id)` composite index — see [2.8 Pagination](#28-pagination).

#### `platforms` table

```sql
CREATE TABLE platforms (
    id            BIGSERIAL    PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    short_name    VARCHAR(20)  NOT NULL UNIQUE,
    platform_type VARCHAR      NOT NULL,   -- enum: broker / mf_platform / direct / other
    is_system     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_at    TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX index_platforms_on_short_name ON platforms (short_name);
```

Admin-managed. Read-only from the API.

#### `platform_accounts` table

```sql
CREATE TABLE platform_accounts (
    id           BIGSERIAL    PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform_id  BIGINT       NOT NULL REFERENCES platforms(id) ON DELETE RESTRICT,
    nickname     VARCHAR(100) NOT NULL,
    account_id   VARCHAR(50),
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL
);

CREATE INDEX index_platform_accounts_on_user_id    ON platform_accounts (user_id);
CREATE INDEX index_platform_accounts_on_platform_id ON platform_accounts (platform_id);
```

#### `instruments` table

```sql
CREATE TABLE instruments (
    id              BIGSERIAL    PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    investment_type VARCHAR      NOT NULL,   -- enum: stock / mutual_fund
    ticker_symbol   VARCHAR(20),
    isin            VARCHAR(20),
    exchange        VARCHAR(20),
    fund_house      VARCHAR(100),
    created_at      TIMESTAMPTZ  NOT NULL,
    updated_at      TIMESTAMPTZ  NOT NULL
);

CREATE INDEX index_instruments_on_investment_type ON instruments (investment_type);
CREATE INDEX index_instruments_on_name            ON instruments (name);
```

Global catalogue of investable securities. Shared across all users.

#### `user_instruments` table

```sql
CREATE TABLE user_instruments (
    id             BIGSERIAL   PRIMARY KEY,
    user_id        BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    instrument_id  BIGINT      NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    added_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX index_user_instruments_on_user_id_and_instrument_id
    ON user_instruments (user_id, instrument_id);
CREATE INDEX index_user_instruments_on_user_id       ON user_instruments (user_id);
CREATE INDEX index_user_instruments_on_instrument_id ON user_instruments (instrument_id);
```

Many-to-many join: tracks which instruments a user watches or holds. Used as the target of `follios.user_instrument_id` and `investments.user_instrument_id`.

#### `investments` table

```sql
CREATE TABLE investments (
    id                   BIGSERIAL      PRIMARY KEY,
    user_id              BIGINT         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_instrument_id   BIGINT         REFERENCES user_instruments(id) ON DELETE SET NULL,
    platform_account_id  BIGINT         REFERENCES platform_accounts(id) ON DELETE SET NULL,
    investment_type      VARCHAR        NOT NULL,   -- enum: stock / mutual_fund
    name                 VARCHAR(255)   NOT NULL,
    amount_invested      DECIMAL(14,2)  NOT NULL,
    current_value        DECIMAL(14,2),
    quantity             DECIMAL(12,4),
    buy_price            DECIMAL(12,2),
    units                DECIMAL(12,4),
    nav_at_purchase      DECIMAL(12,4),
    folio_number         VARCHAR(50),
    purchase_date        DATE           NOT NULL,
    notes                TEXT,
    transaction_public_id UUID,                     -- links back to a transaction
    created_at           TIMESTAMPTZ    NOT NULL,
    updated_at           TIMESTAMPTZ    NOT NULL
);

CREATE INDEX index_investments_on_user_id             ON investments (user_id);
CREATE INDEX index_investments_on_investment_type     ON investments (investment_type);
CREATE INDEX index_investments_on_platform_account_id ON investments (platform_account_id);
CREATE INDEX index_investments_on_user_instrument_id  ON investments (user_instrument_id);
CREATE INDEX index_investments_on_transaction_public_id ON investments (transaction_public_id);
```

`investment_type` is currently `stock` or `mutual_fund`. `transaction_public_id` optionally cross-references the originating transaction record via its stable UUID.

#### `follios` table

```sql
CREATE TABLE follios (
    id                   BIGSERIAL    PRIMARY KEY,
    user_id              BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_instrument_id   BIGINT       NOT NULL REFERENCES user_instruments(id) ON DELETE CASCADE,
    platform_account_id  BIGINT       NOT NULL REFERENCES platform_accounts(id) ON DELETE CASCADE,
    folio_number         VARCHAR(50)  NOT NULL,
    notes                TEXT,
    created_at           TIMESTAMPTZ  NOT NULL,
    updated_at           TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX uq_follio_user_instrument_account
    ON follios (user_instrument_id, platform_account_id);
CREATE INDEX index_follios_on_user_id             ON follios (user_id);
CREATE INDEX index_follios_on_user_instrument_id  ON follios (user_instrument_id);
CREATE INDEX index_follios_on_platform_account_id ON follios (platform_account_id);
```

Links a `user_instrument` to a `platform_account` with a folio number (mutual fund use case). Unique on `(user_instrument_id, platform_account_id)`.

#### `audits` table (from `audited` gem)

```sql
CREATE TABLE audits (
    id               BIGSERIAL    PRIMARY KEY,
    auditable_type   VARCHAR,
    auditable_id     INTEGER,
    associated_type  VARCHAR,
    associated_id    INTEGER,
    user_id          INTEGER,
    user_type        VARCHAR,
    username         VARCHAR,
    action           VARCHAR,
    audited_changes  TEXT,        -- YAML-serialized before/after values
    version          INTEGER      DEFAULT 0,
    comment          VARCHAR,
    remote_address   VARCHAR,
    request_uuid     VARCHAR,
    created_at       TIMESTAMPTZ
);

CREATE INDEX auditable_index ON audits (auditable_type, auditable_id, version);
CREATE INDEX associated_index ON audits (associated_type, associated_id);
CREATE INDEX user_index ON audits (user_id, user_type);
CREATE INDEX index_audits_on_created_at ON audits (created_at);
CREATE INDEX index_audits_on_request_uuid ON audits (request_uuid);
```

Populated automatically by `audited only: [:balance]` on `Account` and `TermAccount`. Exposed via `GET /accounts/{id}/audit-logs` and `GET /term-accounts/{id}/audit-logs`.

#### Entity Relationship

```
users 1──────────────────────────* transactions
  │                                   linked_account → Account or TermAccount (polymorphic)
  │                                   instrument_id FK (nullable) → instruments
  │
  ├──────────────────────────────* accounts
  │                                   bank_id FK → banks
  │                                   ▲ (parent of term_accounts)
  │                                   ▲ (linked_account target for transactions)
  │
  ├──────────────────────────────* term_accounts
  │                                   parent_account_id FK → accounts
  │                                   ▲ (linked_account target for transactions)
  │
  ├──────────────────────────────* investments
  │                                   user_instrument_id FK (nullable) → user_instruments
  │                                   platform_account_id FK (nullable) → platform_accounts
  │
  ├──────────────────────────────* platform_accounts
  │                                   platform_id FK → platforms
  │
  ├──────────────────────────────* user_instruments (M2M join to instruments)
  │                                   instrument_id FK → instruments
  │
  └──────────────────────────────* follios
                                      user_instrument_id FK → user_instruments
                                      platform_account_id FK → platform_accounts

banks        (global, admin-managed)
platforms    (global, admin-managed)
instruments  (global catalogue)
audits       (generated by audited gem — balance change log)
```

### 2.3 API Contract

All routes under `/api/v1`. Default format is JSON (`defaults: { format: :json }`). Protected routes require `Authorization: Bearer <jwt>`.

All responses are wrapped in the standard envelope from the `Responder` concern:

**Success**:
```json
{
  "success": true,
  "code": 200,
  "request_id": "abc123",
  "data": { ... },
  "meta_data": {}
}
```

**Error**:
```json
{
  "success": false,
  "code": 422,
  "data": null,
  "meta_data": {},
  "error": "human-readable message"
}
```

`meta_data` carries pagination info on list endpoints (e.g. `next_cursor`, `total_count`, `page`, `page_size`).

---

#### Auth — `/api/v1/auth`

**POST `/auth/login`** — public (`skip_before_action :authenticate_user!`)

Request:
```json
{ "email": "user@example.com", "password": "secret" }
```
Response `200`:
```json
{
  "success": true,
  "code": 200,
  "data": { "token": "<jwt>", "user": { "id": 1, "email": "...", "first_name": "...", "last_name": "...", "currency_code": "INR" } },
  "meta_data": {}
}
```
Errors: `401` invalid credentials.

---

**GET `/auth/me`** — protected

Response `200`: current user object (same shape as login `user` field).

---

**PUT `/auth/me`** — protected

Request (all fields optional):
```json
{ "first_name": "Jane", "last_name": "Smith", "password": "newpass", "currency_code": "USD" }
```
Response `200`: updated user object.

---

#### Transactions — `/api/v1/transactions`

**GET `/transactions`** — protected

Query params:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `cursor` | string | — | Opaque cursor for next page (from previous response `meta_data`) |
| `limit` | int | 20 | Records per page |
| `transaction_type` | string | — | `credit` or `debit` |
| `start_date` | date | — | ISO 8601 `YYYY-MM-DD` |
| `end_date` | date | — | ISO 8601 `YYYY-MM-DD` |
| `tags` | string (multi) | — | Filter by tag(s) |

Response `200`:
```json
{
  "success": true,
  "code": 200,
  "data": [
    {
      "id": 1,
      "public_id": "550e8400-e29b-41d4-a716-446655440000",
      "transaction_type": "debit",
      "amount": "1500.00",
      "description": "Groceries",
      "date": "2026-04-01",
      "linked_account_type": "Account",
      "linked_account_id": 2,
      "tags": ["food", "essentials"],
      "bank_ref": null,
      "is_active": true,
      "created_at": "2026-04-01T08:00:00.000Z"
    }
  ],
  "meta_data": { "next_cursor": "2026-04-01_1", "limit": 20 }
}
```

---

**POST `/transactions`** — protected

Request:
```json
{
  "transaction_type": "credit",
  "amount": "50000.00",
  "description": "Salary April",
  "date": "2026-04-01",
  "linked_account_type": "Account",
  "linked_account_id": 2,
  "bank_ref": "NEFT2026040112345",
  "tags": ["salary"]
}
```
Response `201`: created transaction object.
Errors: `422` validation failure.

Transactions are **immutable from the API**. No PUT or DELETE endpoints exist. Use Rails console or admin scripts for corrections.

---

#### Accounts — `/api/v1/accounts`

**GET `/accounts`** — protected — list current user's bank accounts.
**POST `/accounts`** — protected — create a bank account.

Request:
```json
{ "bank_id": 1, "nickname": "HDFC Salary", "account_number": "XXXX1234", "account_type": "salary", "open_date": "2020-06-01" }
```
Response `201`: account object with `balance: "0.0"` (balance is transaction-driven).

**GET `/accounts/:id`** — protected — single account.
**PUT `/accounts/:id`** — protected — partial update (nickname, account_number).
**DELETE `/accounts/:id`** — protected — destroy.

**POST `/accounts/:id/close`** — protected

Request:
```json
{ "closed_date": "2026-04-30", "closed_amount": "125000.00" }
```
Response `200`: updated account.

**GET `/accounts/:id/audit-logs`** — protected — balance change history from the `audits` table.

---

#### Term Accounts — `/api/v1/term-accounts`

**GET `/term-accounts`** — protected — list current user's FD/PPF accounts.
**POST `/term-accounts`** — protected — create FD or PPF.

FD request:
```json
{
  "parent_account_id": 2,
  "account_type": "fd",
  "amount": "100000.00",
  "interest_rate": "7.25",
  "tenure_days": 365,
  "open_date": "2026-01-01",
  "account_number": "FD00123"
}
```

PPF request:
```json
{
  "parent_account_id": 3,
  "account_type": "ppf",
  "amount": "150000.00",
  "interest_rate": "7.1",
  "open_date": "2020-04-01",
  "maturity_amount": "310000.00"
}
```

`maturity_date` and `maturity_amount` are auto-calculated for FD via `before_validation`. PPF `maturity_amount` is user-provided; `maturity_date` is auto-set to `open_date + 15 years`.

FD creation validates that the parent savings account has sufficient balance, then creates paired transactions: savings-debit + FD-credit (only savings balance is updated — FD balance tracks principal via its own transactions).

**GET `/term-accounts/:id`** — protected.
**POST `/term-accounts/:id/close`** — protected

Request: `{ "closed_date": "2027-01-01", "closed_amount": "107250.00" }`

Closure credits `closed_amount` back to the parent savings account.

**GET `/term-accounts/:id/audit-logs`** — protected — balance change history.

---

#### Banks — `/api/v1/banks`

**GET `/banks`** — protected — list all banks (read-only from API).
**GET `/banks/:id`** — protected — single bank.

---

#### Platforms — `/api/v1/platforms`

**GET `/platforms`** — protected — list all platforms (read-only from API).
**GET `/platforms/:id`** — protected — single platform.

---

#### Platform Accounts — `/api/v1/platform-accounts`

Full CRUD (index, show, create, update, destroy) — scoped to current user.

Request for create/update:
```json
{ "platform_id": 1, "nickname": "Zerodha Main", "account_id": "AB1234" }
```

---

#### Instruments — `/api/v1/instruments`

**GET `/instruments`** — protected — cursor-paginated list of all instruments.

Query params: `cursor`, `limit`, `investment_type` (filter), `search` (name/ticker/ISIN).

**GET `/instruments/types`** — protected — list valid `investment_type` values.

**GET `/instruments/tracked`** — protected — instruments tracked by current user (via `user_instruments`).

**GET `/instruments/user-instruments`** — protected — current user's `user_instrument` records (include instrument details).

**POST `/instruments`** — protected — create an instrument in the global catalogue.
```json
{ "name": "Reliance Industries", "investment_type": "stock", "ticker_symbol": "RELIANCE", "isin": "INE002A01018", "exchange": "NSE" }
```

**GET `/instruments/:id`** — protected.
**PUT `/instruments/:id`** — protected — update instrument details.
**DELETE `/instruments/:id`** — protected.

**POST `/instruments/:id/track`** — protected — create `user_instrument` row (adds to watchlist).
**DELETE `/instruments/:id/untrack`** — protected — remove from watchlist.

---

#### Investments — `/api/v1/investments`

Full CRUD (index, show, create, update, destroy) — scoped to current user.

**GET `/investments`** — protected

Query params:
| Param | Type | Description |
|-------|------|-------------|
| `investment_type` | string (multi) | Filter by type(s); repeat param for multiple |
| `page` | int | Default 1 |
| `page_size` | int | Default 20, max 200 |

**POST `/investments`** — protected

Stock/MF example:
```json
{
  "investment_type": "stock",
  "name": "Reliance Industries",
  "amount_invested": "50000.00",
  "purchase_date": "2025-01-15",
  "quantity": "10.0",
  "buy_price": "5000.00",
  "user_instrument_id": 5,
  "platform_account_id": 2
}
```

Mutual Fund example:
```json
{
  "investment_type": "mutual_fund",
  "name": "HDFC Nifty 50 Index Fund",
  "amount_invested": "25000.00",
  "purchase_date": "2025-02-01",
  "folio_number": "1234567890",
  "units": "892.8571",
  "nav_at_purchase": "28.00",
  "user_instrument_id": 8,
  "platform_account_id": 3
}
```

**PUT `/investments/:id`** — protected — partial update; commonly used to update `current_value` or `units`.
**DELETE `/investments/:id`** — protected.

---

#### Follios — `/api/v1/follios`

Full CRUD (index, show, create, update, destroy) — scoped to current user.

```json
{
  "user_instrument_id": 5,
  "platform_account_id": 2,
  "folio_number": "12345678"
}
```

Unique constraint on `(user_instrument_id, platform_account_id)`.

---

#### Reports — `/api/v1/reports`

**GET `/reports/dashboard`** — protected — Redis-cached aggregate summary.

Response `200` (inside `data`):
```json
{
  "net_worth": "1250000.00",
  "accounts_balance": "450000.00",
  "term_accounts_balance": "300000.00",
  "portfolio_value": "500000.00",
  "total_invested": "420000.00",
  "unrealized_gain": "80000.00",
  "total_inbound": "600000.00",
  "total_outbound": "150000.00",
  "net_balance": "450000.00",
  "this_month_inbound": "50000.00",
  "this_month_outbound": "18000.00",
  "this_month_net": "32000.00",
  "prev_month_inbound": "50000.00",
  "prev_month_outbound": "22000.00",
  "accounts": [ { "id": 1, "nickname": "HDFC Salary", "balance": "250000.00", ... } ],
  "upcoming_maturities": [ { "id": 1, "account_type": "fd", "maturity_date": "2027-01-01", ... } ],
  "investment_holdings": [ { "investment_type": "stock", "total_invested": "200000.00", "current_value": "240000.00", ... } ],
  "recent_transactions": [ { ... } ]
}
```

**POST `/reports/dashboard/refresh`** — protected — invalidates and rebuilds the Redis cache for the current user.

**GET `/reports/dashboard/cache-status`** — protected — returns TTL / cache hit info.

**GET `/reports/spending-trends`** — protected

Query: `?months=6` (default 6, max 24)

Response `200`:
```json
{
  "monthly_trends": [
    { "month": "2025-11", "inbound": "50000.00", "outbound": "18000.00", "net": "32000.00" },
    { "month": "2025-12", "inbound": "50000.00", "outbound": "22000.00", "net": "28000.00" }
  ]
}
```

**GET `/reports/investment-summary`** — protected

Response `200`:
```json
{
  "total_invested": "420000.00",
  "total_current_value": "500000.00",
  "total_gain_loss": "80000.00",
  "total_gain_loss_pct": 19.05,
  "by_type": [
    { "investment_type": "stock", "amount_invested": "200000.00", "current_value": "240000.00", "count": 4 },
    { "investment_type": "mutual_fund", "amount_invested": "220000.00", "current_value": "260000.00", "count": 3 }
  ]
}
```

**GET `/reports/portfolio`** — protected — detailed portfolio breakdown including per-instrument holdings.

---

#### Client Errors — `/api/v1/errors`

**POST `/errors`** — public — frontend reports client-side JS errors. Logged server-side.

---

#### API Docs

`GET /api-docs` — Swagger UI rendered by `rswag`. Specs are generated from RSpec request specs annotated with rswag metadata.

---

### 2.4 Authentication Flow

No public registration. Users exist only after admin creation.

#### Login + Subsequent Requests

```
Client                              Rails                          DB
  │                                   │                             │
  ├─POST /api/v1/auth/login ─────────►│                             │
  │  {email, password}                │                             │
  │                                   ├─User.find_by(email:) ──────►│
  │                                   │◄── User record ─────────────┤
  │                                   │                             │
  │                                   │ user.authenticate(password) │
  │                                   │ (bcrypt comparison via      │
  │                                   │  has_secure_password)       │
  │                                   │                             │
  │                                   │ JWT.encode(                 │
  │                                   │   { sub: user.id,           │
  │                                   │     exp: 7.days.from_now }, │
  │                                   │   SECRET_KEY, "HS256"       │
  │                                   │ )                           │
  │                                   │                             │
  │◄── 200 { token, user } ───────────┤                             │
  │                                   │                             │
  │ (stores token in localStorage)    │                             │
  │                                   │                             │
  ├─GET /api/v1/transactions ────────►│                             │
  │  Authorization: Bearer <jwt>      │                             │
  │                                   │ Authenticatable concern     │
  │                                   │ JWT.decode(token, secret)   │
  │                                   │ → { sub: 1, exp: ... }      │
  │                                   │                             │
  │                                   ├─User.find(1) ──────────────►│
  │                                   │◄── User(id=1, active=true)──┤
  │                                   │                             │
  │                                   │ [proceeds to controller]    │
  │                                   │                             │
  │◄── 200 TransactionList ───────────┤                             │
```

#### JWT Structure

```
Header:  { "alg": "HS256", "typ": "JWT" }
Payload: { "sub": <user_id>, "exp": <unix_timestamp> }
Secret:  SECRET_KEY_BASE from credentials / .env
Expiry:  7 days (configurable)
```

Token is never stored server-side. Logout is purely client-side (clear localStorage). A `401` response from any protected endpoint signals the frontend to clear the token and redirect to `/login`.

### 2.5 Layer Responsibilities

#### `ApplicationController` — Concerns

Two concerns are included in `ApplicationController`:

**`Authenticatable`** — JWT auth:

```ruby
# app/controllers/concerns/authenticatable.rb
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    payload = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: "HS256").first
    @current_user = User.find(payload["sub"])
    render_error("Unauthorized", :unauthorized) unless @current_user&.is_active
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    render_error("Unauthorized", :unauthorized)
  end

  def current_user
    @current_user
  end
end
```

**`Responder`** — standard envelope:

```ruby
# app/controllers/concerns/responder.rb
module Responder
  def render_success(data, status: :ok, meta_data: {})
    render json: {
      success: true,
      code: Rack::Utils::SYMBOL_TO_STATUS_CODE[status],
      request_id: request.request_id,
      data: data,
      meta_data: meta_data
    }, status: status
  end

  def render_error(message, status = :unprocessable_entity)
    render json: {
      success: false,
      code: Rack::Utils::SYMBOL_TO_STATUS_CODE[status],
      data: nil,
      meta_data: {},
      error: message
    }, status: status
  end
end
```

#### Controllers — HTTP Layer

Controllers are thin. They permit params, call one service or AR query, and delegate rendering:

```ruby
# app/controllers/api/v1/transactions_controller.rb
module Api::V1
  class TransactionsController < ApplicationController
    def index
      result = Transactions::QueryService.call(current_user, filter_params)
      render_success(result[:records], meta_data: { next_cursor: result[:next_cursor], limit: result[:limit] })
    end

    def create
      transaction = Transactions::CreateService.call(current_user, transaction_params)
      render_success(transaction, status: :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.message, :unprocessable_entity)
    end

    private

    def filter_params
      params.permit(:cursor, :limit, :transaction_type, :start_date, :end_date, tags: [])
    end

    def transaction_params
      params.require(:transaction).permit(:transaction_type, :amount, :description, :date,
        :linked_account_type, :linked_account_id, :bank_ref, tags: [])
    end
  end
end
```

#### Models — AR Layer

Models handle validations, enums, callbacks, and associations:

```ruby
# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :linked_account, polymorphic: true, optional: true
  belongs_to :instrument, optional: true

  enum :transaction_type, { credit: "credit", debit: "debit" }

  validates :amount, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :transaction_type, presence: true

  after_create :apply_balance_delta

  private

  def apply_balance_delta
    return unless linked_account.present?
    # Skip FD term accounts — FD balance tracks principal, not running deposits
    return if linked_account.is_a?(TermAccount) && linked_account.account_type == "fd"

    if credit?
      linked_account.credit!(amount)
    else
      linked_account.debit!(amount)
    end
  end
end
```

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  audited only: [:balance]

  belongs_to :user
  belongs_to :bank
  has_many :transactions, as: :linked_account
  has_many :term_accounts, foreign_key: :parent_account_id

  enum :account_type, { savings: "savings", current: "current", salary: "salary", nre: "nre", nro: "nro" }

  def debit!(amount)
    raise "Insufficient balance" if balance < amount
    update!(balance: balance - amount)
  end

  def credit!(amount)
    update!(balance: balance + amount)
  end
end
```

```ruby
# app/models/term_account.rb
class TermAccount < ApplicationRecord
  audited only: [:balance]

  belongs_to :user
  belongs_to :parent_account, class_name: "Account"
  has_many :transactions, as: :linked_account

  enum :account_type, { fd: "fd", ppf: "ppf" }

  before_validation :apply_defaults

  private

  def apply_defaults
    if fd?
      self.maturity_date   ||= open_date + tenure_days.days
      # Compound quarterly: A = P(1 + r/400)^(n/91.25)
      self.maturity_amount ||= (amount * ((1 + interest_rate / 400) ** (tenure_days / 91.25))).round(2)
    elsif ppf?
      self.maturity_date   ||= open_date + 15.years
      # maturity_amount is user-provided for PPF
    end
  end
end
```

### 2.6 Service Layer Design

Services are plain Ruby objects with a `self.call` class method. They accept the `current_user` (for ownership scoping) and a params hash.

#### `Transactions::QueryService`

```ruby
# app/services/transactions/query_service.rb
module Transactions
  class QueryService
    def self.call(user, params)
      new(user, params).call
    end

    def initialize(user, params)
      @user   = user
      @limit  = [(params[:limit] || 20).to_i, 100].min
      @cursor = params[:cursor]   # "2026-04-01_42" (date_id composite)
      @type   = params[:transaction_type]
      @start  = params[:start_date]
      @end    = params[:end_date]
      @tags   = params[:tags]
    end

    def call
      scope = @user.transactions.active.order(date: :desc, id: :desc)

      scope = scope.where(transaction_type: @type)    if @type.present?
      scope = scope.where("date >= ?", @start)        if @start.present?
      scope = scope.where("date <= ?", @end)          if @end.present?
      scope = scope.where("tags @> ARRAY[?]::varchar[]", @tags) if @tags.present?

      if @cursor.present?
        cursor_date, cursor_id = @cursor.split("_")
        scope = scope.where("(date, id) < (?, ?)", cursor_date, cursor_id)
      end

      records    = scope.limit(@limit + 1).to_a
      has_more   = records.size > @limit
      records    = records.first(@limit)
      next_cursor = has_more ? "#{records.last.date}_#{records.last.id}" : nil

      { records: records, next_cursor: next_cursor, limit: @limit }
    end
  end
end
```

#### `Transactions::CreateService`

```ruby
# app/services/transactions/create_service.rb
module Transactions
  class CreateService
    def self.call(user, params)
      new(user, params).call
    end

    def initialize(user, params)
      @user   = user
      @params = params
    end

    def call
      transaction = @user.transactions.build(@params)
      # Validates linked account belongs to current user before save
      if @params[:linked_account_id].present? && @params[:linked_account_type].present?
        klass   = @params[:linked_account_type].constantize
        account = klass.find_by(id: @params[:linked_account_id], user_id: @user.id)
        raise ActiveRecord::RecordInvalid, "Linked account not found" unless account
      end
      transaction.save!
      transaction
    end
  end
end
```

#### `Investments::QueryService`

Page-based (kaminari):

```ruby
# app/services/investments/query_service.rb
module Investments
  class QueryService
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE     = 200

    def self.call(user, params)
      new(user, params).call
    end

    def call
      scope = @user.investments.order(purchase_date: :desc, id: :desc)
      scope = scope.where(investment_type: @types) if @types.present?
      scope.page(@page).per(@page_size)
    end
  end
end
```

### 2.7 Report Queries

All report queries run directly on AR scopes using SQL aggregations. Dashboard results are cached in Redis per user.

#### Dashboard Summary

```ruby
# Balances
accounts_balance      = user.accounts.sum(:balance)
term_accounts_balance = user.term_accounts.where(is_active: true).sum(:balance)

# Portfolio
portfolio_value  = user.investments.sum(:current_value)
total_invested   = user.investments.sum(:amount_invested)
unrealized_gain  = portfolio_value - total_invested

# Transaction totals (all time)
total_inbound  = user.transactions.active.credit.sum(:amount)
total_outbound = user.transactions.active.debit.sum(:amount)

# This month
this_month_inbound  = user.transactions.active.credit.where("date >= ?", Date.current.beginning_of_month).sum(:amount)
this_month_outbound = user.transactions.active.debit.where("date >= ?",  Date.current.beginning_of_month).sum(:amount)
```

#### Monthly Spending Trends

```ruby
# Uses date_trunc via AR grouping
results = user.transactions
  .active
  .where(date: period_start..period_end)
  .group("DATE_TRUNC('month', date)", :transaction_type)
  .order("DATE_TRUNC('month', date)")
  .sum(:amount)

# results is Hash like { [2026-01-01, "credit"] => 50000, [2026-01-01, "debit"] => 18000 }
```

#### Investment Summary

```ruby
by_type = user.investments
  .group(:investment_type)
  .select(
    :investment_type,
    "SUM(amount_invested) AS total_invested",
    "SUM(current_value)   AS total_current_value",
    "COUNT(*)             AS count"
  )
```

#### Redis Cache (Dashboard)

```ruby
# Cache key is per-user; TTL is configurable (default: 1 hour)
CACHE_KEY = ->(user_id) { "dashboard:user:#{user_id}" }

def fetch_dashboard(user)
  Rails.cache.fetch(CACHE_KEY.call(user.id), expires_in: 1.hour) do
    build_dashboard_payload(user)
  end
end

# POST /reports/dashboard/refresh invalidates and rebuilds:
def refresh_dashboard(user)
  Rails.cache.delete(CACHE_KEY.call(user.id))
  fetch_dashboard(user)
end
```

### 2.8 Pagination

Two strategies are used depending on the domain:

#### Cursor-Based (Transactions, Instruments)

Cursor encodes `"<date>_<id>"`. The composite index `(date, id)` makes cursor seeks efficient:

```sql
-- Next page after cursor "2026-04-01_42":
WHERE (date, id) < ('2026-04-01', 42)
ORDER BY date DESC, id DESC
LIMIT 21  -- fetch limit+1 to detect has_more
```

Response `meta_data`:
```json
{ "next_cursor": "2026-03-28_17", "limit": 20 }
```

When `next_cursor` is `null`, there are no more pages.

#### Page-Based (Investments)

Kaminari page-based via `scope.page(page).per(page_size)`:

```json
{ "page": 2, "page_size": 20, "total_count": 47, "total_pages": 3 }
```

Max `page_size` is 200 for investments.

### 2.9 Error Handling

#### `rescue_from` in `ApplicationController`

```ruby
class ApplicationController < ActionController::API
  include Authenticatable
  include Responder

  rescue_from ActiveRecord::RecordNotFound    do |e| render_error(e.message, :not_found)            end
  rescue_from ActiveRecord::RecordInvalid     do |e| render_error(e.message, :unprocessable_entity) end
  rescue_from ActionController::ParameterMissing do |e| render_error(e.message, :bad_request)       end
  rescue_from JWT::DecodeError                do |_| render_error("Unauthorized", :unauthorized)    end
end
```

#### Error Response Table

| Situation | HTTP Status |
|-----------|-------------|
| Resource not found | `404 Not Found` |
| JWT invalid or expired | `401 Unauthorized` |
| User inactive | `401 Unauthorized` |
| Validation failure | `422 Unprocessable Entity` |
| Params missing | `400 Bad Request` |
| Business rule violation | `422 Unprocessable Entity` |
| Unhandled server error | `500 Internal Server Error` |

All errors follow the standard envelope: `{ success: false, code: ..., data: null, error: "message" }`.

### 2.10 Configuration Management

Rails credentials (`config/credentials.yml.enc`) and environment variables via `ENV`:

`backend/.env` (gitignored, loaded via `dotenv-rails` in development):
```
DATABASE_URL=postgresql://fintrack_user:password@localhost:5432/fintrack_db
SECRET_KEY_BASE=<output of: rails secret>
REDIS_URL=redis://localhost:6379/0
ENVIRONMENT=development
```

Access pattern:
```ruby
# Database — Rails reads DATABASE_URL automatically
# Redis
Rails.application.config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
# JWT secret
JWT.encode(payload, Rails.application.credentials.secret_key_base, "HS256")
```

CORS (development only):
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:5173"
    resource "/api/*", headers: :any, methods: [:get, :post, :put, :patch, :delete, :options]
  end
end
```

### 2.11 Database Migrations

Rails migrations live in `db/migrate/`. The canonical schema state is always `db/schema.rb` (auto-regenerated on `rails db:migrate`).

Workflow for schema changes:
1. `rails generate migration AddColumnXToInvestments column_x:string`
2. Edit the generated file in `db/migrate/` if needed
3. `rails db:migrate`
4. `db/schema.rb` is automatically updated — commit it alongside the migration

Loading a fresh DB:
```bash
rails db:create db:schema:load  # faster than running all migrations
# or
rails db:migrate                # incremental
```

**No downgrade migrations** — write a new forward migration for any change. `schema.rb` is the source of truth for `db:schema:load`.

Key constraints:
- `pgcrypto` extension must be enabled before migrations that use `gen_random_uuid()`.
- String enums (`account_type`, `transaction_type`, etc.) are stored as `VARCHAR` with AR `enum` validation — not PostgreSQL `ENUM` types — making future value additions a Rails-only change.

### 2.12 Testing Strategy

RSpec with `factory_bot_rails`, `shoulda-matchers`, `database_cleaner-active_record`, and `rswag-specs`.

`spec/rails_helper.rb` critical setup:

```ruby
require "database_cleaner/active_record"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Shoulda::Matchers::ActiveRecord, type: :model
  config.include Shoulda::Matchers::ActiveModel,  type: :model

  config.before(:suite)  { DatabaseCleaner.strategy = :transaction }
  config.around(:each)   { |example| DatabaseCleaner.cleaning { example.run } }
end
```

#### Request Spec Example

```ruby
# spec/requests/api/v1/transactions_spec.rb
require "rails_helper"

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:user)  { create(:user) }
  let(:bank)  { create(:bank) }
  let(:account) { create(:account, user: user, bank: bank) }
  let(:token) { JWT.encode({ sub: user.id, exp: 7.days.from_now.to_i }, Rails.application.credentials.secret_key_base, "HS256") }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/transactions" do
    it "creates a transaction and updates account balance" do
      post "/api/v1/transactions",
        params: {
          transaction: {
            transaction_type: "credit",
            amount: "5000.00",
            description: "Test credit",
            date: Date.current.iso8601,
            linked_account_type: "Account",
            linked_account_id: account.id
          }
        },
        headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]["amount"]).to eq("5000.0")
      expect(account.reload.balance).to eq(5000.0)
    end
  end

  describe "GET /api/v1/transactions" do
    before { create_list(:transaction, 5, user: user, linked_account: account) }

    it "returns paginated transactions" do
      get "/api/v1/transactions", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["data"].length).to eq(5)
      expect(body["meta_data"]).to have_key("next_cursor")
    end
  end
end
```

#### Model Spec Example

```ruby
# spec/models/term_account_spec.rb
require "rails_helper"

RSpec.describe TermAccount, type: :model do
  describe "before_validation :apply_defaults" do
    context "FD" do
      it "auto-calculates maturity_date and maturity_amount" do
        fd = build(:term_account, :fd, open_date: Date.new(2026, 1, 1), tenure_days: 365, interest_rate: 7.25, amount: 100_000)
        fd.valid?
        expect(fd.maturity_date).to eq(Date.new(2027, 1, 1))
        expect(fd.maturity_amount).to be_within(1).of(107_500)
      end
    end

    context "PPF" do
      it "sets maturity_date to open_date + 15 years" do
        ppf = build(:term_account, :ppf, open_date: Date.new(2020, 4, 1))
        ppf.valid?
        expect(ppf.maturity_date).to eq(Date.new(2035, 4, 1))
      end
    end
  end
end
```

#### Factory Examples

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name    { "Test" }
    last_name     { "User" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password      { "password123" }
    is_active     { true }
  end
end

# spec/factories/transactions.rb
FactoryBot.define do
  factory :transaction do
    user
    association :linked_account, factory: :account
    transaction_type { "credit" }
    amount           { 1000.00 }
    description      { "Test transaction" }
    date             { Date.current }
  end
end
```

Tests run against a real PostgreSQL test database — no SQLite fallback. This catches PostgreSQL-specific features (array columns, UUID defaults, `date_trunc`) that SQLite would not exercise.

Run tests:
```bash
cd backend
bundle exec rspec                          # all specs
bundle exec rspec spec/requests/           # request specs only
bundle exec rspec spec/models/             # model specs only
bundle exec rspec spec/requests/api/v1/transactions_spec.rb  # single file
```
