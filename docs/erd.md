# FinTrack — Entity Relationship Diagram

> Based on `DB-Design.txt`. This reflects the **intended design**, not the current implementation.

```mermaid
erDiagram

    User {
        uuid    id
        string  email
        string  first_name
        string  last_name
        string  hashed_password
        boolean is_active           "default false"
        boolean is_superuser        "default false"
        datetime created_at
        datetime updated_at
    }

    Bank {
        uuid    id
        string  name
        string  code
    }

    Account {
        uuid    id
        uuid    user_id             FK
        uuid    bank_id             FK
        string  account_number
        string  account_type        "AccountType enum"
        decimal balance
    }

    Transaction {
        uuid    id
        uuid    account_id          FK
        uuid    user_id             FK
        string  type                "inbound | outbound"
        decimal amount
        string  description
        string  category            "TransactionCategory enum"
        uuid    public_id           "external reference ID"
        datetime created_at
        datetime updated_at
    }

    Instrument {
        uuid    id
        string  name
        string  symbol
        string  type                "InstrumentType enum"
        datetime created_at
        datetime updated_at
    }

    UserInstrument {
        uuid    id
        uuid    user_id             FK
        uuid    instrument_id       FK
    }

    Platform {
        uuid    id
        string  name
        string  code
    }

    PlatformAccount {
        uuid    id
        uuid    user_id             FK
        uuid    platform_id         FK
        string  account_identifier  "username or account no. on platform"
        datetime created_at
        datetime updated_at
    }

    Follio {
        uuid    id
        string  follio_id           "unique folio reference string"
        uuid    user_id             FK
        uuid    platform_id         FK
        uuid    instrument_id       FK  "must exist in UserInstrument"
        datetime created_at
        datetime updated_at
    }

    InvestmentTransaction {
        int         id                      PK
        int         user_id                 FK
        int         platform_account_id     FK  "nullable"
        int         instrument_id           FK  "nullable"
        string      type                    "stock|mutual_fund|fixed_deposit|gold|crypto|ppf|nps|real_estate"
        string      name
        decimal     amount_invested
        decimal     current_value
        date        purchase_date
        text        notes
        decimal     quantity                "stock: shares held"
        decimal     avg_buy_price           "stock: avg cost"
        string      folio_number            "MF: folio"
        decimal     units                   "MF: units held"
        decimal     nav_at_purchase         "MF: NAV at buy"
        string      bank_name               "FD: issuing bank"
        string      fd_number               "FD: reference"
        decimal     interest_rate           "FD: % p.a."
        int         tenure_months           "FD: duration"
        date        maturity_date           "FD"
        decimal     maturity_amount         "FD"
        string      compounding             "FD: quarterly etc."
        string      gold_form               "Gold: SGB/coin/bar"
        decimal     weight_grams            "Gold"
        string      purity                  "Gold: 24K etc."
        int         transaction_public_id   FK  "→ Transaction.public_id"
        datetime    created_at
        datetime    updated_at
    }

    %% ── Relationships ──────────────────────────────────────────────────────

    User                ||--o{    Account                 : "has"
    User                ||--o{    Transaction             : "owns"
    User                ||--o{    UserInstrument          : "tracks"
    User                ||--o{    PlatformAccount         : "has"
    User                ||--o{    Follio                  : "holds"
    User                ||--o{    InvestmentTransaction   : "makes"

    Bank                ||--o{    Account                 : "provides"
    Account             ||--o{    Transaction             : "source of"

    Instrument          ||--o{    UserInstrument          : "tracked via"
    Instrument          ||--o{    Follio                  : "held in"
    Instrument          |o--o{    InvestmentTransaction   : "linked to"

    Platform            ||--o{    PlatformAccount         : "provides"
    Platform            ||--o{    Follio                  : "hosts"

    PlatformAccount     |o--o{    InvestmentTransaction   : "held in"
    Follio              ||--o{    InvestmentTransaction   : "involved in"
    Transaction         |o--o{    InvestmentTransaction   : "traced via public_id"
```

## Design notes

### Follio
Represents a user's position account for a specific instrument on a specific platform — e.g. a mutual fund folio number, or a demat account holding for a particular stock. `instrument_id` must already exist in `UserInstrument` (i.e. the user must be tracking that instrument before creating a folio).

### InvestmentTransaction
Models individual **buy / sell events**, not snapshots. Uses a **polymorphic source → destination** pattern:

| Event | source_type | destination_type |
|---|---|---|
| Buy stock | `bank` (debit account) | `follio` (position increases) |
| Sell stock | `follio` (position decreases) | `bank` (credit account) |
| MF SIP | `bank` | `follio` |
| MF redemption | `follio` | `bank` |

`transaction_public_id` links back to the corresponding `Transaction.public_id` for full cash-flow traceability.

### TransactionCategory
`Transaction` carries a `category` enum (e.g. salary, rent, groceries, investment) for spending classification — not yet defined in the design file but implied by the field.

### Key divergences from current implementation
| Design | Current impl |
|---|---|
| `User.first_name` + `last_name` | `User.full_name` |
| `User.is_superuser` | Missing |
| `Account.balance` | Missing |
| `Transaction.category` | Missing |
| `Transaction.public_id` | Missing |
| `Follio` table | Missing — collapsed into `Investment` |
| `InvestmentTransaction` (buy/sell events) | `Investment` (snapshot of current holding) |
| Polymorphic source/destination | Not implemented |
| UUID primary keys | Integer primary keys |
