# FinTrack — Sample Seed Data

Sample rows for each table showing realistic data. UUIDs are shortened for readability (`u1`, `b1`, etc.).

---

## User

| id | email | first_name | last_name | is_active | is_superuser | created_at |
|----|-------|-----------|-----------|-----------|--------------|------------|
| u1 | test@fintrack.dev | Prashant | Sharma | true | false | 2025-01-01 |
| u2 | admin@fintrack.dev | Admin | User | true | true | 2025-01-01 |

---

## Bank

| id | name | code |
|----|------|------|
| bk1 | HDFC Bank | HDFC |
| bk2 | State Bank of India | SBI |
| bk3 | ICICI Bank | ICICI |
| bk4 | Axis Bank | AXIS |

---

## Account

| id | user_id | bank_id | account_number | account_type | balance |
|----|---------|---------|----------------|--------------|---------|
| ac1 | u1 | bk1 | HDFC0001234567 | savings | 125000.00 |
| ac2 | u1 | bk2 | SBI00098765432 | salary | 48200.00 |
| ac3 | u1 | bk3 | ICICI009988776 | current | -12400.00 |

---

## Instrument

| id | name | symbol | type | created_at |
|----|------|--------|------|------------|
| in1 | Reliance Industries | RELIANCE | stock | 2025-01-01 |
| in2 | HDFC Bank | HDFCBANK | stock | 2025-01-01 |
| in3 | Infosys | INFY | stock | 2025-01-01 |
| in4 | Nippon India Nifty 50 Index Fund | NIPPON-NIFTY50 | mutual_fund | 2025-01-01 |
| in5 | Parag Parikh Flexi Cap Fund | PPFCF | mutual_fund | 2025-01-01 |

---

## UserInstrument

| id | user_id | instrument_id |
|----|---------|---------------|
| ui1 | u1 | in1 |
| ui2 | u1 | in2 |
| ui3 | u1 | in4 |
| ui4 | u1 | in5 |

---

## Platform

| id | name | code |
|----|------|------|
| pl1 | Zerodha | ZERODHA |
| pl2 | Groww | GROWW |
| pl3 | Coin by Zerodha | COIN |

---

## PlatformAccount

| id | user_id | platform_id | account_identifier | created_at |
|----|---------|-------------|-------------------|------------|
| pa1 | u1 | pl1 | ZER-PS-00123 | 2025-01-15 |
| pa2 | u1 | pl2 | GROWW-9988776 | 2025-01-20 |

---

## Follio

| id | follio_id | user_id | platform_id | instrument_id | created_at |
|----|-----------|---------|-------------|---------------|------------|
| fo1 | 12345678 | u1 | pl2 | in4 | 2025-02-01 |
| fo2 | 87654321 | u1 | pl2 | in5 | 2025-02-01 |
| fo3 | ZER-DEMAT-RELIANCE | u1 | pl1 | in1 | 2025-03-01 |

> `follio_id` is the platform's own reference string — MF folio number, demat holding ID, etc.

---

## Transaction

| id | account_id | user_id | type | amount | category | description | public_id | created_at |
|----|-----------|---------|------|--------|----------|-------------|-----------|------------|
| tx1 | ac2 | u1 | inbound | 95000.00 | salary | Salary - April 2025 | pub1 | 2025-04-01 |
| tx2 | ac1 | u1 | outbound | 25000.00 | rent | House rent - April | pub2 | 2025-04-02 |
| tx3 | ac1 | u1 | outbound | 4200.00 | groceries | Big Basket order | pub3 | 2025-04-05 |
| tx4 | ac1 | u1 | outbound | 5000.00 | investment | SIP — Nippon Nifty 50 | pub4 | 2025-04-07 |
| tx5 | ac1 | u1 | inbound | 1850.00 | dividend | HDFCBANK dividend | pub5 | 2025-04-10 |
| tx6 | ac1 | u1 | outbound | 1200.00 | dining | Zomato / dining out | pub6 | 2025-04-15 |
| tx7 | ac1 | u1 | outbound | 18000.00 | investment | Stock buy — RELIANCE | pub7 | 2025-04-18 |

---

## InvestmentTransaction

| id | user_id | platform_account_id | instrument_id | type | name | amount_invested | current_value | purchase_date | quantity | avg_buy_price | folio_number | units | nav_at_purchase | bank_name | fd_number | interest_rate | tenure_months | maturity_date | maturity_amount | gold_form | weight_grams | purity | transaction_public_id |
|----|---------|--------------------|-----------|----|------|-----------------|---------------|---------------|----------|---------------|--------------|-------|-----------------|-----------|-----------|---------------|---------------|---------------|-----------------|-----------|-------------|--------|----------------------|
| it1 | u1 | pa1 | in1 | stock | Reliance Industries | 18000.00 | 20400.00 | 2025-04-18 | 6.00 | 3000.00 | — | — | — | — | — | — | — | — | — | — | — | — | pub7 |
| it2 | u1 | pa2 | in4 | mutual_fund | Nippon India Nifty 50 Index Fund | 5000.00 | 5210.00 | 2025-04-07 | — | — | 12345678 | 98.45 | 50.79 | — | — | — | — | — | — | — | — | — | pub4 |
| it3 | u1 | — | — | fixed_deposit | SBI Fixed Deposit | 100000.00 | 107500.00 | 2025-01-15 | — | — | — | — | — | State Bank of India | SBI-FD-2025-001 | 7.50 | 12 | 2026-01-15 | 107500.00 | — | — | — | — |
| it4 | u1 | — | — | gold | Sovereign Gold Bond 2024 | 45000.00 | 52000.00 | 2024-11-20 | — | — | — | — | — | — | — | — | — | — | — | SGB | 14.50 | 24K | — |
| it5 | u1 | — | — | ppf | Public Provident Fund | 150000.00 | 163500.00 | 2024-04-01 | — | — | — | — | — | — | — | 7.10 | — | 2039-04-01 | — | — | — | — | — |

> `—` denotes NULL. Type-specific columns are only populated for the relevant investment type.

---

## Cross-table FK traceability example

```
Transaction tx4 (SIP payment, outbound ₹5000)
  └── public_id = pub4
        └── InvestmentTransaction it2
              ├── instrument_id = in4  →  Instrument: "Nippon India Nifty 50 Index Fund"
              ├── platform_account_id = pa2  →  PlatformAccount on Groww (GROWW-9988776)
              └── folio_number = 12345678  →  Follio fo1

Transaction tx7 (stock buy, outbound ₹18000)
  └── public_id = pub7
        └── InvestmentTransaction it1
              ├── instrument_id = in1  →  Instrument: "Reliance Industries" (RELIANCE)
              └── platform_account_id = pa1  →  PlatformAccount on Zerodha (ZER-PS-00123)
```
