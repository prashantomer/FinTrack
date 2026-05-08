import { useMemo, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  LineChart,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { PageHeader } from '@/components/layout/PageHeader'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useCurrency } from '@/hooks/useCurrency'
import { usePerformance } from '@/hooks/useReports'

type Window = { label: string; days: number }
const WINDOWS: Window[] = [
  { label: '7d',  days: 7 },
  { label: '30d', days: 30 },
  { label: '90d', days: 90 },
  { label: '1y',  days: 365 },
]

// Stable, theme-friendly palette for stacked platform series. Cycles if the
// user has more platforms than colours — fine, charts read OK on collisions.
const PLATFORM_COLORS = [
  '#6366f1', // indigo
  '#10b981', // emerald
  '#f59e0b', // amber
  '#ef4444', // red
  '#8b5cf6', // violet
  '#06b6d4', // cyan
  '#ec4899', // pink
  '#84cc16', // lime
]

function fmtShortDate(iso: string) {
  const d = new Date(iso)
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

export function PerformancePage() {
  const [days, setDays] = useState(90)
  const { data, isLoading } = usePerformance(days)
  const { formatCurrency, formatCurrencyCompact } = useCurrency()
  const qc = useQueryClient()

  const platformNames = useMemo(() => {
    if (!data?.per_platform_series.length) return [] as string[]
    const names = new Set<string>()
    data.per_platform_series.forEach((row) => {
      Object.keys(row).forEach((k) => { if (k !== 'date') names.add(k) })
    })
    return Array.from(names).sort()
  }, [data])

  const totals = data?.totals
  const realizedPositive = (totals?.realized_30d ?? 0) >= 0
  const unrealizedPositive = (totals?.unrealized_gain ?? 0) >= 0

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <PageHeader
        title="Performance"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['reports', 'performance'] })}
        isRefreshing={isLoading}
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

      <div className="flex-1 overflow-auto p-6 space-y-4">
        {isLoading ? (
          <div className="text-sm text-muted-foreground">Loading…</div>
        ) : !data || data.net_worth_series.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center text-sm text-muted-foreground">
              No snapshot data yet for the selected window. Daily snapshots are
              captured at 05:00 IST — come back tomorrow.
            </CardContent>
          </Card>
        ) : (
          <>
            <Card>
              <CardContent className="py-4 px-6 flex flex-wrap items-center gap-x-8 gap-y-2 text-sm">
                <div>
                  <div className="text-xs text-muted-foreground">Current Value</div>
                  <div className="text-xl font-semibold tabular-nums">
                    {formatCurrency(totals?.current_value ?? 0)}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground">Unrealized</div>
                  <div className={`text-xl font-semibold tabular-nums ${unrealizedPositive ? 'text-green-600' : 'text-red-500'}`}>
                    {unrealizedPositive ? '+' : ''}{formatCurrency(totals?.unrealized_gain ?? 0)}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground">Realized (30d)</div>
                  <div className={`text-xl font-semibold tabular-nums ${realizedPositive ? 'text-green-600' : 'text-red-500'}`}>
                    {realizedPositive ? '+' : ''}{formatCurrency(totals?.realized_30d ?? 0)}
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Net Worth</CardTitle>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={260}>
                  <LineChart data={data.net_worth_series} margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                    <XAxis
                      dataKey="date"
                      tick={{ fontSize: 11 }}
                      tickFormatter={fmtShortDate}
                      minTickGap={24}
                    />
                    <YAxis
                      tick={{ fontSize: 11 }}
                      tickFormatter={(v) => formatCurrencyCompact(Number(v))}
                      width={64}
                    />
                    <Tooltip
                      formatter={(v) => formatCurrency(Number(v))}
                      labelFormatter={(label) => fmtShortDate(String(label))}
                    />
                    <Line
                      type="monotone"
                      dataKey="value"
                      stroke="#6366f1"
                      strokeWidth={2}
                      dot={false}
                      isAnimationActive={false}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {platformNames.length > 0 && (
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">By Platform</CardTitle>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={260}>
                    <AreaChart data={data.per_platform_series} margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                      <XAxis
                        dataKey="date"
                        tick={{ fontSize: 11 }}
                        tickFormatter={fmtShortDate}
                        minTickGap={24}
                      />
                      <YAxis
                        tick={{ fontSize: 11 }}
                        tickFormatter={(v) => formatCurrencyCompact(Number(v))}
                        width={64}
                      />
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
                </CardContent>
              </Card>
            )}
          </>
        )}
      </div>
    </div>
  )
}
