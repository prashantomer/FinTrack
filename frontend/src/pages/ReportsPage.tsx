import { useState } from 'react'
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import type { ValueType } from 'recharts/types/component/DefaultTooltipContent'
import { useQueryClient } from '@tanstack/react-query'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader } from '@/components/layout/PageHeader'
import { useInvestmentSummary, useSpendingTrends } from '@/hooks/useReports'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import { useCurrency } from '@/hooks/useCurrency'

export function ReportsPage() {
  const qc = useQueryClient()
  const { formatCurrency, formatCurrencyCompact } = useCurrency()
  const tooltipFormatter = (v: ValueType | undefined) => typeof v === 'number' ? formatCurrency(v) : String(v ?? '')
  const [trendMonths, setTrendMonths] = useState('6')
  const { data: trends, isFetching } = useSpendingTrends(Number(trendMonths))
  const { data: invSummary } = useInvestmentSummary()

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Reports"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['reports'] })}
        isRefreshing={isFetching}
      />

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-6">
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base">Transaction Trends</CardTitle>
          <Select value={trendMonths} onValueChange={(v) => v && setTrendMonths(v)}>
            <SelectTrigger className="w-28"><SelectValue /></SelectTrigger>
            <SelectContent>
              {['3','6','12','24'].map(m => <SelectItem key={m} value={m}>{m} months</SelectItem>)}
            </SelectContent>
          </Select>
        </CardHeader>
        <CardContent>
          {trends && trends.months.length === 0 ? (
            <div className="flex items-center justify-center h-[260px] text-sm text-muted-foreground">
              No transactions in this period
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={trends?.months ?? []}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                <XAxis dataKey="month" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} tickFormatter={v => formatCurrencyCompact(Number(v))} />
                <Tooltip formatter={tooltipFormatter} />
                <Bar dataKey="inbound" name="Inbound" fill="#10b981" radius={[3,3,0,0]} />
                <Bar dataKey="outbound" name="Outbound" fill="#ef4444" radius={[3,3,0,0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle className="text-base">Investment Portfolio</CardTitle></CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Type</TableHead>
                <TableHead className="text-right">Invested</TableHead>
                <TableHead className="text-right">Current</TableHead>
                <TableHead className="text-right">Gain</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {invSummary?.holdings.length === 0 && (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-muted-foreground py-8">
                    No investments yet
                  </TableCell>
                </TableRow>
              )}
              {invSummary?.holdings.map(h => (
                <TableRow key={h.type}>
                  <TableCell>{INVESTMENT_TYPE_LABELS[h.type]}</TableCell>
                  <TableCell className="text-right font-mono text-sm">{formatCurrency(h.total_invested)}</TableCell>
                  <TableCell className="text-right font-mono text-sm">{formatCurrency(h.current_value)}</TableCell>
                  <TableCell className={`text-right font-mono text-sm font-medium ${h.unrealized_gain >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                    {h.unrealized_gain >= 0 ? '+' : ''}{formatCurrency(h.unrealized_gain)}
                  </TableCell>
                </TableRow>
              ))}
              {invSummary && invSummary.holdings.length > 0 && (
                <TableRow className="font-semibold border-t-2">
                  <TableCell>Total</TableCell>
                  <TableCell className="text-right font-mono">{formatCurrency(invSummary.total_invested)}</TableCell>
                  <TableCell className="text-right font-mono">{formatCurrency(invSummary.total_current_value)}</TableCell>
                  <TableCell className={`text-right font-mono ${invSummary.total_unrealized_gain >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                    {invSummary.total_unrealized_gain >= 0 ? '+' : ''}{formatCurrency(invSummary.total_unrealized_gain)}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      </div>
    </div>
  )
}
