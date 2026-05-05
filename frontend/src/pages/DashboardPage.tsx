import { useCallback, useState } from 'react'

import { ArrowDownRight, ArrowUpRight, Landmark, RefreshCw, TrendingUp, Wallet } from 'lucide-react'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import {
  Bar, CartesianGrid, ComposedChart, Line,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts'
import type { ValueType } from 'recharts/types/component/DefaultTooltipContent'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useDashboard, useDashboardCacheStatus, useRefreshDashboard, useSpendingTrends } from '@/hooks/useReports'
import { ACCOUNT_TYPE_LABELS, INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import { formatCurrency, formatCurrencyCompact } from '@/lib/currency'
import type { AccountSummary, InvestmentTypeBreakdown, RecentTransaction, TermAccountSummary } from '@/types'

const fmt = { format: formatCurrency }
const fmtCompact = formatCurrencyCompact
const fmtDate = (iso: string) => new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
const tooltipFmt = (v: ValueType | undefined) => typeof v === 'number' ? fmt.format(v) : String(v ?? '')

function relativeTime(ts: number): string {
  const secs = Math.floor((Date.now() - ts) / 1000)
  if (secs < 5) return 'just now'
  if (secs < 60) return `${secs}s ago`
  const mins = Math.floor(secs / 60)
  if (mins < 60) return `${mins}m ago`
  return `${Math.floor(mins / 60)}h ago`
}

const INVESTMENT_COLORS: Record<string, string> = {
  stock: '#6366f1',
  mutual_fund: '#8b5cf6',
  fixed_deposit: '#3b82f6',
  gold: '#f59e0b',
  crypto: '#f97316',
  ppf: '#10b981',
  nps: '#14b8a6',
  real_estate: '#64748b',
}

// ── Stat card ────────────────────────────────────────────────────────────────

function StatCard({
  title, value, icon: Icon, sub, trend,
}: {
  title: string
  value: string
  icon: React.ElementType
  sub?: string
  trend?: { label: string; positive: boolean }
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <Icon size={16} className="text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {sub && <p className="text-xs text-muted-foreground mt-1">{sub}</p>}
        {trend && (
          <p className={`text-xs font-medium mt-1 flex items-center gap-0.5 ${trend.positive ? 'text-green-600' : 'text-red-500'}`}>
            {trend.positive ? <ArrowUpRight size={12} /> : <ArrowDownRight size={12} />}
            {trend.label}
          </p>
        )}
      </CardContent>
    </Card>
  )
}

// ── Account balances ─────────────────────────────────────────────────────────

function AccountBalancesCard({ accounts, total }: { accounts: AccountSummary[]; total: number }) {
  return (
    <Card className="flex flex-col">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Bank Accounts</CardTitle>
      </CardHeader>
      <CardContent className="flex-1 p-0">
        {accounts.map((a) => (
          <div key={a.id} className="flex items-center justify-between px-6 py-3 border-b last:border-0">
            <div className="min-w-0">
              <p className="text-sm font-medium truncate">{a.nickname}</p>
              <p className="text-xs text-muted-foreground">
                {a.bank_short_name}
                <span className="mx-1 opacity-40">·</span>
                {ACCOUNT_TYPE_LABELS[a.account_type as keyof typeof ACCOUNT_TYPE_LABELS] ?? a.account_type}
              </p>
            </div>
            <p className={`text-sm font-mono font-semibold shrink-0 ml-4 ${a.balance >= 0 ? 'text-green-600' : 'text-red-500'}`}>
              {fmt.format(a.balance)}
            </p>
          </div>
        ))}
        {accounts.length === 0 && (
          <p className="text-sm text-muted-foreground px-6 py-4">No active accounts</p>
        )}
        <div className="flex items-center justify-between px-6 py-3 bg-muted/40">
          <p className="text-xs font-medium text-muted-foreground">Total</p>
          <p className="text-sm font-bold">{fmt.format(total)}</p>
        </div>
      </CardContent>
    </Card>
  )
}

// ── Portfolio breakdown ──────────────────────────────────────────────────────

function PortfolioCard({
  holdings, total,
}: {
  holdings: InvestmentTypeBreakdown[]
  total: number
}) {
  return (
    <Card className="flex flex-col">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Portfolio Breakdown</CardTitle>
      </CardHeader>
      <CardContent className="flex-1 p-0">
        {holdings.map((h) => {
          const pct = total > 0 ? (h.current_value / total) * 100 : 0
          const color = INVESTMENT_COLORS[h.type as string] ?? '#94a3b8'
          return (
            <div key={h.type as string} className="px-6 py-3 border-b last:border-0">
              <div className="flex items-center justify-between mb-1.5">
                <div className="flex items-center gap-2 min-w-0">
                  <span className="w-2 h-2 rounded-full shrink-0" style={{ backgroundColor: color }} />
                  <span className="text-sm font-medium truncate">
                    {INVESTMENT_TYPE_LABELS[h.type as keyof typeof INVESTMENT_TYPE_LABELS]}
                  </span>
                  <span className="text-xs text-muted-foreground shrink-0">{h.count}×</span>
                </div>
                <div className="text-right shrink-0 ml-4">
                  <p className="text-sm font-mono font-semibold">{fmt.format(h.current_value)}</p>
                  <p className={`text-xs ${h.unrealized_gain >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                    {h.unrealized_gain >= 0 ? '+' : ''}{fmt.format(h.unrealized_gain)}
                  </p>
                </div>
              </div>
              <div className="h-1 bg-border rounded-full overflow-hidden">
                <div className="h-full rounded-full" style={{ width: `${pct.toFixed(1)}%`, backgroundColor: color }} />
              </div>
            </div>
          )
        })}
        {holdings.length === 0 && (
          <p className="text-sm text-muted-foreground px-6 py-4">No investments</p>
        )}
        <div className="flex items-center justify-between px-6 py-3 bg-muted/40">
          <p className="text-xs font-medium text-muted-foreground">Total</p>
          <p className="text-sm font-bold">{fmt.format(total)}</p>
        </div>
      </CardContent>
    </Card>
  )
}

// ── Cash flow chart ──────────────────────────────────────────────────────────

function CashFlowCard() {
  const [months, setMonths] = useState(6)
  const { data: trends } = useSpendingTrends(months)

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm">Monthly Cash Flow</CardTitle>
        <div className="flex gap-1">
          {[3, 6, 12].map((m) => (
            <Button
              key={m}
              size="sm"
              variant={months === m ? 'default' : 'ghost'}
              className="h-6 px-2 text-xs"
              onClick={() => setMonths(m)}
            >
              {m}M
            </Button>
          ))}
        </div>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={220}>
          <ComposedChart data={trends?.months ?? []} barGap={2}>
            <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
            <XAxis dataKey="month" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} tickFormatter={fmtCompact} width={52} />
            <Tooltip formatter={tooltipFmt} />
            <Bar dataKey="inbound" name="In" fill="#10b981" radius={[2, 2, 0, 0]} />
            <Bar dataKey="outbound" name="Out" fill="#ef4444" radius={[2, 2, 0, 0]} />
            <Line type="monotone" dataKey="net" name="Net" stroke="#6366f1" strokeWidth={2} dot={false} />
          </ComposedChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}

// ── Recent transactions ──────────────────────────────────────────────────────

function RecentTransactionsCard({ transactions }: { transactions: RecentTransaction[] }) {
  return (
    <Card className="flex flex-col">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Recent Transactions</CardTitle>
      </CardHeader>
      <CardContent className="flex-1 p-0">
        {transactions.map((t) => (
          <div key={t.id} className="flex items-start justify-between px-6 py-3 border-b last:border-0 gap-3">
            <div className="min-w-0 flex-1">
              <p className="text-sm truncate">
                {t.description || (t.tags.length ? t.tags.join(', ') : '—')}
              </p>
              <div className="flex items-center gap-1.5 mt-0.5 flex-wrap">
                <span className="text-xs text-muted-foreground">{fmtDate(t.date)}</span>
                {t.tags.length > 0 && t.description && t.tags.map((tag) => (
                  <span key={tag} className="text-xs bg-muted px-1.5 py-0.5 rounded">{tag}</span>
                ))}
              </div>
            </div>
            <p className={`text-sm font-mono font-semibold shrink-0 ${t.type === 'credit' ? 'text-green-600' : 'text-red-500'}`}>
              {t.type === 'credit' ? '+' : '−'}{fmt.format(t.amount)}
            </p>
          </div>
        ))}
        {transactions.length === 0 && (
          <p className="text-sm text-muted-foreground px-6 py-4">No transactions yet</p>
        )}
      </CardContent>
    </Card>
  )
}

// ── Upcoming maturities ──────────────────────────────────────────────────────

function UpcomingMaturitiesCard({ maturities }: { maturities: TermAccountSummary[] }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Upcoming Maturities <span className="text-muted-foreground font-normal">(next 90 days)</span></CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Account</TableHead>
              <TableHead>Bank</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Matures</TableHead>
              <TableHead className="text-right">Days</TableHead>
              <TableHead className="text-right">Balance</TableHead>
              <TableHead className="text-right">Payout</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {maturities.map((ta) => (
              <TableRow key={ta.id}>
                <TableCell className="font-mono text-sm">{ta.account_number || '—'}</TableCell>
                <TableCell className="text-sm">{ta.bank_short_name}</TableCell>
                <TableCell>
                  <Badge variant={ta.type === 'fd' ? 'default' : 'secondary'}>
                    {ta.type.toUpperCase()}
                  </Badge>
                </TableCell>
                <TableCell className="text-sm text-muted-foreground">{ta.maturity_date}</TableCell>
                <TableCell className={`text-right font-mono text-sm font-semibold ${ta.days_remaining <= 14 ? 'text-orange-500' : 'text-muted-foreground'}`}>
                  {ta.days_remaining}d
                </TableCell>
                <TableCell className="text-right font-mono text-sm">{fmt.format(ta.balance)}</TableCell>
                <TableCell className="text-right font-mono text-sm text-green-600">
                  {ta.maturity_amount != null ? fmt.format(ta.maturity_amount) : '—'}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

// ── Page ─────────────────────────────────────────────────────────────────────

export function DashboardPage() {
  const [, forceRender] = useState(0)

  const { data: dash, dataUpdatedAt, isFetching } = useDashboard()
  const { mutate: refreshCache, isPending: isRefreshing } = useRefreshDashboard()
  const { data: cacheStatus } = useDashboardCacheStatus()

  const handleRefresh = useCallback(() => {
    refreshCache(undefined, { onSettled: () => forceRender(n => n + 1) })
  }, [refreshCache])

  const thisMonthNet = dash?.this_month_net ?? 0
  const prevMonthNet = (dash?.prev_month_inbound ?? 0) - (dash?.prev_month_outbound ?? 0)
  const momDelta = thisMonthNet - prevMonthNet
  const momLabel = prevMonthNet !== 0
    ? `${momDelta >= 0 ? '+' : ''}${fmt.format(momDelta)} vs last month`
    : `${fmt.format(thisMonthNet)} this month`

  const gainPct = dash && dash.total_invested > 0
    ? ((dash.unrealized_gain / dash.total_invested) * 100).toFixed(1)
    : null

  return (
    <div className="flex flex-col gap-5">
      {/* ── Header ── */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <h1 className="text-2xl font-semibold">Dashboard</h1>

        <div className="flex items-center gap-3 flex-wrap">
          {/* Cache status */}
          {cacheStatus && (
            <Popover>
              <PopoverTrigger asChild>
                <button className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors">
                  <span className={`w-1.5 h-1.5 rounded-full ${
                    !cacheStatus.redis_connected ? 'bg-zinc-400' :
                    cacheStatus.cache_warm ? 'bg-green-500' : 'bg-yellow-400'
                  }`} />
                  {!cacheStatus.redis_connected ? 'No cache' :
                   cacheStatus.cache_warm
                     ? `Cached · ${cacheStatus.cache_ttl_seconds != null ? `${Math.ceil(cacheStatus.cache_ttl_seconds / 60)}m left` : ''}`
                     : 'Cache cold'}
                </button>
              </PopoverTrigger>
              <PopoverContent align="end" className="w-52 text-xs space-y-2 p-4">
                <p className="font-medium text-sm">Cache Status</p>
                <div className="space-y-1.5 text-muted-foreground">
                  <div className="flex justify-between">
                    <span>Redis</span>
                    <span className={cacheStatus.redis_connected ? 'text-green-600' : 'text-red-500'}>
                      {cacheStatus.redis_connected ? 'Connected' : 'Disconnected'}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Cache</span>
                    <span className={cacheStatus.cache_warm ? 'text-green-600' : 'text-yellow-600'}>
                      {cacheStatus.cache_warm ? `Warm · ${cacheStatus.cache_ttl_seconds}s TTL` : 'Cold'}
                    </span>
                  </div>
                </div>
                <p className="text-muted-foreground pt-1">Use Refresh to update cache.</p>
              </PopoverContent>
            </Popover>
          )}

          {/* Last updated */}
          {dataUpdatedAt > 0 && (
            <span className="text-xs text-muted-foreground tabular-nums" key={dataUpdatedAt}>
              Updated {relativeTime(dataUpdatedAt)}
            </span>
          )}

          {/* Manual refresh */}
          <Button
            size="sm"
            variant="outline"
            className="h-7 px-3 gap-1.5"
            onClick={handleRefresh}
            disabled={isRefreshing || isFetching}
          >
            <RefreshCw size={12} className={(isRefreshing || isFetching) ? 'animate-spin' : ''} />
            <span className="text-xs">Refresh</span>
          </Button>
        </div>
      </div>

      {/* ── Stat cards ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Net Worth"
          value={fmt.format(dash?.net_worth ?? 0)}
          icon={Wallet}
          sub={`${fmt.format((dash?.accounts_balance ?? 0) + (dash?.term_accounts_balance ?? 0))} cash · ${fmt.format(dash?.portfolio_value ?? 0)} invested`}
        />
        <StatCard
          title="Cash Balance"
          value={fmt.format(dash?.accounts_balance ?? 0)}
          icon={Landmark}
          sub={dash && dash.term_accounts_balance > 0 ? `+ ${fmt.format(dash.term_accounts_balance)} in FD / PPF` : undefined}
        />
        <StatCard
          title="This Month"
          value={fmt.format(thisMonthNet)}
          icon={thisMonthNet >= 0 ? ArrowUpRight : ArrowDownRight}
          sub={`↑ ${fmt.format(dash?.this_month_inbound ?? 0)} · ↓ ${fmt.format(dash?.this_month_outbound ?? 0)}`}
          trend={prevMonthNet !== 0 ? { label: momLabel, positive: momDelta >= 0 } : undefined}
        />
        <StatCard
          title="Portfolio"
          value={fmt.format(dash?.portfolio_value ?? 0)}
          icon={TrendingUp}
          sub={`${fmt.format(dash?.total_invested ?? 0)} invested`}
          trend={
            dash && dash.total_invested > 0
              ? {
                  label: `${dash.unrealized_gain >= 0 ? '+' : ''}${fmt.format(dash.unrealized_gain)} (${gainPct}%)`,
                  positive: (dash.unrealized_gain ?? 0) >= 0,
                }
              : undefined
          }
        />
      </div>

      {/* ── Accounts + Portfolio ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <AccountBalancesCard
          accounts={dash?.accounts ?? []}
          total={dash?.accounts_balance ?? 0}
        />
        <PortfolioCard
          holdings={dash?.investment_holdings ?? []}
          total={dash?.portfolio_value ?? 0}
        />
      </div>

      {/* ── Cash flow + Recent transactions ── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2">
          <CashFlowCard />
        </div>
        <RecentTransactionsCard transactions={dash?.recent_transactions ?? []} />
      </div>

      {/* ── Upcoming maturities ── */}
      {(dash?.upcoming_maturities?.length ?? 0) > 0 && (
        <UpcomingMaturitiesCard maturities={dash!.upcoming_maturities} />
      )}
    </div>
  )
}
