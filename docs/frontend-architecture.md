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
   - 2.11 [Error Handling & Loading States](#211-error-handling--loading-states)
   - 2.12 [Build Configuration](#212-build-configuration)
   - 2.13 [Styling System](#213-styling-system)

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
│  │   Login  Register  Dashboard  Transactions  Investments│  │
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
│   ├── LoginPage
│   └── RegisterPage
│
└── ProtectedRoute  (checks AuthContext → redirects if unauthenticated)
    └── AppShell  (persistent layout: sidebar + header)
        ├── Sidebar  (nav links, active state)
        ├── Header   (user menu, logout)
        └── <Outlet />  (rendered page)
            ├── DashboardPage
            ├── TransactionsPage
            ├── InvestmentsPage
            ├── AccountsPage
            ├── PlatformAccountsPage
            └── InstrumentsPage
```

**Provider stack** (outermost → innermost, defined in `main.tsx`):

```
<QueryClientProvider>        ← TanStack Query cache
  <AuthProvider>             ← JWT state + login/logout
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
| **Server state** | TanStack Query v5 | Transactions list, investments list, dashboard totals, reports — anything that comes from the API |
| **Auth state** | React Context | JWT token, decoded user object, `login()`, `logout()` |

**No global UI state store.** Component-local `useState` handles everything else (modal open/close, filter panel, form dirty state). The rule: if it comes from the server, it belongs in React Query. If it's the current user's identity, it belongs in AuthContext. Everything else is local.

### 1.4 Routing Architecture

React Router v7 with the data router API (`createBrowserRouter`):

```
/login                 → LoginPage              (public)
/register              → RegisterPage           (public)
/                      → DashboardPage          (protected)
/transactions          → TransactionsPage       (protected)
/investments           → InvestmentsPage        (protected)
/accounts              → AccountsPage           (protected)
/platform-accounts     → PlatformAccountsPage   (protected)
/instruments           → InstrumentsPage        (protected)
*                      → NotFoundPage
```

**Route protection pattern:**

```
ProtectedRoute
  └── reads AuthContext
  └── if no token → <Navigate to="/login" replace />
  └── if token    → <Outlet />  (renders nested route)
```

`AppShell` is a layout route wrapping all protected routes. It renders `<Outlet />` in its content area — so the sidebar and header are always mounted, only the page content changes on navigation.

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

Build command: `npm run build` → Vite outputs `frontend/dist/`. FastAPI detects the directory and auto-mounts it.

### 1.6 Tech Stack Rationale

| Concern | Choice | Why |
|---------|--------|-----|
| Build tool | Vite 8 | Near-instant HMR, ES module native, Rollup-based prod build |
| UI framework | React 19 | Concurrent features, stable ecosystem |
| Language | TypeScript 6 | Full type coverage for API shapes matches backend Pydantic schemas |
| Routing | React Router v7 | Data router API; nested layouts with Outlet |
| Server state | TanStack Query v5 | Built-in cache, background refetch, mutation invalidation — eliminates hand-rolled fetch/loading/error boilerplate |
| Forms | react-hook-form + Zod | Uncontrolled inputs = no re-render on keystroke; Zod schema can be shared as source of truth for field validation |
| HTTP client | Axios | Interceptors for auth header + 401 redirect; cleaner than fetch for all JSON APIs |
| Charts | Recharts 3 | Pure React (no D3 imperative code), TypeScript-first, composable primitives |
| UI components | shadcn/ui + Tailwind v4 | Unstyled accessible primitives, full design control, copied into codebase (not a black-box dependency) |
| Icons | lucide-react | Tree-shakeable, consistent style, TypeScript types |
| Date handling | date-fns | Immutable, tree-shakeable, no global locale mutation |

---

## 2. Low-Level Design

### 2.1 Directory Structure

```
frontend/
├── index.html                    ← Vite entry; mounts <div id="root">
├── vite.config.ts                ← Dev proxy + build config
├── tsconfig.json                 ← TypeScript config (strict mode)
├── tailwind.config.ts            ← Tailwind v4 theme
├── components.json               ← shadcn/ui config (paths, style)
│
└── src/
    ├── main.tsx                  ← ReactDOM.createRoot, provider stack
    ├── App.tsx                   ← createBrowserRouter, route definitions
    ├── vite-env.d.ts             ← Vite import.meta.env types
    │
    ├── types/                    ← Shared TypeScript interfaces (mirrors backend schemas)
    │   ├── auth.ts               ← User, Token, LoginRequest, RegisterRequest
    │   ├── transaction.ts        ← Transaction, TransactionCreate, TransactionUpdate, filters
    │   ├── investment.ts         ← Investment, InvestmentCreate subtypes, InvestmentType enum
    │   ├── reports.ts            ← DashboardSummary, MonthlyTrend, InvestmentSummary
    │   └── index.ts              ← AccountType, PlatformType, Bank, Account, Platform,
    │                               PlatformAccount, Instrument, and all Create/Update variants
    │
    ├── api/                      ← Axios call functions (pure async functions, no hooks)
    │   ├── client.ts             ← Axios instance + interceptors
    │   ├── auth.ts               ← login(), register(), getMe(), updateMe()
    │   ├── transactions.ts       ← listTransactions(), createTransaction(), etc.
    │   ├── investments.ts        ← listInvestments(), createInvestment(), etc.
    │   ├── reports.ts            ← getDashboard(), getSpendingTrends(), getInvestmentSummary()
    │   ├── banks.ts              ← listBanks(), listAccounts(), createAccount(), updateAccount(), deleteAccount()
    │   ├── platforms.ts          ← listPlatforms(), listPlatformAccounts(), createPlatformAccount(), etc.
    │   └── instruments.ts        ← listInstruments(), listTrackedInstruments(), createInstrument(),
    │                               trackInstrument(), untrackInstrument()
    │
    ├── context/
    │   └── AuthContext.tsx        ← createContext, AuthProvider, useAuthContext hook
    │
    ├── hooks/                    ← React Query hooks (wrap api/ functions)
    │   ├── useAuth.ts            ← useCurrentUser()
    │   ├── useTransactions.ts    ← useTransactions(), useCreateTransaction(), etc.
    │   ├── useInvestments.ts     ← useInvestments(), useCreateInvestment(), etc.
    │   ├── useReports.ts         ← useDashboard(), useSpendingTrends(), useInvestmentSummary()
    │   ├── useBanks.ts           ← useBanks(), useAccounts(), useCreateAccount(), useUpdateAccount(), useDeleteAccount()
    │   ├── usePlatforms.ts       ← usePlatforms(), usePlatformAccounts(), useCreatePlatformAccount(), etc.
    │   └── useInstruments.ts     ← useInstruments(), useTrackedInstruments(), useCreateInstrument(),
    │                               useTrackInstrument(), useUntrackInstrument()
    │
    ├── components/
    │   ├── ui/                   ← shadcn/ui primitives (Button, Card, Input, Command,
    │   │                           Popover, InputGroup, etc.)
    │   │
    │   ├── layout/
    │   │   ├── AppShell.tsx      ← Layout route: Sidebar + Header + <Outlet />
    │   │   ├── Sidebar.tsx       ← Nav links (Dashboard, Transactions, Investments,
    │   │   │                       Bank Accounts, Platforms, Instruments)
    │   │   └── Header.tsx        ← User display, logout button
    │   │
    │   ├── auth/
    │   │   └── ProtectedRoute.tsx ← Checks AuthContext; redirects to /login if no token
    │   │
    │   ├── transactions/
    │   │   ├── TransactionTable.tsx    ← Table with sort, row actions (edit/delete)
    │   │   ├── TransactionForm.tsx     ← Create/edit form; Bank Account select + Instrument combobox
    │   │   └── TransactionFilters.tsx  ← Type/date range filter bar (category filter removed)
    │   │
    │   ├── investments/
    │   │   ├── InvestmentTable.tsx     ← Table grouped or filtered by type
    │   │   ├── InvestmentForm.tsx      ← Dynamic form + Instrument combobox + Platform Account select
    │   │   └── InstrumentCombobox.tsx  ← Searchable combobox (shadcn Command + @base-ui/react Popover);
    │   │                                 props: value, onChange, filterType
    │   │
    │   └── dashboard/
    │       ├── SummaryCards.tsx        ← Inbound / Outbound / Balance / Portfolio cards
    │       └── SpendingChart.tsx       ← Recharts ComposedChart (bar + line), inbound/outbound keys
    │
    ├── pages/
    │   ├── LoginPage.tsx
    │   ├── RegisterPage.tsx
    │   ├── DashboardPage.tsx
    │   ├── TransactionsPage.tsx
    │   ├── InvestmentsPage.tsx
    │   ├── AccountsPage.tsx            ← CRUD for bank accounts (table + dialog form)
    │   ├── PlatformAccountsPage.tsx    ← CRUD for platform accounts (table + dialog form)
    │   ├── InstrumentsPage.tsx         ← Browse/search instruments; track/untrack; create dialog
    │   └── NotFoundPage.tsx
    │
    └── lib/
        ├── utils.ts              ← cn() (clsx + tailwind-merge), currency/date formatters
        └── labels.ts             ← TRANSACTION_TYPE_LABELS, ACCOUNT_TYPE_LABELS, PLATFORM_TYPE_LABELS
```

### 2.2 Type System

All types in `src/types/` mirror the backend Pydantic schemas exactly. This is the single source of truth for data shapes.

#### `types/transaction.ts`

```typescript
export type TransactionType = "inbound" | "outbound";

// TransactionCategory was removed in the schema redesign

export interface Transaction {
  id: number;
  user_id: number;
  amount: string;            // Decimal serialized as string from backend
  type: TransactionType;
  account_id: number | null;
  instrument_id: number | null;
  description: string | null;
  date: string;              // ISO 8601 date "YYYY-MM-DD"
  notes: string | null;
  created_at: string;        // ISO 8601 datetime
}

export interface TransactionCreate {
  amount: string;
  type: TransactionType;
  account_id?: number | null;
  instrument_id?: number | null;
  description?: string;
  date: string;
  notes?: string;
}

export type TransactionUpdate = Partial<TransactionCreate>;

export interface TransactionFilters {
  page?: number;
  page_size?: number;
  type?: TransactionType;
  start_date?: string;
  end_date?: string;
  sort_by?: "date" | "amount" | "created_at";
  order?: "asc" | "desc";
}

export interface TransactionListResponse {
  items: Transaction[];
  total: number;
  page: number;
  page_size: number;
}
```

#### `types/investment.ts`

```typescript
export type InvestmentType =
  | "stock" | "mutual_fund" | "fixed_deposit"
  | "gold" | "crypto" | "ppf" | "nps" | "real_estate";

// Base fields common to all investment types
interface InvestmentBase {
  type: InvestmentType;
  name: string;
  amount_invested: string;
  current_value?: string;
  purchase_date: string;
  notes?: string;
}

// Type-specific create shapes (used in InvestmentForm)
export interface StockCreate extends InvestmentBase {
  type: "stock";
  ticker_symbol: string;
  quantity: string;
  avg_buy_price: string;
  exchange?: string;
}

export interface MutualFundCreate extends InvestmentBase {
  type: "mutual_fund";
  folio_number?: string;
  units: string;
  nav_at_purchase: string;
  fund_house?: string;
}

export interface FixedDepositCreate extends InvestmentBase {
  type: "fixed_deposit";
  bank_name: string;
  fd_number?: string;
  interest_rate: string;
  tenure_months: number;
  maturity_date?: string;
  maturity_amount?: string;
  compounding?: string;
}

export interface GoldCreate extends InvestmentBase {
  type: "gold";
  gold_form: string;
  weight_grams?: string;
  purity?: string;
}

export interface GenericInvestmentCreate extends InvestmentBase {}

export type InvestmentCreate =
  | StockCreate | MutualFundCreate | FixedDepositCreate
  | GoldCreate | GenericInvestmentCreate;

// Read shape: all fields present, type-specific ones nullable
export interface Investment extends InvestmentBase {
  id: number;
  user_id: number;
  platform_account_id: number | null;
  instrument_id: number | null;
  created_at: string;
  // Stock
  ticker_symbol: string | null;
  quantity: string | null;
  avg_buy_price: string | null;
  exchange: string | null;
  // Mutual Fund
  folio_number: string | null;
  units: string | null;
  nav_at_purchase: string | null;
  fund_house: string | null;
  // Fixed Deposit
  bank_name: string | null;
  fd_number: string | null;
  interest_rate: string | null;
  tenure_months: number | null;
  maturity_date: string | null;
  maturity_amount: string | null;
  compounding: string | null;
  // Gold
  gold_form: string | null;
  weight_grams: string | null;
  purity: string | null;
}

export interface InvestmentListResponse {
  items: Investment[];
  total: number;
  page: number;
  page_size: number;
}
```

#### `types/reports.ts`

```typescript
export interface DashboardSummary {
  total_inbound: string;
  total_outbound: string;
  net_balance: string;
  total_invested: string;
  current_portfolio_value: string;
  investment_gain_loss: string;
}

export interface MonthlyTrend {
  month: string;       // "2026-01"
  inbound: string;
  outbound: string;
}

export interface SpendingTrendsResponse {
  period_start: string;
  period_end: string;
  monthly_trends: MonthlyTrend[];
}

// CategoryBreakdown and CategoryBreakdownResponse were removed in the schema redesign

export interface InvestmentTypeSummary {
  type: string;
  amount_invested: string;
  current_value: string;
  gain_loss: string;
  count: number;
}

export interface InvestmentSummaryResponse {
  total_invested: string;
  total_current_value: string;
  total_gain_loss: string;
  total_gain_loss_pct: number;
  by_type: InvestmentTypeSummary[];
}
```

#### `types/index.ts` — Accounts, Platforms, Instruments

```typescript
export type AccountType = "savings" | "current" | "salary" | "nre" | "nro";
export type PlatformType = "broker" | "mf_platform" | "direct" | "other";

export interface Bank { id: number; name: string; }

export interface Account {
  id: number; user_id: number; bank_id: number; bank: Bank;
  account_type: AccountType; nickname: string | null; created_at: string;
}
export interface AccountCreate { bank_id: number; account_type: AccountType; nickname?: string; }
export type AccountUpdate = Partial<AccountCreate>;

export interface Platform { id: number; name: string; type: PlatformType; }

export interface PlatformAccount {
  id: number; user_id: number; platform_id: number; platform: Platform;
  account_label: string | null; created_at: string;
}
export interface PlatformAccountCreate { platform_id: number; account_label?: string; }
export type PlatformAccountUpdate = Partial<PlatformAccountCreate>;

export interface Instrument {
  id: number; name: string; type: InvestmentType;
  ticker_symbol: string | null; isin: string | null;
}
export interface InstrumentCreate { name: string; type: InvestmentType; ticker_symbol?: string; isin?: string; }
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

#### `api/transactions.ts` — Domain call functions

```typescript
import client from "./client";
import type {
  TransactionCreate, TransactionUpdate,
  TransactionListResponse, Transaction, TransactionFilters
} from "../types/transaction";

// Note: category param was removed from TransactionFilters in the schema redesign
export const listTransactions = async (
  filters: TransactionFilters = {}
): Promise<TransactionListResponse> => {
  const { data } = await client.get("/transactions", { params: filters });
  return data;
};

export const createTransaction = async (
  body: TransactionCreate
): Promise<Transaction> => {
  const { data } = await client.post("/transactions", body);
  return data;
};

export const updateTransaction = async (
  id: number, body: TransactionUpdate
): Promise<Transaction> => {
  const { data } = await client.put(`/transactions/${id}`, body);
  return data;
};

export const deleteTransaction = async (id: number): Promise<void> => {
  await client.delete(`/transactions/${id}`);
};
```

The `api/` layer is **pure async functions** — no React, no hooks, no state. This makes them independently testable with `vitest` and reusable outside React Query if needed.

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

  // Decode JWT payload to get user_id, fetch /auth/me on mount
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

// Convenience hook — throws if used outside AuthProvider
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

### 2.5 React Query Patterns

All server state goes through React Query. Convention: query hooks live in `hooks/`, mutation hooks live alongside them.

#### Query key factory — `hooks/useTransactions.ts`

```typescript
// Query key factory — centralised so invalidation is consistent
export const transactionKeys = {
  all:    () => ["transactions"]                     as const,
  list:   (filters: TransactionFilters) =>
            [...transactionKeys.all(), "list", filters] as const,
  detail: (id: number) =>
            [...transactionKeys.all(), "detail", id]  as const,
};

// List query
export function useTransactions(filters: TransactionFilters = {}) {
  return useQuery({
    queryKey: transactionKeys.list(filters),
    queryFn:  () => listTransactions(filters),
    staleTime: 30_000,    // data considered fresh for 30s
    placeholderData: keepPreviousData,   // no flash on filter change
  });
}

// Create mutation
export function useCreateTransaction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: createTransaction,
    onSuccess: () => {
      // Invalidate all transaction list queries (any filter combination)
      qc.invalidateQueries({ queryKey: transactionKeys.all() });
      // Also invalidate dashboard — totals change
      qc.invalidateQueries({ queryKey: reportKeys.dashboard() });
    },
  });
}

