import { useState } from 'react'
import { ChevronLeft, ChevronRight, Pencil, Plus, Search, X } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { PageHeader } from '@/components/layout/PageHeader'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { InvestmentForm } from '@/components/investments/InvestmentForm'
import { useCreateInvestment, useFilteredInvestments, useUpdateInvestment } from '@/hooks/useInvestments'
import { useCurrency } from '@/hooks/useCurrency'
import { useDebounce } from '@/hooks/useDebounce'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Investment, InvestmentType, TradeType } from '@/types'

const PAGE_SIZE = 15
const ALL_TYPES: InvestmentType[] = ['stock', 'mutual_fund']

export function InvestmentsPage() {
  const qc = useQueryClient()
  const { formatCurrency } = useCurrency()
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Investment | null>(null)
  const [page, setPage] = useState(1)
  const [typeFilter, setTypeFilter] = useState<InvestmentType | undefined>(undefined)
  const [tradeTypeFilter, setTradeTypeFilter] = useState<TradeType | undefined>(undefined)
  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const debouncedSearch = useDebounce(search, 300)

  const { data, isLoading, isFetching } = useFilteredInvestments({
    type:       typeFilter ? [typeFilter] : undefined,
    trade_type: tradeTypeFilter,
    search:     debouncedSearch || undefined,
    date_from:  dateFrom || undefined,
    date_to:    dateTo || undefined,
    page,
    page_size:  PAGE_SIZE,
  })

  const filtersActive = !!(typeFilter || tradeTypeFilter || debouncedSearch || dateFrom || dateTo)
  function clearFilters() {
    setTypeFilter(undefined); setTradeTypeFilter(undefined)
    setSearch(''); setDateFrom(''); setDateTo('')
    setPage(1)
  }
  const createMutation = useCreateInvestment()
  const updateMutation = useUpdateInvestment()

  const investments = data?.items ?? []
  const total = data?.total ?? 0

  async function handleSubmit(values: Partial<Investment> & {
    type: InvestmentType; name: string; amount_invested: number; purchase_date: string
  }) {
    if (editing) {
      await updateMutation.mutateAsync({ id: editing.id, data: values })
    } else {
      await createMutation.mutateAsync(values)
      setPage(1)
    }
    setOpen(false)
    setEditing(null)
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Investments"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['investments'] })}
        isRefreshing={isFetching}
      >
        <Button onClick={() => { setEditing(null); setOpen(true) }}><Plus size={16} className="mr-1" />Add</Button>
      </PageHeader>

      <div className="flex-1 min-h-0 px-6 py-6 flex flex-col gap-4 overflow-hidden">
        <div className="flex flex-wrap items-end gap-3 shrink-0">
          <div className="relative flex-1 min-w-[260px] max-w-md">
            <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1) }}
              placeholder="Search by name, order ID, trade ID, or public ID…"
              className="pl-8 pr-8"
            />
            {search && (
              <button
                onClick={() => { setSearch(''); setPage(1) }}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                title="Clear search"
              >
                <X size={14} />
              </button>
            )}
          </div>

          <Select
            value={typeFilter ?? 'all'}
            onValueChange={v => { setTypeFilter(v === 'all' ? undefined : v as InvestmentType); setPage(1) }}
          >
            <SelectTrigger className="w-40"><SelectValue placeholder="All Types" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
              {ALL_TYPES.map(t => (
                <SelectItem key={t} value={t}>{INVESTMENT_TYPE_LABELS[t]}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Select
            value={tradeTypeFilter ?? 'all'}
            onValueChange={v => { setTradeTypeFilter(v === 'all' ? undefined : v as TradeType); setPage(1) }}
          >
            <SelectTrigger className="w-32"><SelectValue placeholder="Trade" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Trades</SelectItem>
              <SelectItem value="buy">Buy</SelectItem>
              <SelectItem value="sell">Sell</SelectItem>
            </SelectContent>
          </Select>

          <div className="flex items-center gap-1.5 text-xs">
            <Input
              type="date"
              value={dateFrom}
              onChange={e => { setDateFrom(e.target.value); setPage(1) }}
              className="w-[140px]"
              title="From date"
            />
            <span className="text-muted-foreground">→</span>
            <Input
              type="date"
              value={dateTo}
              onChange={e => { setDateTo(e.target.value); setPage(1) }}
              className="w-[140px]"
              title="To date"
            />
          </div>

          {filtersActive && (
            <Button variant="ghost" size="sm" onClick={clearFilters} className="gap-1">
              <X size={14} /> Clear
            </Button>
          )}
        </div>

        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="flex-1 min-h-0 rounded-lg border overflow-auto">
            <Table>
              <TableHeader className="sticky top-0 z-10 bg-muted/60 backdrop-blur supports-[backdrop-filter]:bg-muted/70 [&_th]:shadow-[inset_0_-1px_0_var(--border)]">
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Trade</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead className="text-right">Qty / Units</TableHead>
                  <TableHead className="text-right">Price</TableHead>
                  <TableHead className="text-right">Amount</TableHead>
                  <TableHead className="text-right">Current Value</TableHead>
                  <TableHead className="text-right">Gain / Loss</TableHead>
                  <TableHead>Order ID</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {investments.map(inv => {
                  const isSell  = inv.trade_type === 'sell'
                  // Live values use instrument.last_price × qty. Falls back to
                  // the row's own current_value (rarely populated) or amount_invested.
                  const live    = inv.live_current_value ?? inv.current_value ?? null
                  const gain    = inv.live_gain ?? (live != null ? (live - inv.amount_invested) : null)
                  const pct     = inv.live_gain_pct ?? (gain != null && inv.amount_invested > 0 ? (gain / inv.amount_invested) * 100 : null)
                  const isPositive = (gain ?? 0) >= 0
                  return (
                    <TableRow key={inv.id}>
                      <TableCell className="font-medium group">
                        <div className="flex flex-col leading-tight">
                          <div className="flex items-center gap-1.5">
                            <span>{inv.name}</span>
                            {inv.source === 'imported' && (
                              <span
                                className="text-[9px] uppercase tracking-wide text-muted-foreground bg-muted px-1 py-0.5 rounded"
                                title="Imported via CSV — read-only"
                              >
                                imp
                              </span>
                            )}
                            {inv.source === 'manual' && (
                              <button
                                onClick={() => { setEditing(inv); setOpen(true) }}
                                className="ml-1 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-foreground"
                                title="Edit notes"
                              >
                                <Pencil size={11} />
                              </button>
                            )}
                          </div>
                          {inv.instrument_last_price != null && (
                            <span className="text-[10px] text-muted-foreground font-mono">
                              LTP ₹{new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 4 }).format(inv.instrument_last_price)}
                            </span>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant={isSell ? 'destructive' : 'default'} className="text-[10px] uppercase">
                          {inv.trade_type}
                        </Badge>
                      </TableCell>
                      <TableCell><Badge variant="outline">{INVESTMENT_TYPE_LABELS[inv.type]}</Badge></TableCell>
                      <TableCell className="text-muted-foreground text-sm">{inv.purchase_date}</TableCell>
                      <TableCell className="text-right font-mono text-sm">
                        {(inv.quantity ?? inv.units) != null
                          ? (inv.quantity ?? inv.units)!.toLocaleString('en-IN', { maximumFractionDigits: 4 })
                          : <span className="text-muted-foreground">—</span>}
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm text-muted-foreground">
                        {inv.price != null ? formatCurrency(inv.price) : '—'}
                      </TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(inv.amount_invested)}</TableCell>
                      <TableCell className="text-right font-mono text-muted-foreground">
                        {isSell ? '—' : (live != null ? formatCurrency(live) : <span className="text-muted-foreground/60">—</span>)}
                      </TableCell>
                      <TableCell className={`text-right font-mono font-medium ${isSell || gain == null ? 'text-muted-foreground' : (isPositive ? 'text-green-600' : 'text-red-500')}`}>
                        {isSell || gain == null
                          ? '—'
                          : `${isPositive ? '+' : ''}${formatCurrency(gain)}${pct != null ? ` (${pct.toFixed(2)}%)` : ''}`}
                      </TableCell>
                      <TableCell className="font-mono text-xs text-muted-foreground">
                        {inv.order_id || inv.trade_id ? (
                          <div className="flex flex-col leading-tight">
                            <span>{inv.order_id || '—'}</span>
                            {inv.trade_id && <span className="opacity-60">trade · {inv.trade_id}</span>}
                          </div>
                        ) : '—'}
                      </TableCell>
                    </TableRow>
                  )
                })}
                {investments.length === 0 && (
                  <TableRow><TableCell colSpan={10} className="text-center text-muted-foreground py-8">No investments yet</TableCell></TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        )}
      </div>

      {total > PAGE_SIZE && (
        <div className="border-t px-6 py-3 flex items-center justify-between text-sm shrink-0">
          <span className="text-muted-foreground">{total} total</span>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => setPage(p => p - 1)} disabled={page === 1}>
              <ChevronLeft size={14} />Prev
            </Button>
            <span className="text-muted-foreground px-1">Page {page}</span>
            <Button variant="outline" size="sm" onClick={() => setPage(p => p + 1)} disabled={investments.length < PAGE_SIZE}>
              Next<ChevronRight size={14} />
            </Button>
          </div>
        </div>
      )}
      {total > 0 && total <= PAGE_SIZE && (
        <p className="text-center text-xs text-muted-foreground py-2 border-t shrink-0">{total} investments</p>
      )}

      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="right" className="w-[480px] sm:max-w-[520px] flex flex-col p-0 overflow-hidden">
          <SheetHeader className="border-b px-6 py-5 shrink-0">
            <SheetTitle className="text-base">{editing ? 'Edit Investment' : 'New Investment'}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto px-6 py-5">
            <InvestmentForm
              initial={editing ?? undefined}
              notesOnly={!!editing}
              onSubmit={handleSubmit}
              onCancel={() => { setOpen(false); setEditing(null) }}
            />
          </div>
        </SheetContent>
      </Sheet>
    </div>
  )
}
