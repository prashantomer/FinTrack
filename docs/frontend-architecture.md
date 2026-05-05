# FinTrack Frontend Architecture

## Table of Contents

1. [High-Level Design (HLD)](#1-high-level-design)
   - 1.1 [System Overview](#11-system-overview)
   - 1.2 [Component Architecture](#12-component-architecture)
   - 1.3 [State Management Strategy](#13-state-management-strategy)
   - 1.4 [Routing Architecture](#14-routing-architecture)
   - 1.5 [Dev vs Production Flow](#15-dev-vs-production-flow)
   - 1.6 [Tech Stack Rationale](#16-tech-stack-rationale)
2. [Low-Level Design (LLD)](#2-low-level-design)
   - 2.1 [Directory Structure](#21-directory-structure)
   - 2.2 [Type System](#22-type-system)
   - 2.3 [API Client Layer](#23-api-client-layer)
   - 2.4 [Authentication Flow](#24-authentication-flow)
   - 2.5 [React Query Patterns](#25-react-query-patterns)
   - 2.6 [Form Management](#26-form-management)
   - 2.7 [Component Design](#27-component-design)
   - 2.8 [Pages](#28-pages)
   - 2.9 [Dashboard & Charts](#29-dashboard--charts)
   - 2.10 [Investment Form — Dynamic Fields](#210-investment-form--dynamic-fields)
   - 2.11 [Instruments Page — Two-Table Pattern](#211-instruments-page--two-table-pattern)
   - 2.12 [Pagination Patterns](#212-pagination-patterns)
   - 2.13 [Error Handling & Loading States](#213-error-handling--loading-states)
   - 2.14 [Build Configuration](#214-build-configuration)
   - 2.15 [Styling System](#215-styling-system)

---

## 1. High-Level Design

### 1.1 System Overview

The frontend is a **React 19 SPA** built with Vite 8. In development it runs on its own port (5173) and proxies all `/api` requests to FastAPI (8000). In production it compiles to a static `dist/` bundle that FastAPI serves directly — no separate frontend server needed.

```
┌──────────────────────────────────────────────────────────────┐
│                    Browser (SPA)                             │
│                                                              │
│  ┌────────────┐   ┌──────────────┐   ┌───────────────────┐  │
│  │ AuthContext│   │ React Router │   │  TanStack Query   │  │
│  │ (JWT store)│   │  v7 Routes   │   │  (server cache)   │  │
│  └────────────┘   └──────────────┘   └───────────────────┘  │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                   Pages / Components                  │   │
│  │  Login  Dashboard  Transactions  Investments  Accounts│   │
│  │  Platforms  Instruments  Portfolio  Follios  Reports  │   │
│  └───────────────────────┬───────────────────────────────┘   │
│                          │                                   │
│  ┌───────────────────────▼───────────────────────────────┐   │
│  │              API Layer  (api/client.ts)                │   │
│  │         Axios instance — baseURL "/api/v1"             │   │
│  │   Request interceptor: attach Bearer token             │   │
│  │   Response interceptor: redirect on 401                │   │
│  └───────────────────────┬───────────────────────────────┘   │
└──────────────────────────┼───────────────────────────────────┘
                           │ HTTP  (proxy in dev / direct in prod)
┌──────────────────────────▼───────────────────────────────────┐
│               FastAPI Backend  :8000                          │
│               /api/v1/*  endpoints                            │
└───────────────────────────────────────────────────────────────┘
```

### 1.2 Component Architecture

```
App.tsx  (Router + Providers)
│
├── PublicRoutes
│   └── LoginPage          (no public registration — users created via CLI)
│
└── ProtectedRoute  (checks AuthContext → redirects if unauthenticated)
    └── AppShell  (persistent layout: sidebar + header)
        ├── Sidebar  (nav links, active state)
        ├── Header   (user menu, logout)
        └── <Outlet />  (rendered page)
            ├── DashboardPage
            ├── TransactionsPage
            ├── InvestmentsPage
            ├── PortfolioPage
            ├── AccountsPage
            ├── PlatformAccountsPage
            ├── InstrumentsPage
            ├── FolliosPage
            └── ReportsPage
```

**Provider stack** (outermost → innermost, defined in `main.tsx`):

```
<QueryClientProvider>        ← TanStack Query cache
  <AuthProvider>             ← JWT state + login/logout + user profile
    <RouterProvider>         ← React Router v7
      <App />
    </RouterProvider>
  </AuthProvider>
</QueryClientProvider>
```

### 1.3 State Management Strategy

FinTrack uses **two distinct state layers** — no Redux, no Zustand:

| Layer | Tool | What lives here |
|-------|------|----------------|
| **Server state** | TanStack Query v5 | Transactions, investments, accounts, instruments, dashboard, reports — anything fetched from the API |
| **Auth state** | React Context | JWT token, user object (including `currency_code` + `currency_locale`), `login()`, `logout()` |

**No global UI state store.** Component-local `useState` handles everything else (modal open/close, filter state, form dirty state, selected page). The rule: if it comes from the server, it belongs in React Query. If it identifies the current user, it belongs in AuthContext. Everything else is local.

`useCurrency()` derives a `formatCurrency` function from the user's `currency_code` and `currency_locale` stored in AuthContext — the displayed currency symbol updates without a page reload when the user changes their profile.

### 1.4 Routing Architecture

React Router v7 with the data router API (`createBrowserRouter`):

```
/login              → LoginPage              (public)
/                   → DashboardPage          (protected)
/transactions       → TransactionsPage       (protected)
/investments        → InvestmentsPage        (protected)
/portfolio          → PortfolioPage          (protected)
/accounts           → AccountsPage           (protected)
/platform-accounts  → PlatformAccountsPage   (protected)
/instruments        → InstrumentsPage        (protected)
/follios            → FolliosPage            (protected)
/reports            → ReportsPage            (protected)
```

There is **no `/register` route** — user registration is CLI-only (`uv run python -m app.cli users create`).

**Route protection pattern:**

```
ProtectedRoute
  └── reads AuthContext
  └── if no token → <Navigate to="/login" replace />
  └── if token    → <Outlet />  (renders nested route)
```

`AppShell` is a layout route wrapping all protected routes. It renders `<Outlet />` in its content area — sidebar and header are always mounted, only the page content changes on navigation.

### 1.5 Dev vs Production Flow

#### Development

```
Browser :5173
  │
  ├── /               → Vite dev server serves index.html + React HMR
  ├── /assets/*       → Vite serves bundled assets
  └── /api/*          → Proxy → http://localhost:8000/api/*
                         (vite.config.ts: server.proxy)
```

`changeOrigin: true` in the proxy config means the browser sees a single origin (`:5173`) — no CORS headers needed in development.

#### Production

```
Browser :8000
  │
  ├── /api/*          → FastAPI routes (served first)
  ├── /assets/*       → StaticFiles(frontend/dist/assets/)
  └── /*              → FileResponse(frontend/dist/index.html)
                         (catch-all enables React Router client-side routing)
```

Build command: `npm run build` → Vite outputs `frontend/dist/`. FastAPI detects the directory and auto-mounts it via the catch-all registered after all `/api/v1/` routers.

### 1.6 Tech Stack Rationale

| Concern | Choice | Why |
|---------|--------|-----|
| Build tool | Vite 8 | Near-instant HMR, ES module native, Rollup-based prod build |
| UI framework | React 19 | Concurrent features, stable ecosystem |
| Language | TypeScript 6 | Full type coverage for API shapes matches backend Pydantic schemas |
| Routing | React Router v7 | Data router API; nested layouts with Outlet |
| Server state | TanStack Query v5 | Built-in cache, background refetch, mutation invalidation — eliminates hand-rolled fetch/loading/error boilerplate |
| Forms | react-hook-form + Zod v4 | Uncontrolled inputs = no re-render on keystroke; Zod schema is the single source of truth for field validation |
| HTTP client | Axios | Interceptors for auth header + 401 redirect; cleaner than fetch for all JSON APIs |
| Charts | Recharts 3 | Pure React (no D3 imperative code), TypeScript-first, composable primitives |
| UI components | shadcn/ui + Tailwind v4 | Unstyled accessible primitives, full design control, copied into codebase (not a black-box dependency) |
| Icons | lucide-react | Tree-shakeable, consistent style, TypeScript types |
| Date handling | date-fns | Immutable, tree-shakeable, no global locale mutation |
| Toast notifications | sonner | Minimal API, accessible, works without a provider wrapping the whole tree |
| Headless popover | @base-ui/react | Used for `InstrumentCombobox` — note: does **not** support `asChild` (unlike Radix UI), style `PopoverTrigger` directly |

---

## 2. Low-Level Design

### 2.1 Directory Structure

```
frontend/
├── index.html                    ← Vite entry; mounts <div id="root">
├── vite.config.ts                ← Dev proxy + build config
├── tsconfig.json                 ← TypeScript config (strict mode)
├── components.json               ← shadcn/ui config (paths, style)
│
└── src/
    ├── main.tsx                  ← ReactDOM.createRoot, provider stack
    ├── App.tsx                   ← createBrowserRouter, route definitions
    ├── vite-env.d.ts             ← Vite import.meta.env types
    │
    ├── types/
    │   └── index.ts              ← All shared TypeScript interfaces (mirrors backend schemas):
    │                               User, Bank, Account, AccountCreate, AccountClose,
    │                               TermAccount, TermAccountCreate, TermAccountClose,
    │                               Transaction, TransactionCreate, TransactionListResponse,
    │                               Investment, InvestmentListResponse,
    │                               Instrument, UserInstrument, Follio,
    │                               DashboardReport, SpendingTrendsReport,
    │                               InvestmentSummaryReport, PortfolioReport, PortfolioPosition,
    │                               AuditLog, and all enum types
    │
    ├── api/                      ← Axios call functions (pure async, no React, no hooks)
    │   ├── client.ts             ← Axios instance + interceptors
    │   ├── auth.ts               ← login(), getMe(), updateMe()
    │   ├── banks.ts              ← listBanks, listAccounts, createAccount, updateAccount,
    │   │                           closeAccount, deleteAccount
    │   ├── term_accounts.ts      ← listTermAccounts, getTermAccount, createTermAccount,
    │   │                           closeTermAccount
    │   ├── transactions.ts       ← listTransactions (cursor-based), createTransaction
    │   ├── investments.ts        ← listInvestments(type[], page, pageSize), getInvestment,
    │   │                           createInvestment, updateInvestment, deleteInvestment
    │   ├── instruments.ts        ← listInstruments (cursor-based infinite), listInstrumentTypes,
    │   │                           listTrackedInstruments, createInstrument,
    │   │                           trackInstrument, untrackInstrument, listUserInstruments
    │   ├── platforms.ts          ← listPlatforms, listPlatformAccounts,
    │   │                           createPlatformAccount, updatePlatformAccount,
    │   │                           deletePlatformAccount
    │   ├── follios.ts            ← listFollios, createFollio, updateFollio, deleteFollio
    │   ├── reports.ts            ← getDashboard, refreshDashboard, getDashboardCacheStatus,
    │   │                           getSpendingTrends, getInvestmentSummary, getPortfolio
    │   └── audit.ts              ← getAccountAuditLogs, getTermAccountAuditLogs
    │
    ├── context/
    │   └── AuthContext.tsx        ← createContext, AuthProvider, useAuthContext hook;
    │                               stores token + User (incl. currency_code, currency_locale)
    │
    ├── hooks/                    ← React Query hooks (wrap api/ functions)
    │   ├── useBanks.ts           ← useBanks, useAccounts, useCreateAccount,
    │   │                           useUpdateAccount, useCloseAccount, useDeleteAccount
    │   ├── useTermAccounts.ts    ← useTermAccounts, useCreateTermAccount, useCloseTermAccount
    │   ├── useTransactions.ts    ← useTransactions (cursor-based), useCreateTransaction
    │   ├── useInvestments.ts     ← useInvestments(types?, page, pageSize),
    │   │                           useCreateInvestment, useUpdateInvestment, useDeleteInvestment
    │   ├── useInstruments.ts     ← useInfiniteInstruments, useInstrumentTypes,
    │   │                           useTrackedInstruments, useTrackInstrument,
    │   │                           useUntrackInstrument, useUserInstruments
    │   ├── usePlatforms.ts       ← usePlatforms, usePlatformAccounts,
    │   │                           useCreatePlatformAccount, useUpdatePlatformAccount,
    │   │                           useDeletePlatformAccount
    │   ├── useFollios.ts         ← useFollios, useCreateFollio, useUpdateFollio,
    │   │                           useDeleteFollio
    │   ├── useReports.ts         ← useDashboard, useSpendingTrends,
    │   │                           useInvestmentSummary, usePortfolio
    │   ├── useAuditLogs.ts       ← useAccountAuditLogs, useTermAccountAuditLogs
    │   ├── useCurrency.ts        ← returns formatCurrency() based on user's locale/currency
    │   ├── useDebounce.ts        ← debounce utility hook
    │   └── useTransactionFilters.ts ← manages transaction filter state (type, date range, cursor)
    │
    ├── components/
    │   ├── ui/                   ← shadcn/ui primitives (Button, Card, Input, Label,
    │   │                           Select, Table, Dialog, Form, Badge, Separator,
    │   │                           Skeleton, Popover, Command, etc.)
    │   │
    │   ├── layout/
    │   │   ├── AppShell.tsx      ← Layout route: Sidebar + Header + <Outlet />
    │   │   ├── Sidebar.tsx       ← Nav links (all 9 sections)
    │   │   ├── Header.tsx        ← User display, logout button
    │   │   └── PageHeader.tsx    ← Consistent page title + action button slot
    │   │
    │   ├── auth/
    │   │   └── ProtectedRoute.tsx ← Reads AuthContext; <Navigate to="/login" replace /> if no token
    │   │
    │   ├── transactions/
    │   │   ├── TransactionTable.tsx    ← Cursor-paginated table; credit/debit badge
    │   │   ├── TransactionForm.tsx     ← Create-only; linked account polymorphic select;
    │   │   │                             bank_ref shown only for credit; tags as comma-separated input
    │   │   └── TransactionFilters.tsx  ← type / date range filter bar
    │   │
    │   ├── investments/
    │   │   ├── InvestmentTable.tsx     ← Page-based paginated table filtered by type
    │   │   ├── InvestmentForm.tsx      ← Dynamic fields by investment type; InstrumentCombobox;
    │   │   │                             PlatformAccount select
    │   │   └── InstrumentCombobox.tsx  ← @base-ui/react Popover + searchable list;
    │   │                                 props: value, onChange, filterType
    │   │
    │   └── dashboard/
    │       ├── SummaryCards.tsx        ← Credit / Debit / Account Balance / Portfolio cards
    │       └── SpendingChart.tsx       ← Recharts ComposedChart (bar + line)
    │
    ├── pages/
    │   ├── LoginPage.tsx               ← Public
    │   ├── DashboardPage.tsx           ← Summary cards + spending chart
    │   ├── TransactionsPage.tsx        ← Cursor-paginated transactions + filters + create dialog
    │   ├── InvestmentsPage.tsx         ← Page-based pagination; sticky footer pagination bar
    │   ├── PortfolioPage.tsx           ← Portfolio positions from /reports/portfolio
    │   ├── AccountsPage.tsx            ← Open accounts + term accounts (FD/PPF);
    │   │                                 closed records in separate table below active
    │   ├── PlatformAccountsPage.tsx    ← CRUD for platform accounts
    │   ├── InstrumentsPage.tsx         ← "In Portfolio" table + "Not Yet Invested" table;
    │   │                                 BrowseSheet for infinite-scroll search
    │   ├── FolliosPage.tsx             ← CRUD for follios
    │   └── ReportsPage.tsx             ← Spending trends + investment summary charts/tables
    │
    └── lib/
        ├── utils.ts              ← cn() (clsx + tailwind-merge), shared helpers
        ├── labels.ts             ← TRANSACTION_TYPE_LABELS, INVESTMENT_TYPE_LABELS,
        │                           ACCOUNT_TYPE_LABELS, TERM_ACCOUNT_TYPE_LABELS, etc.
        └── finance.ts            ← calcGainLoss(amountInvested, currentValue)
                                    → { gain, pct, isPositive }
```

### 2.2 Type System

All types in `src/types/index.ts` mirror backend Pydantic schemas exactly. This is the single source of truth for data shapes across the frontend.

#### Enum types

```typescript
export type TransactionType    = 'credit' | 'debit';
export type InvestmentType     = 'stock' | 'mutual_fund';
export type AccountType        = 'savings' | 'current' | 'salary' | 'nre' | 'nro';
export type TermAccountType    = 'fd' | 'ppf';
```

Note: `InvestmentType` is intentionally narrow (`stock | mutual_fund`) — the backend investment model supports more types, but only stocks and mutual funds have active UI support.

#### Transaction types

```typescript
export interface Transaction {
  id: number;
  user_id: number;
  amount: string;                    // Decimal serialised as string
  type: TransactionType;             // 'credit' | 'debit'
  linked_account_type: 'account' | 'term_account' | null;
  linked_account_id: number | null;  // polymorphic FK
  description: string | null;
  date: string;                      // "YYYY-MM-DD"
  bank_ref: string | null;           // UTR/IMPS — only on credit
  tags: string[] | null;             // free-form labels
  is_active: boolean;
  created_at: string;
}

export interface TransactionCreate {
  amount: string;
  type: TransactionType;
  linked_account_type?: 'account' | 'term_account' | null;
  linked_account_id?: number | null;
  description?: string;
  date: string;
  bank_ref?: string | null;
  tags?: string[];
}

// Cursor-based list response
export interface TransactionListResponse {
  items: Transaction[];
  next_cursor: string | null;        // null when no more pages
  limit: number;
}
```

#### Account types

```typescript
export interface Bank {
  id: number;
  name: string;
  short_name: string;                // max 6 chars, display code
}

export interface Account {
  id: number;
  user_id: number;
  bank_id: number;
  bank: Bank;
  account_type: AccountType;
  nickname: string | null;
  balance: string;
  closed_date: string | null;
  closed_amount: string | null;
  created_at: string;
}

export interface AccountCreate { bank_id: number; account_type: AccountType; nickname?: string; }
export interface AccountClose  { closed_date: string; closed_amount: string; }
export type AccountUpdate = Partial<AccountCreate>;

export interface TermAccount {
  id: number;
  user_id: number;
  account_id: number;                // parent savings account
  type: TermAccountType;
  name: string;
  amount: string;
  interest_rate: string | null;
  open_date: string;
  maturity_date: string | null;
  maturity_amount: string | null;
  balance: string;
  closed_date: string | null;
  closed_amount: string | null;
  created_at: string;
}

export interface TermAccountCreate {
  account_id: number;
  type: TermAccountType;
  name: string;
  amount: string;
  interest_rate?: string;
  open_date: string;
  maturity_amount?: string;          // required for PPF; auto-calculated for FD
}

export interface TermAccountClose { closed_date: string; closed_amount: string; }
```

#### Investment types

```typescript
export interface Investment {
  id: number;
  user_id: number;
  type: InvestmentType;
  name: string;
  instrument_id: number | null;      // links to global instruments catalogue
  platform_account_id: number | null;
  amount_invested: string;
  current_value: string | null;
  purchase_date: string;
  notes: string | null;
  // Stock-specific
  ticker_symbol: string | null;
  quantity: string | null;
  avg_buy_price: string | null;
  exchange: string | null;
  // Mutual Fund-specific
  folio_number: string | null;
  units: string | null;
  nav_at_purchase: string | null;
  fund_house: string | null;
  created_at: string;
}

export interface InvestmentListResponse {
  items: Investment[];
  total: number;
  page: number;
  page_size: number;
}
```

#### Instruments, Follios, and Reports

```typescript
export interface Instrument {
  id: number;
  name: string;
  type: InvestmentType;
  ticker_symbol: string | null;
  isin: string | null;
}

// Instrument the current user has explicitly tracked
export interface UserInstrument {
  id: number;
  user_id: number;
  instrument_id: number;
  instrument: Instrument;
  created_at: string;
}

export interface Follio {
  id: number;
  user_id: number;
  name: string;
  description: string | null;
  created_at: string;
}

// Reports
export interface DashboardReport {
  total_credits: string;
  total_debits: string;
  net_balance: string;
  total_invested: string;
  current_portfolio_value: string;
  investment_gain_loss: string;
}

export interface SpendingTrendsReport {
  period_start: string;
  period_end: string;
  monthly_trends: Array<{ month: string; credits: string; debits: string }>;
}

export interface InvestmentSummaryReport {
  total_invested: string;
  total_current_value: string;
  total_gain_loss: string;
  total_gain_loss_pct: number;
  by_type: Array<{ type: string; amount_invested: string; current_value: string; gain_loss: string; count: number }>;
}

export interface PortfolioPosition {
  instrument_id: number;
  instrument: Instrument;
  total_invested: string;
  current_value: string | null;
  gain_loss: string | null;
  gain_loss_pct: number | null;
  quantity: string | null;
}

export interface PortfolioReport {
  positions: PortfolioPosition[];
  total_invested: string;
  total_current_value: string | null;
  total_gain_loss: string | null;
}

export interface AuditLog {
  id: number;
  action: string;
  timestamp: string;
  details: Record<string, unknown> | null;
}
```

### 2.3 API Client Layer

#### `api/client.ts` — Axios instance

```typescript
import axios from "axios";

const client = axios.create({
  baseURL: "/api/v1",
  headers: { "Content-Type": "application/json" },
});

// Attach JWT on every request
client.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// On 401: clear token and redirect to login
client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("access_token");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

export default client;
```

#### `api/transactions.ts` — cursor-based pagination

```typescript
import client from "./client";
import type { Transaction, TransactionCreate, TransactionListResponse } from "../types";

export interface TransactionParams {
  cursor?: string;
  limit?: number;
  type?: 'credit' | 'debit';
  start_date?: string;
  end_date?: string;
}

export const listTransactions = async (
  params: TransactionParams = {}
): Promise<TransactionListResponse> => {
  const { data } = await client.get("/transactions", { params });
  return data;
};

export const createTransaction = async (
  body: TransactionCreate
): Promise<Transaction> => {
  const { data } = await client.post("/transactions", body);
  return data;
};
// No update or delete — transactions are immutable from the API.
// Use the CLI (transactions correct / deactivate) for admin corrections.
```

#### `api/investments.ts` — page-based pagination

```typescript
export const listInvestments = async (
  types?: InvestmentType[],
  page = 1,
  pageSize = 20
): Promise<InvestmentListResponse> => {
  const params: Record<string, unknown> = { page, page_size: pageSize };
  if (types?.length) params.type = types;          // ?type=stock&type=mutual_fund
  const { data } = await client.get("/investments", { params });
  return data;
};
```

The `api/` layer is **pure async functions** — no React, no hooks, no state. Independently testable and reusable outside React Query.

### 2.4 Authentication Flow

#### `context/AuthContext.tsx`

```typescript
interface AuthContextValue {
  token: string | null;
  user: User | null;
  login: (token: string) => void;
  logout: () => void;
  isAuthenticated: boolean;
}

export const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(
    () => localStorage.getItem("access_token")   // initialise from storage
  );
  const [user, setUser] = useState<User | null>(null);

  // On mount (or token change): call /auth/me to populate user profile
  // user.currency_code + user.currency_locale drive useCurrency()
  useEffect(() => {
    if (!token) { setUser(null); return; }
    getMe().then(setUser).catch(() => {
      setToken(null);
      localStorage.removeItem("access_token");
    });
  }, [token]);

  const login = (newToken: string) => {
    localStorage.setItem("access_token", newToken);
    setToken(newToken);
  };

  const logout = () => {
    localStorage.removeItem("access_token");
    setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ token, user, login, logout, isAuthenticated: !!token }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuthContext = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuthContext must be inside AuthProvider");
  return ctx;
};
```

#### Auth flow — Login sequence

```
LoginPage
  │
  ├── User submits {email, password}
  │
  ├── login() from api/auth.ts → POST /api/v1/auth/login
  │   returns { access_token, token_type }
  │
  ├── AuthContext.login(access_token)
  │   ├── localStorage.setItem("access_token", token)
  │   └── setToken(token) → triggers useEffect → getMe() → setUser(user)
  │
  └── navigate("/")  →  DashboardPage
```

#### `components/auth/ProtectedRoute.tsx`

```typescript
import { Navigate, Outlet } from "react-router-dom";
import { useAuthContext } from "../../context/AuthContext";

export function ProtectedRoute() {
  const { isAuthenticated } = useAuthContext();
  return isAuthenticated ? <Outlet /> : <Navigate to="/login" replace />;
}
```

`replace` ensures the login redirect doesn't pollute the browser history stack.

#### `hooks/useCurrency.ts`

```typescript
export function useCurrency() {
  const { user } = useAuthContext();
  const formatCurrency = useCallback(
    (value: string | number | null | undefined): string => {
      if (value == null) return "—";
      return new Intl.NumberFormat(user?.currency_locale ?? "en-IN", {
        style: "currency",
        currency: user?.currency_code ?? "INR",
        minimumFractionDigits: 2,
      }).format(typeof value === "string" ? parseFloat(value) : value);
    },
    [user?.currency_locale, user?.currency_code]
  );
  return { formatCurrency };
}
```

All monetary display in the app uses `formatCurrency` from this hook — never hardcoded `₹` or `"en-IN"`.

### 2.5 React Query Patterns

All server state goes through React Query. Convention: query + mutation hooks live together in domain files under `hooks/`.

#### Query key registry

| Key | Hook | Notes |
|-----|------|-------|
| `['banks']` | `useBanks` | |
| `['accounts']` | `useAccounts` | invalidated by create/update/close/delete account, and create/close term account |
| `['term-accounts']` | `useTermAccounts` | invalidated by create/close term account, and close account |
| `['transactions', params]` | `useTransactions` | params includes cursor, limit, type, date range |
| `['investments', types, page, pageSize]` | `useInvestments` | page-based; types is sorted string[] for cache stability |
| `['instruments', ...]` | `useInfiniteInstruments` | infinite scroll; cursor-based |
| `['instruments/tracked']` | `useTrackedInstruments` | |
| `['instruments/types']` | `useInstrumentTypes` | |
| `['instruments/user-instruments']` | `useUserInstruments` | |
| `['platform-accounts']` | `usePlatformAccounts` | |
| `['follios']` | `useFollios` | |
| `['reports/dashboard']` | `useDashboard` | invalidated on transaction or investment mutation |
| `['reports/spending-trends']` | `useSpendingTrends` | |
| `['reports/investment-summary']` | `useInvestmentSummary` | |
| `['reports/portfolio']` | `usePortfolio` | |

#### `hooks/useTransactions.ts` — cursor-based list

```typescript
export function useTransactions(params: TransactionParams = {}) {
  return useQuery({
    queryKey: ['transactions', params],
    queryFn:  () => listTransactions(params),
    staleTime: 30_000,
    placeholderData: keepPreviousData,    // no flash when cursor changes
  });
}

export function useCreateTransaction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: createTransaction,
    onSuccess: () => {
      // Invalidate all transaction queries (any cursor/filter combination)
      qc.invalidateQueries({ queryKey: ['transactions'] });
      // Balance changes — refresh accounts
      qc.invalidateQueries({ queryKey: ['accounts'] });
      qc.invalidateQueries({ queryKey: ['term-accounts'] });
      // Dashboard totals change
      qc.invalidateQueries({ queryKey: ['reports/dashboard'] });
    },
  });
}
```

#### `hooks/useInvestments.ts` — page-based list

```typescript
export function useInvestments(
  types?: InvestmentType[],
  page = 1,
  pageSize = 20
) {
  // Sort types for stable cache key regardless of caller order
  const sortedTypes = types ? [...types].sort() : undefined;
  return useQuery({
    queryKey: ['investments', sortedTypes, page, pageSize],
    queryFn:  () => listInvestments(types, page, pageSize),
    staleTime: 30_000,
    placeholderData: keepPreviousData,
  });
}
```

#### `hooks/useInstruments.ts` — infinite scroll

```typescript
export function useInfiniteInstruments(search: string, type?: InvestmentType) {
  return useInfiniteQuery({
    queryKey: ['instruments', 'browse', search, type],
    queryFn:  ({ pageParam }) =>
                listInstruments({ cursor: pageParam, limit: 30, search, type }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.next_cursor ?? undefined,
    staleTime: 60_000,
  });
}
```

**Invalidation strategy**: mutations always invalidate by the top-level key prefix — this clears every cached page/filter combination in one call. Dashboard is also invalidated when transactions or investments change.

### 2.6 Form Management

All forms use `react-hook-form` with `zodResolver`. The Zod schema is the single source of field validation rules.

#### `components/transactions/TransactionForm.tsx` — create-only

```typescript
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";

const transactionSchema = z.object({
  amount: z
    .string()
    .min(1, "Amount is required")
    .refine((v) => !isNaN(parseFloat(v)) && parseFloat(v) > 0, "Must be positive"),
  type: z.enum(["credit", "debit"]),
  // Polymorphic linked account — encoded as "account:<id>" or "term_account:<id>"
  linked_account_key: z.string().optional(),
  description: z.string().max(500).optional(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Must be YYYY-MM-DD"),
  bank_ref: z.string().max(100).optional().nullable(),  // credit only
  tags: z.string().optional(),   // comma-separated → string[] on submit
});
```

**Polymorphic account key**: The form combines `accounts` + `term_accounts` into a single select. Each option is keyed as `"account:<id>"` or `"term_account:<id>"`. On submit, the form decodes this key into `linked_account_type` + `linked_account_id` for the API payload.

```typescript
// Decode polymorphic key before submitting
const [linked_account_type, rawId] = values.linked_account_key?.split(":") ?? [];
const payload: TransactionCreate = {
  ...values,
  linked_account_type: (linked_account_type as 'account' | 'term_account') ?? null,
  linked_account_id:   rawId ? parseInt(rawId) : null,
  bank_ref:            values.type === "credit" ? values.bank_ref : null,
  tags:                values.tags?.split(",").map((t) => t.trim()).filter(Boolean) ?? [],
};
```

**`bank_ref` visibility**: Shown only when `type === "credit"` — `watch("type")` drives conditional rendering.

`react-hook-form` keeps all inputs **uncontrolled** — no `useState` per field, no re-render on every keystroke. The form only re-renders on submit or explicit error state.

Transactions are **immutable from the API** — no edit or delete. `TransactionForm` is create-only. Admin corrections use the CLI.

### 2.7 Component Design

#### shadcn/ui usage

shadcn components are **copied into `src/components/ui/`** — not imported from a package. You own the source and can modify primitives without forking a library.

```
components/ui/
  button.tsx      card.tsx       input.tsx      label.tsx
  select.tsx      table.tsx      dialog.tsx     form.tsx
  badge.tsx       separator.tsx  skeleton.tsx   popover.tsx
  command.tsx     sheet.tsx      tooltip.tsx    tabs.tsx
```

#### `InstrumentCombobox` — `@base-ui/react` caveat

`InstrumentCombobox` uses `@base-ui/react` Popover (not Radix UI). **`@base-ui/react` does not support the `asChild` prop** on `PopoverTrigger`. Style the trigger element directly — do not wrap it in another component expecting `asChild`:

```typescript
// CORRECT — style PopoverTrigger directly
<Popover.Trigger className="flex h-9 w-full rounded-md border bg-transparent px-3 py-1 text-sm">
  {selectedInstrument?.name ?? "Search instruments…"}
</Popover.Trigger>

// WRONG — asChild is silently ignored in @base-ui/react
<Popover.Trigger asChild>
  <Button variant="outline">Search instruments…</Button>
</Popover.Trigger>
```

#### `lib/utils.ts` — shared helpers

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

// shadcn standard cn() — merges Tailwind classes without conflicts
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

Currency formatting is handled by `useCurrency()` (locale-aware) rather than a utility function — do not add hardcoded `formatCurrency` to `utils.ts`.

#### `lib/finance.ts` — gain/loss calculation

```typescript
export function calcGainLoss(
  amountInvested: string | number,
  currentValue: string | number | null | undefined
): { gain: number; pct: number; isPositive: boolean } {
  const invested = typeof amountInvested === "string" ? parseFloat(amountInvested) : amountInvested;
  const current  = currentValue != null
    ? (typeof currentValue === "string" ? parseFloat(currentValue) : currentValue)
    : invested;
  const gain = current - invested;
  const pct  = invested !== 0 ? (gain / invested) * 100 : 0;
  return { gain, pct, isPositive: gain >= 0 };
}
```

#### `components/layout/Sidebar.tsx`

```typescript
const navItems = [
  { to: "/",                  label: "Dashboard",       icon: LayoutDashboard },
  { to: "/transactions",      label: "Transactions",    icon: ArrowLeftRight },
  { to: "/investments",       label: "Investments",     icon: TrendingUp },
  { to: "/portfolio",         label: "Portfolio",       icon: PieChart },
  { to: "/accounts",          label: "Bank Accounts",   icon: Landmark },
  { to: "/platform-accounts", label: "Platforms",       icon: Briefcase },
  { to: "/instruments",       label: "Instruments",     icon: BarChart2 },
  { to: "/follios",           label: "Follios",         icon: FolderOpen },
  { to: "/reports",           label: "Reports",         icon: FileBarChart },
];
```

`end={to === "/"}` on the Dashboard link prevents it from matching as active on deeper routes.

### 2.8 Pages

Pages are thin orchestrators — they compose hooks + components, manage local UI state (modal open/close, active page number, filter values), and pass data down. No business logic lives in pages.

#### `pages/AccountsPage.tsx` — two-section pattern

AccountsPage displays four tables across two domain objects, each split by open/closed status:

```
┌─────────────────────────────────────────────┐
│  Open Accounts                              │
│  [savings / current / salary / NRE / NRO]  │
├─────────────────────────────────────────────┤
│  Closed Accounts                            │
│  (shown only if any exist)                  │
├─────────────────────────────────────────────┤
│  Term Accounts — Active  (FD / PPF)         │
├─────────────────────────────────────────────┤
│  Term Accounts — Closed                     │
│  (shown only if any exist)                  │
└─────────────────────────────────────────────┘
```

Closed/inactive records are separated into a **second table below active** — not mixed rows with opacity. The same pattern applies to any page that has a concept of active vs. closed records.

```typescript
const { data: accounts = [] } = useAccounts();
const { data: termAccounts = [] } = useTermAccounts();

const openAccounts   = accounts.filter((a) => !a.closed_date);
const closedAccounts = accounts.filter((a) =>  a.closed_date);
const activeTerms    = termAccounts.filter((t) => !t.closed_date);
const closedTerms    = termAccounts.filter((t) =>  t.closed_date);
```

#### `pages/TransactionsPage.tsx` — cursor navigation

```typescript
export function TransactionsPage() {
  const [cursor, setCursor] = useState<string | undefined>(undefined);
  const { filters, setFilters } = useTransactionFilters();

  const { data, isLoading } = useTransactions({ cursor, limit: 50, ...filters });

  return (
    <div className="flex flex-col h-full">
      <PageHeader title="Transactions">
        <Button onClick={() => setIsFormOpen(true)}>+ Add Transaction</Button>
      </PageHeader>

      <TransactionFilters value={filters} onChange={(f) => { setFilters(f); setCursor(undefined); }} />

      <TransactionTable data={data?.items ?? []} isLoading={isLoading} />

      {/* Cursor navigation */}
      <div className="flex justify-end gap-2 p-4 border-t">
        <Button variant="outline" disabled={!cursor}
          onClick={() => setCursor(undefined)}>First</Button>
        <Button variant="outline" disabled={!data?.next_cursor}
          onClick={() => data?.next_cursor && setCursor(data.next_cursor)}>
          Next
        </Button>
      </div>
    </div>
  );
}
```

When filters change, cursor is reset to `undefined` (first page).

### 2.9 Dashboard & Charts

#### `components/dashboard/SummaryCards.tsx`

```typescript
export function SummaryCards({ data }: { data: DashboardReport }) {
  const { formatCurrency } = useCurrency();
  const { gain, pct, isPositive } = calcGainLoss(data.total_invested, data.current_portfolio_value);

  const cards = [
    { label: "Total Credits",    value: data.total_credits,           color: "text-green-600" },
    { label: "Total Debits",     value: data.total_debits,            color: "text-red-500"   },
    { label: "Net Balance",      value: data.net_balance,             color: "text-blue-600"  },
    { label: "Portfolio",        value: data.current_portfolio_value, color: isPositive ? "text-green-600" : "text-red-500" },
  ];

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map(({ label, value, color }) => (
        <Card key={label}>
          <CardContent className="pt-6">
            <p className="text-sm text-muted-foreground">{label}</p>
            <p className={cn("text-2xl font-bold mt-1", color)}>
              {formatCurrency(value)}
            </p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
```

#### `components/dashboard/SpendingChart.tsx`

```typescript
import {
  ComposedChart, Bar, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from "recharts";

export function SpendingChart({ data }: { data: SpendingTrendsReport['monthly_trends'] }) {
  const { formatCurrency } = useCurrency();
  const chartData = data.map((d) => ({
    month:   format(new Date(d.month + "-01"), "MMM yy"),
    credits: parseFloat(d.credits),
    debits:  parseFloat(d.debits),
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <ComposedChart data={chartData}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="month" />
        <YAxis tickFormatter={(v) => formatCurrency(v)} />
        <Tooltip formatter={(v: number) => formatCurrency(v)} />
        <Legend />
        <Bar  dataKey="debits"  fill="#f87171" name="Debits"  radius={[4,4,0,0]} />
        <Line dataKey="credits" stroke="#4ade80" name="Credits" strokeWidth={2} dot={false} />
      </ComposedChart>
    </ResponsiveContainer>
  );
}
```

### 2.10 Investment Form — Dynamic Fields

`InvestmentForm` uses `react-hook-form`'s `watch("type")` to render type-specific field groups. When the type changes, unmounted fields reset automatically.

Two selectors appear at the bottom regardless of type:
- **InstrumentCombobox** — filtered by the selected `type` via the `filterType` prop
- **Platform Account select** — from `usePlatformAccounts()`; links the investment to a brokerage account

```typescript
const investmentBaseSchema = z.object({
  type:            z.enum(["stock", "mutual_fund"]),
  name:            z.string().min(1),
  amount_invested: z.string().min(1),
  current_value:   z.string().optional(),
  purchase_date:   z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  notes:           z.string().optional(),
  instrument_id:       z.number().nullable().optional(),
  platform_account_id: z.number().nullable().optional(),
});

export function InvestmentForm({ onSuccess }: Props) {
  const form = useForm({ resolver: zodResolver(investmentBaseSchema) });
  const type = form.watch("type") as InvestmentType | undefined;

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <TypeSelector />
        <BaseFields />

        {/* Type-specific fields — conditionally mounted */}
        {type === "stock"       && <StockFields />}
        {type === "mutual_fund" && <MutualFundFields />}

        {/* Always-visible bottom selectors */}
        <InstrumentCombobox filterType={type} ... />
        <PlatformAccountSelect ... />

        <Button type="submit">Save Investment</Button>
      </form>
    </Form>
  );
}
```

`StockFields` and `MutualFundFields` are sub-components that access the parent form via `useFormContext()` — no prop drilling.

### 2.11 Instruments Page — Two-Table Pattern

`InstrumentsPage` shows two tables driven by the intersection of tracked instruments and actual investments:

```
┌────────────────────────────────────────────┐
│  In Portfolio                              │
│  (tracked instruments that have ≥1 investment) │
├────────────────────────────────────────────┤
│  Not Yet Invested                          │
│  (tracked instruments with no investment)  │
└────────────────────────────────────────────┘
```

The split is computed client-side:

```typescript
// Fetch up to 200 investments (backend max) to cover the full portfolio
const { data: investmentsData } = useInvestments(undefined, 1, 200);
const { data: userInstruments  } = useUserInstruments();

const investedInstrumentIds = new Set(
  (investmentsData?.items ?? [])
    .map((inv) => inv.instrument_id)
    .filter(Boolean)
);

const inPortfolio   = (userInstruments ?? []).filter((ui) =>
  investedInstrumentIds.has(ui.instrument_id)
);
const notYetInvested = (userInstruments ?? []).filter((ui) =>
  !investedInstrumentIds.has(ui.instrument_id)
);
```

**`BrowseSheet`** (inline in `InstrumentsPage.tsx`) is a side-sheet for discovering and tracking new instruments. It uses `useInfiniteInstruments` with an `IntersectionObserver` trigger at the bottom of the list:

```typescript
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteInstruments(debouncedSearch, typeFilter);

// Flatten pages
const instruments = data?.pages.flatMap((p) => p.items) ?? [];

// Sentinel element at bottom of list — triggers fetchNextPage when visible
<div ref={sentinelRef} className="h-1" />
{isFetchingNextPage && <Spinner />}
```

Search input is debounced via `useDebounce` (300ms) before updating the query key.

### 2.12 Pagination Patterns

FinTrack uses **two different pagination strategies** depending on the domain:

#### Cursor-based (Transactions, Instruments infinite scroll)

- API sends `next_cursor: string | null` in the response body.
- Client sends `cursor` param on subsequent requests.
- `next_cursor === null` means the last page.
- TransactionsPage stores cursor in local state; resetting to `undefined` returns to page 1.
- Filtering changes always reset cursor to `undefined`.

#### Page-based (Investments)

- API sends `total`, `page`, `page_size` in the response body.
- `InvestmentsPage` has a local `page` state (`useState(1)`).
- The pagination bar is rendered **outside the scroll container** as a sticky footer:

```typescript
export function InvestmentsPage() {
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 20;

  const { data, isLoading } = useInvestments(undefined, page, PAGE_SIZE);
  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 1;

  return (
    // Outer flex column fills viewport height
    <div className="flex flex-col h-full">
      <PageHeader title="Investments">
        <Button onClick={() => setIsFormOpen(true)}>+ Add Investment</Button>
      </PageHeader>

      {/* Scrollable content area — does NOT include pagination bar */}
      <div className="flex-1 overflow-auto p-6">
        <InvestmentTable data={data?.items ?? []} isLoading={isLoading} />
      </div>

      {/* Pagination bar is a sticky footer OUTSIDE the scroll area */}
      <div className="border-t px-6 py-3 flex items-center justify-between shrink-0">
        <span className="text-sm text-muted-foreground">
          Page {page} of {totalPages}
        </span>
        <div className="flex gap-2">
          <Button variant="outline" size="sm"
            disabled={page === 1} onClick={() => setPage((p) => p - 1)}>
            Previous
          </Button>
          <Button variant="outline" size="sm"
            disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
            Next
          </Button>
        </div>
      </div>
    </div>
  );
}
```

### 2.13 Error Handling & Loading States

#### Loading states

React Query provides `isLoading`, `isFetching`, `isError` on every query. Convention:
- `isLoading` (no cached data yet) → render `<Skeleton />` components in the table/card shape
- `isFetching` (background refetch with existing data) → subtle spinner in the component header
- `isError` → inline error message with a retry button

```typescript
function InvestmentTable({ data, isLoading }: Props) {
  if (isLoading) return <TableSkeleton rows={8} cols={6} />;
  if (data.length === 0) return <EmptyState message="No investments yet. Add one to get started." />;
  // ... render table rows
}
```

#### Mutation error handling with sonner toasts

```typescript
import { toast } from "sonner";

const mutation = useCreateTransaction();

const onSubmit = (values: TransactionFormValues) => {
  mutation.mutate(buildPayload(values), {
    onSuccess: () => {
      toast.success("Transaction recorded");
      onClose();
    },
    onError: (error) => {
      // Axios error — extract FastAPI validation detail
      const detail = (error as AxiosError<{ detail: string }>)
        .response?.data?.detail ?? "Something went wrong";
      toast.error(detail);
    },
  });
};
```

sonner renders toast notifications without requiring a `<Toaster>` wrapped around the entire provider tree — mount `<Toaster />` once in `App.tsx`.

#### React 19 Error Boundary

Wrap `AppShell`'s `<Outlet />` in a React error boundary to catch unexpected render errors without crashing the entire app:

```typescript
<ErrorBoundary fallback={<FullPageError />}>
  <Outlet />
</ErrorBoundary>
```

The sidebar and header remain visible — the user can navigate away from the broken page.

### 2.14 Build Configuration

#### `vite.config.ts`

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },  // @ → src/
  },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8000",
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: "dist",
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor:  ["react", "react-dom", "react-router-dom"],
          query:   ["@tanstack/react-query"],
          charts:  ["recharts"],
          ui:      ["lucide-react"],
        },
      },
    },
  },
});
```

`manualChunks` splits the bundle so vendor chunks are cached separately from app code — users only re-download the app chunk on updates.

#### `tsconfig.json` (strict mode)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  }
}
```

`strict: true` enables `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, and others. Combined with `noUnusedLocals` / `noUnusedParameters`, it keeps the codebase clean at compile time.

### 2.15 Styling System

#### Tailwind v4 — CSS-first configuration

Tailwind v4 replaces `tailwind.config.js` with a CSS-first `@theme` block. All design tokens are CSS custom properties:

```css
/* src/index.css */
@import "tailwindcss";

@theme {
  --color-background:        hsl(0 0% 100%);
  --color-foreground:        hsl(222.2 84% 4.9%);
  --color-primary:           hsl(221.2 83.2% 53.3%);
  --color-primary-foreground:hsl(210 40% 98%);
  --color-muted:             hsl(210 40% 96.1%);
  --color-muted-foreground:  hsl(215.4 16.3% 46.9%);
  --color-accent:            hsl(210 40% 96.1%);
  --color-border:            hsl(214.3 31.8% 91.4%);
  --radius:                  0.5rem;
}
```

There is **no `tailwind.config.js`** (or `.ts`) — Tailwind v4 reads the `@theme` block at build time. Attempting to extend the theme via a config file has no effect in v4.

shadcn components reference these tokens via utility classes (`bg-background`, `text-foreground`, `bg-primary`, etc.). Swapping the entire theme is a single CSS file change.

#### Class merging

All dynamic class names go through `cn()` from `lib/utils.ts`:

```typescript
// Correct — twMerge resolves conflicts (p-4 wins over p-2)
<div className={cn("p-2 text-sm", isActive && "bg-accent p-4")} />

// Wrong — Tailwind classes conflict silently without twMerge
<div className={`p-2 text-sm ${isActive ? "bg-accent p-4" : ""}`} />
```

#### `lib/labels.ts` — display label maps

```typescript
export const TRANSACTION_TYPE_LABELS: Record<TransactionType, string> = {
  credit: "Credit",
  debit:  "Debit",
};

export const INVESTMENT_TYPE_LABELS: Record<InvestmentType, string> = {
  stock:       "Stock",
  mutual_fund: "Mutual Fund",
};

export const ACCOUNT_TYPE_LABELS: Record<AccountType, string> = {
  savings: "Savings",
  current: "Current",
  salary:  "Salary",
  nre:     "NRE",
  nro:     "NRO",
};

export const TERM_ACCOUNT_TYPE_LABELS: Record<TermAccountType, string> = {
  fd:  "Fixed Deposit",
  ppf: "PPF",
};
```

Use these maps for table cells and badge labels — never hardcode display strings inline.