// Delete mutation
export function useDeleteTransaction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: deleteTransaction,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: transactionKeys.all() });
      qc.invalidateQueries({ queryKey: reportKeys.dashboard() });
    },
  });
}
```

**Invalidation strategy**: mutations always invalidate by the `all()` key prefix — this clears every cached filter combination in one call. Dashboard/reports are also invalidated when transactions or investments change, keeping summary cards in sync.

#### `hooks/useReports.ts`

```typescript
export const reportKeys = {
  dashboard:         () => ["reports", "dashboard"]            as const,
  spendingTrends:    (months: number) =>
                       ["reports", "spending-trends", months]  as const,
  // categoryBreakdown key removed — endpoint no longer exists
  investmentSummary: () => ["reports", "investment-summary"]   as const,
};

export function useDashboard() {
  return useQuery({
    queryKey: reportKeys.dashboard(),
    queryFn:  getDashboard,
    staleTime: 60_000,    // dashboard totals can be 1 min stale
  });
}

export function useSpendingTrends(months = 6) {
  return useQuery({
    queryKey: reportKeys.spendingTrends(months),
    queryFn:  () => getSpendingTrends(months),
    staleTime: 60_000,
  });
}

// useCategoryBreakdown was removed — category breakdown report no longer exists
```

### 2.6 Form Management

All forms use `react-hook-form` with a `zodResolver`. The Zod schema is the single source of field validation rules.

#### Transaction form schema (`components/transactions/TransactionForm.tsx`)

```typescript
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";

