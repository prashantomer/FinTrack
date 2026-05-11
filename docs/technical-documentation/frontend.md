# Frontend

> React 19 + TypeScript + Vite + TanStack Query + base-ui. The patterns here
> are what's specific to this codebase; standard React/TS conventions are
> assumed.

## Directory layout

```
frontend/src/
├── api/              # Per-domain Axios call functions (one file per backend resource)
│   ├── accounts.ts
│   ├── auth.ts
│   ├── cleanup.ts
│   ├── imports.ts
│   ├── investments.ts
│   ├── transactions.ts
│   └── client.ts     # The single Axios instance
├── components/
│   ├── ui/           # shadcn-style wrappers around base-ui primitives
│   │   ├── button.tsx       # uses base-ui's `render` prop, not Radix asChild
│   │   ├── dialog.tsx
│   │   ├── select.tsx       # narrowed to string values
│   │   ├── sheet.tsx
│   │   └── table.tsx
│   ├── accounts/     # AuditLogSidebar, account form, etc.
│   ├── assistant/    # Chat panel + settings
│   ├── imports/      # ImportWizard (the 5-step flow)
│   ├── investments/  # InvestmentForm + InvestmentCombobox
│   ├── instruments/  # InstrumentLotsTable
│   ├── transactions/ # TransactionForm
│   ├── layout/       # AppShell, PageHeader, SettingsSheet
│   └── landing/      # Illustrations.tsx (inline SVG)
├── context/AuthContext.tsx
├── hooks/            # TanStack Query hooks per domain
│   ├── useAccounts.ts
│   ├── useCleanup.ts
│   ├── useImports.ts
│   ├── useInvestments.ts
│   ├── useTransactions.ts
│   ├── useTransactionFilters.ts   # local filter state, shared between Transactions + Investments pages for page-size constants
│   └── ...
├── lib/              # Pure utilities — formatters, error reporting
│   ├── finance.ts    # currency / number helpers
│   ├── errors.ts     # getErrorMessage
│   └── errorReporter.ts
├── pages/            # One file per route
│   ├── AccountsPage.tsx
│   ├── CleanupPage.tsx
│   ├── DashboardPage.tsx
│   ├── HoldingsPage.tsx
│   ├── ImportsPage.tsx
│   ├── InstrumentProfilePage.tsx
│   ├── InstrumentsPage.tsx
│   ├── InvestmentsPage.tsx
│   ├── PortfolioPage.tsx
│   ├── ReportsPage.tsx
│   ├── TransactionsPage.tsx
│   └── ...
└── types/index.ts    # All shared TS interfaces — mirrors backend serializers
```

## API client

```ts
// src/api/client.ts (paraphrased)
const client = axios.create({ baseURL: '/api/v1' })

client.interceptors.request.use(cfg => {
  const token = localStorage.getItem('token')
  if (token) cfg.headers.Authorization = `Bearer ${token}`
  return cfg
})

client.interceptors.response.use(
  r => r,
  err => {
    if (err.response?.status === 401) {
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)
```

All API calls go through this client. Per-domain files export typed
functions that wrap `client.get` / `post` / etc. — never call `axios`
directly from a component.

## State management

**TanStack Query** owns all server state. Local component state is for UI
toggles only (form values, modal open/closed, expanded rows).

### Query key conventions

```ts
['transactions', params]              // list with filter object
['transactions', id]                  // single
['imports']                           // list (no filter)
['imports', id]                       // single
['accounts']
['audit-logs', target?.type, target?.id]
['instruments', 'profile', 'position', id]
```

When in doubt, look at the existing hook file for the resource — keys are
consistent across read/mutate boundaries so `invalidateQueries` lands.

### Hook patterns

**List with filters:**

```ts
export function useTransactions(params: UseTransactionsParams = {}) {
  return useQuery({
    queryKey: ['transactions', params],
    queryFn: () => listTransactions(params),
  })
}
```

**Mutation with cache invalidation:**

```ts
export function useCreateTransaction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: TransactionCreate) => createTransaction(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['transactions'] })
      qc.invalidateQueries({ queryKey: ['accounts'] })
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      toast.success('Transaction added')
    },
  })
}
```

**Polling for status:**

```ts
export function useImport(id: number | null) {
  return useQuery({
    queryKey: ['imports', id],
    queryFn:  () => getImport(id!),
    enabled:  id != null,
    refetchInterval: q => {
      const status = q.state.data?.status
      return status === 'processing' || status === 'pending' ? 1500 : false
    },
  })
}
```

Polling intervals are kept short (1.5s) for visible progress; longer
intervals (5s+) are fine for ambient health checks.

## Routing

`react-router-dom` v7. `App.tsx`:
- `/` → `LandingPage` (public)
- `/login` → `LoginPage` (public)
- Everything else → wrapped in `ProtectedRoute → AppShell`:
  - `/dashboard`, `/accounts`, `/transactions`, `/platform-accounts`,
    `/instruments`, `/instruments/:id`, `/holdings`, `/investments`,
    `/portfolio`, `/reports`, `/imports`, `/assistant`, `/cleanup`.
