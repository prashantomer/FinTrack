import { useMemo, useState } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { PageHeader } from '@/components/layout/PageHeader'
import {
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { usePerformance, usePortfolio } from '@/hooks/useReports'
import { useCurrency } from '@/hooks/useCurrency'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { LotRead, PortfolioPosition } from '@/types'

const TYPE_COLORS: Record<string, string> = {
  stock: '#6366f1',
  mutual_fund: '#10b981',
}

// Stable, theme-friendly palette for the per-platform stacked area.
// Cycles if a user has more platforms than colours.
const PLATFORM_COLORS = [
  '#6366f1', '#10b981', '#f59e0b', '#ef4444',
  '#8b5cf6', '#06b6d4', '#ec4899', '#84cc16',
]

type Window = { label: string; days: number }
const WINDOWS: Window[] = [
  { label: '7d',  days: 7 },
  { label: '30d', days: 30 },
  { label: '90d', days: 90 },
  { label: '1y',  days: 365 },
]

function fmtShortDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

function GainBadge({ value, pct }: { value: number; pct?: number }) {
  const positive = value >= 0
  return (
    <span className={`font-mono text-sm font-medium ${positive ? 'text-green-600' : 'text-red-500'}`}>
      {positive ? '+' : ''}{value.toFixed(2)}
      {pct !== undefined && (
        <span className="ml-1 text-xs opacity-70">({positive ? '+' : ''}{pct.toFixed(1)}%)</span>
      )}
    </span>
  )
}

function LotRow({ lot }: { lot: LotRead }) {
  const { formatCurrency } = useCurrency()
  const cv = lot.current_value ?? lot.amount_invested
  const gain = cv - lot.amount_invested
  return (
    <TableRow className="bg-muted/30 text-xs border-l-2 border-l-primary/20">
      <TableCell className="pl-10 text-muted-foreground">{lot.purchase_date}</TableCell>
      <TableCell className="text-muted-foreground">
        {lot.platform_account_nickname ?? '—'}
      </TableCell>
      <TableCell className="text-muted-foreground text-right font-mono">
        {lot.quantity != null ? `${lot.quantity} u` : lot.units != null ? `${lot.units} u` : '—'}
      </TableCell>
      <TableCell className="text-muted-foreground text-right font-mono">
        {lot.price != null ? formatCurrency(lot.price) : '—'}
      </TableCell>
      <TableCell className="text-right font-mono">{formatCurrency(lot.amount_invested)}</TableCell>
      <TableCell className="text-right">
        <GainBadge value={gain} />
      </TableCell>
      <TableCell />
    </TableRow>
  )
}

function PositionRow({ position }: { position: PortfolioPosition }) {
  const [expanded, setExpanded] = useState(false)
  const { formatCurrency } = useCurrency()

  return (
    <>
      <TableRow
        className="cursor-pointer"
        onClick={() => setExpanded(e => !e)}
      >
        <TableCell className="font-medium">
          <div className="flex items-center gap-2">
            {expanded ? <ChevronDown size={14} className="shrink-0 text-muted-foreground" /> : <ChevronRight size={14} className="shrink-0 text-muted-foreground" />}
            <div>
              <span>{position.instrument_name}</span>
              {position.instrument_ticker && (
                <span className="ml-1.5 text-xs text-muted-foreground font-mono">{position.instrument_ticker}</span>
              )}
            </div>
          </div>
        </TableCell>
        <TableCell className="text-muted-foreground text-sm">
          {position.platform_accounts.join(', ') || '—'}
        </TableCell>
        <TableCell className="text-right font-mono text-sm">
          {position.total_units != null ? position.total_units.toFixed(4) : '—'}
        </TableCell>
        <TableCell className="text-right font-mono text-sm">
          {position.avg_buy_price != null ? formatCurrency(position.avg_buy_price) : '—'}
        </TableCell>
        <TableCell className="text-right font-mono text-sm">{formatCurrency(position.total_invested)}</TableCell>
        <TableCell className="text-right">
          <GainBadge value={position.unrealized_gain} pct={position.unrealized_gain_pct} />
        </TableCell>
        <TableCell className="text-right text-xs text-muted-foreground">{position.total_lots}</TableCell>
      </TableRow>
      {expanded && position.lots.map(lot => <LotRow key={lot.id} lot={lot} />)}
    </>
  )
}

export function PortfolioPage() {
  const qc = useQueryClient()
  const [days, setDays] = useState(90)
  const { data: portfolio, isLoading: portfolioLoading, isFetching: portfolioFetching } = usePortfolio()
  const { data: performance, isFetching: performanceFetching } = usePerformance(days)
  const { formatCurrency, formatCurrencyCompact } = useCurrency()

  const platformNames = useMemo(() => {
    if (!performance?.per_platform_series.length) return [] as string[]
    const names = new Set<string>()
    performance.per_platform_series.forEach((row) => {
      Object.keys(row).forEach((k) => { if (k !== 'date') names.add(k) })
    })
    return Array.from(names).sort()
  }, [performance])

  if (portfolioLoading) return <div className="text-muted-foreground">Loading…</div>

  const empty = !portfolio || portfolio.positions.length === 0

  // Hide fully-exited positions (zero net units) — closed history belongs on Holdings.
  const open = portfolio?.positions.filter(p => !p.is_closed) ?? []
  const stocks = open.filter(p => p.type === 'stock')
  const mfs = open.filter(p => p.type === 'mutual_fund')

  const gainPositive = (portfolio?.unrealized_gain ?? 0) >= 0
  const realizedPositive = (performance?.totals.realized_30d ?? 0) >= 0

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Portfolio"
        description="Aggregated investment positions and performance over time"
        onRefresh={() => {
          qc.invalidateQueries({ queryKey: ['reports', 'portfolio'] })
          qc.invalidateQueries({ queryKey: ['reports', 'performance'] })
        }}
        isRefreshing={portfolioFetching || performanceFetching}
      >
        <div className="flex items-center gap-1 rounded-md border p-0.5 bg-muted/40">
          {WINDOWS.map((w) => (
            <button
              key={w.days}
              onClick={() => setDays(w.days)}
              className={`px-3 py-1 text-xs font-medium rounded transition-colors ${
                days === w.days
                  ? 'bg-background shadow-sm text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              {w.label}
            </button>
          ))}
        </div>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-6">
        {/* Summary cards — current state + 30-day realised */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="pt-5">
              <p className="text-xs text-muted-foreground uppercase tracking-wide">Invested</p>
              <p className="text-2xl font-semibold mt-1 font-mono">{formatCurrency(portfolio?.total_invested ?? 0)}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <p className="text-xs text-muted-foreground uppercase tracking-wide">Current Value</p>
              <p className="text-2xl font-semibold mt-1 font-mono">{formatCurrency(portfolio?.current_value ?? 0)}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <p className="text-xs text-muted-foreground uppercase tracking-wide">Unrealized</p>
              <p className={`text-2xl font-semibold mt-1 font-mono ${gainPositive ? 'text-green-600' : 'text-red-500'}`}>
                {gainPositive ? '+' : ''}{formatCurrency(portfolio?.unrealized_gain ?? 0)}
                <span className="ml-2 text-base font-medium">
                  ({gainPositive ? '+' : ''}{(portfolio?.unrealized_gain_pct ?? 0).toFixed(1)}%)
                </span>
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <p className="text-xs text-muted-foreground uppercase tracking-wide">Realized (30d)</p>
              <p className={`text-2xl font-semibold mt-1 font-mono ${realizedPositive ? 'text-green-600' : 'text-red-500'}`}>
                {realizedPositive ? '+' : ''}{formatCurrency(performance?.totals.realized_30d ?? 0)}
              </p>
            </CardContent>
          </Card>
        </div>

        {empty ? (
          <Card>
            <CardContent className="flex items-center justify-center py-16 text-muted-foreground text-sm">
              No positions yet. Add investments linked to tracked instruments to see your portfolio.
            </CardContent>
          </Card>
        ) : (
          <>
            {/* Net worth time series */}
            <Card>
              <CardHeader><CardTitle className="text-sm">Net Worth</CardTitle></CardHeader>
              <CardContent>
                {!performance || performance.net_worth_series.length === 0 ? (
                  <p className="text-sm text-muted-foreground text-center py-12">
                    No snapshot history yet for this window. Daily snapshots are captured at 05:00 IST.
                  </p>
                ) : (
                  <ResponsiveContainer width="100%" height={240}>
                    <LineChart data={performance.net_worth_series} margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                      <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={fmtShortDate} minTickGap={24} />
                      <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => formatCurrencyCompact(Number(v))} width={64} />
                      <Tooltip
                        formatter={(v) => formatCurrency(Number(v))}
                        labelFormatter={(label) => fmtShortDate(String(label))}
                      />
                      <Line type="monotone" dataKey="value" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
                    </LineChart>
                  </ResponsiveContainer>
                )}
              </CardContent>
            </Card>

            {/* Allocation pie + per-platform stacked area */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <Card>
                <CardHeader><CardTitle className="text-sm">Allocation</CardTitle></CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={240}>
                    <PieChart>
                      <Pie
                        data={portfolio?.by_type ?? []}
                        dataKey="current_value"
                        nameKey="type"
                        cx="50%"
                        cy="50%"
                        innerRadius={55}
                        outerRadius={85}
                        paddingAngle={2}
                        label={(props) => {
                          const type = (props as { type?: string }).type ?? ''
                          const pct  = (props.percent ?? 0) * 100
                          const label = INVESTMENT_TYPE_LABELS[type as keyof typeof INVESTMENT_TYPE_LABELS] ?? type
                          return `${label} ${pct.toFixed(0)}%`
                        }}
                        labelLine={false}
                      >
                        {portfolio?.by_type.map(entry => (
                          <Cell key={entry.type} fill={TYPE_COLORS[entry.type] ?? '#94a3b8'} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(v) => formatCurrency(Number(v))} />
                    </PieChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>

              <Card>
                <CardHeader><CardTitle className="text-sm">By Platform</CardTitle></CardHeader>
                <CardContent>
                  {platformNames.length === 0 ? (
                    <p className="text-sm text-muted-foreground text-center py-12">
                      No snapshot history yet for this window.
                    </p>
                  ) : (
                    <ResponsiveContainer width="100%" height={240}>
                      <AreaChart data={performance?.per_platform_series ?? []} margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
                        <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                        <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={fmtShortDate} minTickGap={24} />
                        <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => formatCurrencyCompact(Number(v))} width={64} />
                        <Tooltip
                          formatter={(v) => formatCurrency(Number(v))}
                          labelFormatter={(label) => fmtShortDate(String(label))}
                        />
                        <Legend wrapperStyle={{ fontSize: 11 }} />
                        {platformNames.map((name, i) => (
                          <Area
                            key={name}
                            type="monotone"
                            dataKey={name}
                            stackId="1"
                            stroke={PLATFORM_COLORS[i % PLATFORM_COLORS.length]}
                            fill={PLATFORM_COLORS[i % PLATFORM_COLORS.length]}
                            fillOpacity={0.4}
                            isAnimationActive={false}
                          />
                        ))}
                      </AreaChart>
                    </ResponsiveContainer>
                  )}
                </CardContent>
              </Card>
            </div>

            {/* Positions */}
            {[
              { label: 'Stocks', positions: stocks },
              { label: 'Mutual Funds', positions: mfs },
            ].map(({ label, positions }) =>
              positions.length === 0 ? null : (
                <div key={label}>
                  <div className="flex items-center gap-2 mb-2">
                    <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">{label}</h2>
                    <Badge variant="secondary">{positions.length}</Badge>
                  </div>
                  <div className="rounded-lg border overflow-hidden">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>Instrument</TableHead>
                          <TableHead>Platform(s)</TableHead>
                          <TableHead className="text-right">Units</TableHead>
                          <TableHead className="text-right">Avg Price</TableHead>
                          <TableHead className="text-right">Invested</TableHead>
                          <TableHead className="text-right">Gain</TableHead>
                          <TableHead className="text-right">Lots</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {positions.map(p => (
                          <PositionRow key={p.user_instrument_id} position={p} />
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                </div>
              )
            )}
          </>
        )}
      </div>
    </div>
  )
}
