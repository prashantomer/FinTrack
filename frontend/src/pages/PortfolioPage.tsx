import { useState } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { PageHeader } from '@/components/layout/PageHeader'
import {
  Bar,
  BarChart,
  Cell,
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
import { usePortfolio } from '@/hooks/useReports'
import { useCurrency } from '@/hooks/useCurrency'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { LotRead, PortfolioPosition } from '@/types'

const TYPE_COLORS: Record<string, string> = {
  stock: '#6366f1',
  mutual_fund: '#10b981',
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
        {lot.buy_price != null
          ? formatCurrency(lot.buy_price)
          : lot.nav_at_purchase != null
          ? formatCurrency(lot.nav_at_purchase)
          : '—'}
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
        className="cursor-pointer hover:bg-muted/50 transition-colors"
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
  const { data, isLoading, isFetching } = usePortfolio()
  const { formatCurrency, formatCurrencyCompact } = useCurrency()

  if (isLoading) return <div className="text-muted-foreground">Loading…</div>

  const empty = !data || data.positions.length === 0

  const stocks = data?.positions.filter(p => p.type === 'stock') ?? []
  const mfs = data?.positions.filter(p => p.type === 'mutual_fund') ?? []

  const gainPositive = (data?.unrealized_gain ?? 0) >= 0

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Portfolio"
        description="Aggregated positions across all investments"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['reports', 'portfolio'] })}
        isRefreshing={isFetching}
      />

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-3 gap-4">
        <Card>
          <CardContent className="pt-5">
            <p className="text-xs text-muted-foreground uppercase tracking-wide">Invested</p>
            <p className="text-2xl font-semibold mt-1 font-mono">{formatCurrency(data?.total_invested ?? 0)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-5">
            <p className="text-xs text-muted-foreground uppercase tracking-wide">Current Value</p>
            <p className="text-2xl font-semibold mt-1 font-mono">{formatCurrency(data?.current_value ?? 0)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-5">
            <p className="text-xs text-muted-foreground uppercase tracking-wide">Gain / Loss</p>
            <p className={`text-2xl font-semibold mt-1 font-mono ${gainPositive ? 'text-green-600' : 'text-red-500'}`}>
              {gainPositive ? '+' : ''}{formatCurrency(data?.unrealized_gain ?? 0)}
              <span className="ml-2 text-base font-medium">
                ({gainPositive ? '+' : ''}{(data?.unrealized_gain_pct ?? 0).toFixed(1)}%)
              </span>
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
          {/* Charts */}
          <div className="grid grid-cols-2 gap-4">
            <Card>
              <CardHeader><CardTitle className="text-sm">Allocation</CardTitle></CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={200}>
                  <PieChart>
                    <Pie
                      data={data?.by_type ?? []}
                      dataKey="current_value"
                      nameKey="type"
                      cx="50%"
                      cy="50%"
                      innerRadius={55}
                      outerRadius={85}
                      paddingAngle={2}
                      label={({ type, percent }) =>
                        `${INVESTMENT_TYPE_LABELS[type as keyof typeof INVESTMENT_TYPE_LABELS]} ${(percent * 100).toFixed(0)}%`
                      }
                      labelLine={false}
                    >
                      {data?.by_type.map(entry => (
                        <Cell key={entry.type} fill={TYPE_COLORS[entry.type] ?? '#94a3b8'} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(v: number) => formatCurrency(v)} />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            <Card>
              <CardHeader><CardTitle className="text-sm">By Platform</CardTitle></CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart
                    data={data?.by_platform ?? []}
                    layout="vertical"
                    margin={{ left: 8, right: 16 }}
                  >
                    <XAxis type="number" tick={{ fontSize: 11 }} tickFormatter={v => formatCurrencyCompact(Number(v))} />
                    <YAxis type="category" dataKey="platform_name" tick={{ fontSize: 11 }} width={72} />
                    <Tooltip formatter={(v: number) => formatCurrency(v)} />
                    <Legend />
                    <Bar dataKey="total_invested" name="Invested" fill="#94a3b8" radius={[0, 3, 3, 0]} />
                    <Bar dataKey="current_value" name="Current" fill="#6366f1" radius={[0, 3, 3, 0]} />
                  </BarChart>
                </ResponsiveContainer>
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
