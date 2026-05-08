import { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ChevronLeft } from 'lucide-react'
import {
  CartesianGrid, ComposedChart, Legend, Line, LineChart, ResponsiveContainer,
  Scatter, Tooltip, XAxis, YAxis,
} from 'recharts'
import { PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { InstrumentLotsTable } from '@/components/instruments/InstrumentLotsTable'
import {
  useInstrumentLots,
  useInstrumentPosition,
  useInstrumentPriceHistory,
  useInstrumentTransactions,
} from '@/hooks/useInstruments'
import { useQueryClient } from '@tanstack/react-query'
import { useCurrency } from '@/hooks/useCurrency'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { LotRead } from '@/types'

function fmtShortDate(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
}

type Window = { label: string; days: number }
const WINDOWS: Window[] = [
  { label: '7d',  days: 7 },
  { label: '30d', days: 30 },
  { label: '90d', days: 90 },
  { label: '1y',  days: 365 },
  { label: 'All', days: 1825 }, // backend clamps at 5y
]

export function InstrumentProfilePage() {
  const { id } = useParams<{ id: string }>()
  const numericId = id ? Number(id) : null
  const { formatCurrency } = useCurrency()
  const qc = useQueryClient()
  const handleRefresh = () => {
    qc.invalidateQueries({ queryKey: ['instruments', 'profile'] })
  }

  const [days, setDays] = useState(90)
  // Lazy-initialised so render stays pure — the strict react-hooks/purity
  // lint rule blocks Date.now() calls anywhere outside an initializer.
  const [now] = useState(() => Date.now())

  const positionQ  = useInstrumentPosition(numericId)
  const lotsQ      = useInstrumentLots(numericId)
  const txQ        = useInstrumentTransactions(numericId, 50)
  const historyQ   = useInstrumentPriceHistory(numericId, days)

  const position = positionQ.data
  // Memo the array fallbacks — re-creating `[]` every render would invalidate
  // every downstream useMemo that depends on `lots` and `txns` (caught by the
  // strict react-hooks/exhaustive-deps rule).
  const lots = useMemo(() => lotsQ.data ?? [], [lotsQ.data])
  const txns = useMemo(() => txQ.data ?? [], [txQ.data])

  // Numeric timestamp form for Recharts continuous time-axis. Forward-filled
  // map from price_date → price drives both the price chart's marker
  // alignment and the cost-basis-vs-market-value series below.
  const priceData = useMemo(
    () => (historyQ.data ?? []).map(h => ({ ts: new Date(h.date).getTime(), price: h.price })),
    [historyQ.data],
  )

  const priceByDate = useMemo(() => {
    const m = new Map<string, number>()
    for (const h of historyQ.data ?? []) m.set(h.date, h.price)
    return m
  }, [historyQ.data])

  // Window-driven X-axis domain. Even with sparse data, clicking a different
  // pill visibly shifts the axis range — same pattern as PortfolioPage.
  const xDomain = useMemo<[number, number]>(
    () => [now - days * 24 * 60 * 60 * 1000, now],
    [days, now],
  )

  // Buy / sell markers anchored on the price line. Falls back to the lot's
  // own purchase price if the history doesn't have a matching date (weekends,
  // holidays, or instruments with sparse coverage).
  const { buyMarkers, sellMarkers } = useMemo(() => {
    const buys: { ts: number; price: number }[] = []
    const sells: { ts: number; price: number }[] = []
    const start = xDomain[0]
    const end = xDomain[1]
    for (const lot of lots) {
      const ts = new Date(lot.purchase_date).getTime()
      if (ts < start || ts > end) continue
      const price = priceByDate.get(lot.purchase_date) ?? lot.price ?? null
      if (price == null) continue
      const point = { ts, price: Number(price) }
      if (lot.trade_type === 'sell') sells.push(point)
      else buys.push(point)
    }
    return { buyMarkers: buys, sellMarkers: sells }
  }, [lots, priceByDate, xDomain])

  // Cost-basis vs market-value series. Walks lots in chronological order, then
  // for each price-history date emits {cost_basis, market_value} based on the
  // running held qty + cumulative net cash. Skipped when there's no price
  // history (markers + chart hidden together).
  const valueSeries = useMemo(() => {
    if (priceData.length === 0 || lots.length === 0) return [] as Array<{ ts: number; cost_basis: number; market_value: number }>
    const sortedLots = [...lots].sort((a, b) => a.purchase_date.localeCompare(b.purchase_date))
    return priceData.map(({ ts, price }) => {
      let heldQty = 0
      let costBasis = 0
      const dateKey = new Date(ts).toISOString().slice(0, 10)
      for (const lot of sortedLots) {
        if (lot.purchase_date > dateKey) break
        const qty = (lot.quantity ?? lot.units ?? 0)
        const sign = lot.trade_type === 'sell' ? -1 : 1
        heldQty += sign * qty
        costBasis += sign * lot.amount_invested
      }
      return {
        ts,
        cost_basis:   Math.max(costBasis, 0),
        market_value: heldQty * price,
      }
    })
  }, [priceData, lots])

  // 404 from the gate surfaces as a 404 axios error → query.error
  const notFound = positionQ.isError

  if (notFound) {
    return (
      <div className="flex flex-col h-full">
        <PageHeader title="Instrument" description="Not available" onRefresh={handleRefresh} />
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center space-y-2">
            <p className="text-sm text-muted-foreground">This instrument profile is not available.</p>
            <Link
              to="/instruments"
              className="inline-flex items-center gap-1 h-8 px-3 rounded-md border border-border bg-background text-sm hover:bg-muted"
            >
              <ChevronLeft className="size-4" />Back to Instruments
            </Link>
          </div>
        </div>
      </div>
    )
  }

  if (!position) {
    return (
      <div className="flex flex-col h-full">
        <PageHeader title="Instrument" description="Loading…" onRefresh={handleRefresh} />
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title={position.instrument_name}
        description={[
          INVESTMENT_TYPE_LABELS[position.type],
          position.instrument_ticker,
          position.instrument_exchange,
        ].filter(Boolean).join(' · ')}
        onRefresh={handleRefresh}
        isRefreshing={positionQ.isFetching || historyQ.isFetching}
      >
        <div className="flex items-center gap-2">
          <WindowPills value={days} onChange={setDays} />
          <Link
            to="/instruments"
            className="inline-flex items-center gap-1 h-7 px-2.5 rounded-md border border-border bg-background text-[0.8rem] hover:bg-muted"
          >
            <ChevronLeft className="size-3.5" />Back
          </Link>
        </div>
      </PageHeader>

      {/* space-y-4 (not flex-col gap-N) so chart Cards don't get clipped when
       * page content overflows the viewport — see feedback_flex_col_card_clipping. */}
      <div className="flex-1 overflow-auto px-6 py-4 space-y-4">
        {/* Position summary cards */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <SummaryCard label="Invested"     value={formatCurrency(position.total_invested)} />
          <SummaryCard label="Current"      value={formatCurrency(position.current_value)} />
          <SummaryCard
            label="Unrealized"
            value={`${position.unrealized_gain >= 0 ? '+' : ''}${formatCurrency(position.unrealized_gain)}`}
            tone={position.unrealized_gain >= 0 ? 'positive' : 'negative'}
            sub={position.unrealized_gain_pct != null ? `${position.unrealized_gain_pct >= 0 ? '+' : ''}${position.unrealized_gain_pct.toFixed(2)}%` : undefined}
          />
          <SummaryCard
            label="Realized"
            value={`${position.realized_gain >= 0 ? '+' : ''}${formatCurrency(position.realized_gain)}`}
            tone={position.realized_gain >= 0 ? 'positive' : 'negative'}
          />
        </div>

        <div className="text-xs text-muted-foreground flex items-center gap-3 flex-wrap">
          <span>{position.buy_lots} buys / {position.sell_lots} sells</span>
          {position.total_units != null && (
            <span>· Net <span className="font-mono">{position.total_units.toLocaleString('en-IN', { maximumFractionDigits: 4 })}</span> units</span>
          )}
          {position.avg_buy_price != null && (
            <span>· Avg cost {formatCurrency(position.avg_buy_price)}</span>
          )}
          {position.current_price != null && (
            <span>· LTP {formatCurrency(position.current_price)}</span>
          )}
          {position.is_closed && <Badge variant="secondary">closed</Badge>}
        </div>

        {/* Price history chart with buy/sell markers */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">
              Price history
              <span className="ml-2 text-xs font-normal text-muted-foreground">
                {WINDOWS.find(w => w.days === days)?.label ?? `${days}d`}
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            {priceData.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-12">
                No price history captured yet for this instrument.
              </p>
            ) : (
              <ResponsiveContainer width="100%" height={240}>
                <ComposedChart margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                  <XAxis
                    dataKey="ts"
                    type="number"
                    domain={xDomain}
                    scale="time"
                    tick={{ fontSize: 11 }}
                    tickFormatter={(v) => fmtShortDate(new Date(Number(v)).toISOString())}
                    minTickGap={24}
                  />
                  <YAxis tick={{ fontSize: 11 }} width={64} domain={[ 'auto', 'auto' ]} />
                  <Tooltip
                    formatter={(v) => formatCurrency(Number(v))}
                    labelFormatter={(label) => fmtShortDate(new Date(Number(label)).toISOString())}
                  />
                  <Line
                    data={priceData}
                    type="monotone"
                    dataKey="price"
                    stroke="#6366f1"
                    strokeWidth={2}
                    dot={false}
                    isAnimationActive={false}
                    name="Price"
                  />
                  {/* Markers as separate Scatter series so legend disambiguates buy vs sell */}
                  <Scatter
                    data={buyMarkers}
                    dataKey="price"
                    fill="#16a34a"
                    name="Buy"
                    isAnimationActive={false}
                  />
                  <Scatter
                    data={sellMarkers}
                    dataKey="price"
                    fill="#ef4444"
                    name="Sell"
                    isAnimationActive={false}
                  />
                  <Legend wrapperStyle={{ fontSize: 11 }} />
                </ComposedChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        {/* Cost basis vs market value */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Cost basis vs market value</CardTitle>
          </CardHeader>
          <CardContent>
            {valueSeries.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-12">
                Need both price history and lots to compute the value series.
              </p>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <LineChart data={valueSeries} margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                  <XAxis
                    dataKey="ts"
                    type="number"
                    domain={xDomain}
                    scale="time"
                    tick={{ fontSize: 11 }}
                    tickFormatter={(v) => fmtShortDate(new Date(Number(v)).toISOString())}
                    minTickGap={24}
                  />
                  <YAxis tick={{ fontSize: 11 }} width={72} domain={[ 'auto', 'auto' ]} />
                  <Tooltip
                    formatter={(v) => formatCurrency(Number(v))}
                    labelFormatter={(label) => fmtShortDate(new Date(Number(label)).toISOString())}
                  />
                  <Legend wrapperStyle={{ fontSize: 11 }} />
                  <Line type="monotone" dataKey="cost_basis"   stroke="#94a3b8" strokeWidth={2} dot={false} isAnimationActive={false} name="Cost basis" />
                  <Line type="monotone" dataKey="market_value" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} name="Market value" />
                </LineChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        {/* Lots */}
        <Card>
          <CardHeader><CardTitle className="text-sm">Lots</CardTitle></CardHeader>
          <CardContent className="px-0">
            {lotsQ.isLoading ? (
              <p className="text-sm text-muted-foreground py-6 text-center">Loading…</p>
            ) : (
              <InstrumentLotsTable lots={lots as LotRead[]} />
            )}
          </CardContent>
        </Card>

        {/* Linked transactions */}
        <Card>
          <CardHeader><CardTitle className="text-sm">Linked transactions</CardTitle></CardHeader>
          <CardContent className="px-0">
            {txQ.isLoading ? (
              <p className="text-sm text-muted-foreground py-6 text-center">Loading…</p>
            ) : txns.length === 0 ? (
              <p className="text-sm text-muted-foreground py-6 text-center">No linked transactions.</p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[120px]">Date</TableHead>
                    <TableHead className="w-[80px]">Type</TableHead>
                    <TableHead className="text-right">Amount</TableHead>
                    <TableHead>Description</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {txns.map(t => (
                    <TableRow key={t.id}>
                      <TableCell className="text-muted-foreground text-sm">{t.date}</TableCell>
                      <TableCell>
                        <Badge variant={t.type === 'debit' ? 'destructive' : 'default'} className="text-[10px] uppercase">
                          {t.type}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(t.amount)}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">{t.description || '—'}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function WindowPills({ value, onChange }: { value: number; onChange: (days: number) => void }) {
  return (
    <div className="flex items-center gap-1 rounded-md border p-0.5 bg-muted/40">
      {WINDOWS.map((w) => (
        <button
          key={w.days}
          onClick={() => onChange(w.days)}
          className={`px-2.5 py-0.5 text-xs font-medium rounded transition-colors ${
            value === w.days
              ? 'bg-background shadow-sm text-foreground'
              : 'text-muted-foreground hover:text-foreground'
          }`}
        >
          {w.label}
        </button>
      ))}
    </div>
  )
}

function SummaryCard({
  label, value, sub, tone,
}: { label: string; value: string; sub?: string; tone?: 'positive' | 'negative' }) {
  const toneClass = tone === 'positive' ? 'text-green-600' : tone === 'negative' ? 'text-red-500' : ''
  return (
    <Card>
      <CardContent className="py-3">
        <div className="text-xs text-muted-foreground">{label}</div>
        <div className={`text-lg font-mono ${toneClass}`}>{value}</div>
        {sub && <div className={`text-[11px] ${toneClass}`}>{sub}</div>}
      </CardContent>
    </Card>
  )
}