- `/*` (inside the shell) → `<Navigate to="/dashboard" replace />`.

Sidebar nav items are declared in `AppShell.tsx`'s `navItems` array; adding
a route means adding both the `<Route>` in `App.tsx` and an entry there.

## base-ui gotchas

**No `asChild`.** Unlike Radix, `@base-ui/react` doesn't have an `asChild`
prop. The `Button` wrapper uses base-ui's `render` prop:

```tsx
// ✅ correct
<Button render={<a href="…" />}>Link</Button>

// ❌ broken — nests elements and breaks layout
<Button asChild><a href="…">Link</a></Button>
```

For links, often just a styled `<Link>` is cleaner than wrapping in Button:

```tsx
<Link
  to="/instruments"
  className="inline-flex items-center gap-1 h-7 px-2.5 rounded-md border border-border bg-background text-[0.8rem] hover:bg-muted"
>
  <ChevronLeft className="size-3.5" />Back
</Link>
```

**`PopoverTrigger` has no styling slot.** Style the trigger directly — no
`asChild` to forward to the inner element.

**Select wrapper is narrowed to `string`.** `components/ui/select.tsx` collapses
base-ui's `string | null` callback to `(value: string) => void` at the
boundary. If you need null support, do it at the call site.

## Strict react-hooks rules

ESLint config enables `react-hooks/purity` and `react-hooks/set-state-in-effect`
as errors. Two patterns this enforces:

**Lazy useState for derived values** — never call `Date.now()` in the render body:

```tsx
// ✅ correct — runs once, render stays pure
const [now] = useState(() => Date.now())

// ❌ purity violation
const now = Date.now()
```

**Key-based remount for "reset state when prop changes"** — never
`useEffect(() => setX(newProp), [newProp])`:

```tsx
// ✅ correct — useState initializer fires fresh on every remount
function EditFormWrapper({ txn }) {
  return <EditForm key={txn.id} txn={txn} />
}

function EditForm({ txn }) {
  const [desc, setDesc] = useState(txn.description ?? '')
  // ...
}
```

## Type contracts with the backend

`src/types/index.ts` holds every interface the frontend consumes. Each
interface mirrors a backend serializer. When you add a field server-side:

1. Edit `<Resource>Serializer#attributes`.
2. Edit the matching interface in `src/types/index.ts`.
3. Both go in the same commit. CI's tsc-strict mode catches the drift if
   you forget either.

## Filters page pattern

Both `TransactionsPage` and `InvestmentsPage` follow the same filter-bar
structure. Look at one before adding the same dimension to another so they
stay visually consistent:

- Search input (debounced 300ms, with X-clear affordance)
- Type select
- Trade / Account / Source selects
- Date range
- Sort dropdown + direction toggle
- "Clear filters" button (only shows when filters are active)

Page size is shared between both pages via constants exported from
`hooks/useTransactionFilters.ts`:

```ts
export const PAGE_SIZE_OPTIONS = [15, 30, 50, 100] as const
export const DEFAULT_PAGE_SIZE = 30
```

## Page chrome alignment

Every routed page wraps its content in:

```tsx
<div className="flex flex-col h-full">
  <PageHeader title="..." description="..." onRefresh={...} />
  <div className="flex-1 min-h-0 px-6 py-6 flex flex-col gap-4 overflow-hidden">
    {/* filter bar */}
    {/* scrollable content region: flex-1 min-h-0 rounded-lg border overflow-auto */}
  </div>
  {/* optional footer pinned outside the overflow region */}
</div>
```

The `min-h-0` is critical — without it, flex children with `overflow-auto`
expand past the parent and the page-level scroll takes over instead of the
intended inner scroll.

`PageHeader` is locked to `h-14`, matching the sidebar's top row, so the
grid stays aligned across pages. Don't stack title + description on
separate lines — inline them with a `·` separator.

## Charts (Recharts 3)

Used in `PortfolioPage`, `DashboardPage`, `ReportsPage`, `InstrumentProfilePage`.

Common patterns:
- Numeric `ts` keys (Unix ms) for continuous time-axis, formatted via
  `tickFormatter`.
- `width="100%"` on `ResponsiveContainer`, fixed `height` (240px is the
  default in this codebase).
- Tooltip formatters use `useCurrency()` to respect the user's locale.
- Animation off (`isAnimationActive={false}`) — feels snappier and avoids
  React 19's strict-mode double-render artifacts.

Bundle size warning: the SPA bundle is currently >1MB minified. Recharts
is the biggest contributor. Don't add per-page chart imports lazily yet —
the warning is acknowledged, not actionable.

## Build

```bash
cd frontend
npm run dev     # http://localhost:5173 (proxies /api, /rails, /sidekiq → :8000)
npm run build   # → frontend/dist/
npx tsc --noEmit
npm run lint
```

Vite proxies in `vite.config.ts` are env-aware: `VITE_BACKEND_URL` overrides
the default `http://localhost:8000` (used by Docker compose to point at
`http://backend:8000` over the compose network).

---

Last reviewed: 2026-05-11