const transactionSchema = z.object({
  amount: z
    .string()
    .min(1, "Amount is required")
    .refine((v) => !isNaN(parseFloat(v)) && parseFloat(v) > 0, "Must be positive"),
  type: z.enum(["inbound", "outbound"]),
  // category field removed in schema redesign
  account_id:    z.number().nullable().optional(),
  instrument_id: z.number().nullable().optional(),
  description: z.string().max(500).optional(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Must be YYYY-MM-DD"),
  notes: z.string().optional(),
});

type TransactionFormValues = z.infer<typeof transactionSchema>;

function TransactionForm({ onSuccess, defaultValues }: Props) {
  const { data: accounts } = useAccounts();          // Bank Account select
  const form = useForm<TransactionFormValues>({
    resolver: zodResolver(transactionSchema),
    defaultValues: defaultValues ?? { type: "outbound", date: today() },
  });

  const createMutation = useCreateTransaction();

  const onSubmit = (values: TransactionFormValues) => {
    createMutation.mutate(values, { onSuccess });
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        {/* shadcn FormField components */}
      </form>
    </Form>
  );
}
```

`react-hook-form` keeps all inputs **uncontrolled** — no `useState` per field, no re-render on every keystroke. The form only re-renders on submit or explicit error state.

### 2.7 Component Design

#### shadcn/ui usage

shadcn components are **copied into `src/components/ui/`** — not imported from a package. This means you own the source and can modify primitives without forking a library.

```
components/ui/
  button.tsx      card.tsx      input.tsx     label.tsx
  select.tsx      table.tsx     dialog.tsx    form.tsx
  badge.tsx       separator.tsx skeleton.tsx  toast.tsx
```

#### `lib/utils.ts` — shared helpers

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { format } from "date-fns";

// shadcn standard cn() — merges Tailwind classes without conflicts
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Format Decimal string from backend to display currency
export function formatCurrency(value: string | null | undefined): string {
  if (!value) return "₹0.00";
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
  }).format(parseFloat(value));
}

// Format ISO date string to display
export function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  return format(new Date(value), "dd MMM yyyy");
}

// Today's date as YYYY-MM-DD (for form default values)
export function today(): string {
  return format(new Date(), "yyyy-MM-dd");
}
```

#### `components/layout/Sidebar.tsx`

```typescript
import { NavLink } from "react-router-dom";

const navItems = [
  { to: "/",                  label: "Dashboard",       icon: LayoutDashboard },
  { to: "/transactions",      label: "Transactions",    icon: ArrowLeftRight },
  { to: "/investments",       label: "Investments",     icon: TrendingUp },
  { to: "/accounts",          label: "Bank Accounts",   icon: Landmark },
  { to: "/platform-accounts", label: "Platforms",       icon: Briefcase },
  { to: "/instruments",       label: "Instruments",     icon: BarChart2 },
];

export function Sidebar() {
  return (
    <aside className="w-64 border-r h-screen flex flex-col">
      <div className="p-6 font-bold text-xl">FinTrack</div>
      <nav className="flex-1 px-3">
        {navItems.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            className={({ isActive }) =>
              cn("flex items-center gap-3 px-3 py-2 rounded-md text-sm",
                 isActive ? "bg-accent font-medium" : "hover:bg-muted")
            }
          >
            <Icon size={16} />
            {label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
```

`end={to === "/"}` on the Dashboard link prevents it from matching as active on `/transactions`.

### 2.8 Pages

Pages are thin orchestrators — they compose hooks + components, handle local UI state (modal open/close, selected filters), and pass data down. No business logic lives in pages.

#### `pages/TransactionsPage.tsx` — structure

```typescript
export function TransactionsPage() {
  const [filters, setFilters] = useState<TransactionFilters>({});
  const [editTarget, setEditTarget] = useState<Transaction | null>(null);
  const [isFormOpen, setIsFormOpen] = useState(false);

  const { data, isLoading } = useTransactions(filters);

  return (
    <div className="p-6 space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-semibold">Transactions</h1>
        <Button onClick={() => { setEditTarget(null); setIsFormOpen(true); }}>
          + Add Transaction
        </Button>
      </div>

      <TransactionFilters value={filters} onChange={setFilters} />

      <TransactionTable
        data={data?.items ?? []}
        isLoading={isLoading}
        onEdit={(t) => { setEditTarget(t); setIsFormOpen(true); }}
      />

      <Dialog open={isFormOpen} onOpenChange={setIsFormOpen}>
        <TransactionForm
          defaultValues={editTarget ?? undefined}
          onSuccess={() => setIsFormOpen(false)}
        />
      </Dialog>
    </div>
  );
}
```

### 2.9 Dashboard & Charts

#### `components/dashboard/SummaryCards.tsx`

```typescript
export function SummaryCards({ data }: { data: DashboardSummary }) {
  const cards = [
    { label: "Total Inbound",  value: data.total_inbound,           color: "text-green-600" },
    { label: "Total Outbound", value: data.total_outbound,          color: "text-red-500"   },
    { label: "Net Balance",    value: data.net_balance,             color: "text-blue-600"  },
    { label: "Portfolio",      value: data.current_portfolio_value, color: "text-purple-600"},
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

export function SpendingChart({ data }: { data: MonthlyTrend[] }) {
  const chartData = data.map((d) => ({
    month:    format(new Date(d.month + "-01"), "MMM yy"),
    inbound:  parseFloat(d.inbound),
    outbound: parseFloat(d.outbound),
  }));

  return (
    <Card>
      <CardHeader><CardTitle>Inbound vs Outbound</CardTitle></CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <ComposedChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="month" />
            <YAxis tickFormatter={(v) => `₹${(v/1000).toFixed(0)}k`} />
            <Tooltip formatter={(v: number) => formatCurrency(String(v))} />
            <Legend />
            <Bar   dataKey="outbound" fill="#f87171" name="Outbound" radius={[4,4,0,0]} />
            <Line  dataKey="inbound"  stroke="#4ade80" name="Inbound" strokeWidth={2} dot={false} />
          </ComposedChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
```

### 2.10 Investment Form — Dynamic Fields

The investment form uses `react-hook-form`'s `watch("type")` to render the correct field group. When the type changes, the previous type's fields are unmounted — their values reset automatically.

Two additional selectors appear at the bottom of the form regardless of investment type:
- **Instrument combobox** (`InstrumentCombobox`) — searchable, filtered by the currently selected `type` via the `filterType` prop.
- **Platform Account select** — populated from `usePlatformAccounts()`; links the investment to the user's brokerage/platform account.

```typescript
const investmentBaseSchema = z.object({
  type:            z.enum(["stock","mutual_fund","fixed_deposit","gold","crypto","ppf","nps","real_estate"]),
  name:            z.string().min(1),
  amount_invested: z.string().min(1),
  current_value:   z.string().optional(),
  purchase_date:   z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  notes:           z.string().optional(),
});

// Discriminated schema built at runtime
function buildSchema(type: InvestmentType) {
  const base = investmentBaseSchema;
  switch (type) {
    case "stock":
      return base.extend({
        ticker_symbol: z.string().min(1),
        quantity:      z.string().min(1),
        avg_buy_price: z.string().min(1),
        exchange:      z.string().optional(),
      });
    case "fixed_deposit":
      return base.extend({
        bank_name:      z.string().min(1),
        interest_rate:  z.string().min(1),
        tenure_months:  z.coerce.number().int().positive(),
        maturity_date:  z.string().optional(),
        maturity_amount:z.string().optional(),
        compounding:    z.string().optional(),
      });
    // ... other types
    default:
      return base;
  }
}

export function InvestmentForm({ onSuccess }: Props) {
  const form = useForm({ resolver: zodResolver(investmentBaseSchema) });
  const type = form.watch("type") as InvestmentType | undefined;

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        {/* Base fields always rendered */}
        <TypeSelector />
        <BaseFields />

        {/* Type-specific fields — conditionally mounted */}
        {type === "stock"         && <StockFields />}
        {type === "mutual_fund"   && <MutualFundFields />}
        {type === "fixed_deposit" && <FixedDepositFields />}
        {type === "gold"          && <GoldFields />}

        <Button type="submit">Save Investment</Button>
      </form>
    </Form>
  );
}
```

`StockFields`, `MutualFundFields` etc. are small sub-components that use `useFormContext()` to access the parent form — no prop drilling needed.

### 2.11 Error Handling & Loading States

#### Loading states

React Query provides `isLoading`, `isFetching`, `isError` on every query. Convention:
- `isLoading` (no cached data yet) → render `<Skeleton />` components in the table/card shape
- `isFetching` (background refetch) → subtle spinner in top-right of component
- `isError` → inline error message with a retry button

```typescript
function TransactionTable({ data, isLoading }: Props) {
  if (isLoading) return <TableSkeleton rows={5} />;
  if (data.length === 0) return <EmptyState message="No transactions yet." />;
  // ... render table
}
```

#### Mutation error handling

```typescript
const mutation = useCreateTransaction();

const onSubmit = (values) => {
  mutation.mutate(values, {
    onError: (error) => {
      // Axios error — extract FastAPI detail message
      const detail = error.response?.data?.detail ?? "Something went wrong";
      toast.error(detail);
    },
  });
};
```

#### `ErrorBoundary` (React 19)

Wrap `AppShell`'s `<Outlet />` in a React error boundary to catch unexpected render errors without crashing the entire app (sidebar/header remain visible):

```typescript
<ErrorBoundary fallback={<FullPageError />}>
  <Outlet />
</ErrorBoundary>
```

### 2.12 Build Configuration

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
    sourcemap: false,            // disable in prod for smaller output
    rollupOptions: {
      output: {
        manualChunks: {
          vendor:   ["react", "react-dom", "react-router-dom"],
          query:    ["@tanstack/react-query"],
          charts:   ["recharts"],
          ui:       ["lucide-react"],
        },
      },
    },
  },
});
```

`manualChunks` splits the bundle so the vendor chunks are cached separately from app code — users only re-download the app chunk on updates.

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

`strict: true` enables `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes` and others. Combined with `noUnusedLocals` / `noUnusedParameters`, it keeps the codebase clean at compile time.

### 2.13 Styling System

#### Tailwind v4 + shadcn/ui

Tailwind v4 uses a CSS-first config (`@theme` block in a `.css` file) instead of `tailwind.config.js`. Design tokens are CSS custom properties:

```css
/* src/index.css */
@import "tailwindcss";

@theme {
  --color-background: hsl(0 0% 100%);
  --color-foreground: hsl(222.2 84% 4.9%);
  --color-primary: hsl(221.2 83.2% 53.3%);
  --color-primary-foreground: hsl(210 40% 98%);
  --color-muted: hsl(210 40% 96.1%);
  --color-muted-foreground: hsl(215.4 16.3% 46.9%);
  --color-accent: hsl(210 40% 96.1%);
  --color-border: hsl(214.3 31.8% 91.4%);
  --radius: 0.5rem;
}
```

shadcn components reference these tokens via `bg-background`, `text-foreground`, `bg-primary`, etc. — swapping the theme is one CSS file change.

#### Class merging

All dynamic class names go through `cn()` from `lib/utils.ts`:

```typescript
// Correct — twMerge resolves conflicts (e.g. p-4 wins over p-2)
<div className={cn("p-2 text-sm", isActive && "bg-accent p-4")} />

// Wrong — Tailwind classes conflict silently without twMerge
<div className={`p-2 text-sm ${isActive ? "bg-accent p-4" : ""}`} />
```
