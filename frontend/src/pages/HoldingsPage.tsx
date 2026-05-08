import { useMemo, useState } from 'react'
import { Check, ChevronLeft, ChevronRight, Loader2, Pencil, Search, X } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { PageHeader } from '@/components/layout/PageHeader'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { usePortfolio } from '@/hooks/useReports'
import { useUpdateInstrumentFolio } from '@/hooks/useInvestments'
import { useCurrency } from '@/hooks/useCurrency'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { InvestmentType, LotRead, PortfolioPosition } from '@/types'

const PAGE_SIZE    = 19
const ALL_ACCOUNTS = '__all__'

type Filter = 'all' | InvestmentType
type Status = 'active' | 'closed' | 'all'

const TYPE_TABS: { label: string; value: Filter }[] = [
  { label: 'All',          value: 'all' },
  { label: 'Stocks',       value: 'stock' },
  { label: 'Mutual Funds', value: 'mutual_fund' },
]

const STATUS_TABS: { label: string; value: Status }[] = [
  { label: 'Active',   value: 'active' },
  { label: 'Closed',   value: 'closed' },
  { label: 'All',      value: 'all' },
]

function isClosed(p: PortfolioPosition): boolean {
  return (p.total_units ?? 0) <= 0.0001
}

// All P&L / LT-ST math now lives server-side in
// `Reports::PortfolioService` + `Holdings::PositionCalculator`. Frontend just
// reads `position.long_term_units`, `position.short_term_units`, and
// `lot.pnl`.

export function HoldingsPage() {
  const qc = useQueryClient()
  const { formatCurrency } = useCurrency()
  const { data, isLoading, isFetching } = usePortfolio()
  const [type, setType] = useState<Filter>('all')
  const [status, setStatus] = useState<Status>('active')
  const [platformAccount, setPlatformAccount] = useState<string>(ALL_ACCOUNTS)
  const [search, setSearch] = useState<string>('')
  const [page, setPage] = useState(1)
  const [selectedPosition, setSelectedPosition] = useState<PortfolioPosition | null>(null)

  // Account options narrow to positions that match the active type + status
  // tabs — so picking "Stocks" hides MF-only accounts and vice versa.
  const platformOptions = useMemo<string[]>(() => {
    const set = new Set<string>()
    for (const p of data?.positions ?? []) {
      if (type !== 'all' && p.type !== type) continue
      if (status === 'active' && isClosed(p)) continue
      if (status === 'closed' && !isClosed(p)) continue
      for (const pa of p.platform_accounts) set.add(pa)
    }
    return Array.from(set).sort()
  }, [data, type, status])

  // If the user's platform-account selection isn't in the narrowed options
  // (e.g. they picked an MF account, then switched to Stocks), fall back to
  // "all" during render — keeps the user's intent in state without forcing
  // a re-render via setState-in-effect.
  const effectivePlatformAccount = useMemo(
    () => (platformAccount === ALL_ACCOUNTS || platformOptions.includes(platformAccount))
      ? platformAccount
      : ALL_ACCOUNTS,
    [platformAccount, platformOptions]
  )

  const filtered = useMemo<PortfolioPosition[]>(() => {
    const positions = data?.positions ?? []
    const q = search.trim().toLowerCase()
    return positions.filter(p => {
      if (type !== 'all' && p.type !== type) return false
      if (status === 'active' && isClosed(p)) return false
      if (status === 'closed' && !isClosed(p)) return false
      if (effectivePlatformAccount !== ALL_ACCOUNTS && !p.platform_accounts.includes(effectivePlatformAccount)) return false
      if (q.length > 0) {
        const haystack = [
          p.instrument_name,
          p.instrument_ticker,
          p.folio_number,
        ].filter(Boolean).join(' ').toLowerCase()
        if (!haystack.includes(q)) return false
      }
      return true
    })
  }, [data, type, status, effectivePlatformAccount, search])

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  // Clamp the page in case the filter changed and current page is now beyond the new total
  const safePage   = Math.min(page, totalPages)
  const paged      = useMemo(() => filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE), [filtered, safePage])

  const totals = useMemo(() => {
    const live  = filtered.reduce((sum, p) => sum + p.current_value, 0)
    const inv   = filtered.reduce((sum, p) => sum + p.total_invested, 0)
    const unrl  = filtered.reduce((sum, p) => sum + p.unrealized_gain, 0)
    const real  = filtered.reduce((sum, p) => sum + (p.realized_gain ?? 0), 0)
    return { live, inv, unrl, real }
  }, [filtered])

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Holdings"
        description="Net position per instrument — aggregated from all your trades"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['reports', 'portfolio'] })}
        isRefreshing={isFetching}
      />

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-4">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex gap-1 border-b">
            {TYPE_TABS.map(tab => (
              <button
                key={tab.value}
                onClick={() => { setType(tab.value); setPage(1) }}
                className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors -mb-px ${
                  type === tab.value
                    ? 'border-primary text-primary'
                    : 'border-transparent text-muted-foreground hover:text-foreground'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-3 flex-wrap">
            <div className="relative">
              <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
              <Input
                value={search}
                onChange={(e) => { setSearch(e.target.value); setPage(1) }}
                placeholder="Search name / ticker / folio…"
                className="h-8 w-[260px] pl-7 pr-7 text-xs"
              />
              {search && (
                <button
                  type="button"
                  onClick={() => { setSearch(''); setPage(1) }}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  aria-label="Clear search"
                >
                  <X size={13} />
                </button>
              )}
            </div>
            <Select
              value={effectivePlatformAccount}
              onValueChange={(v) => { setPlatformAccount(v); setPage(1) }}
            >
              <SelectTrigger className="h-8 w-[220px] text-xs">
                <SelectValue>
                  {effectivePlatformAccount === ALL_ACCOUNTS ? 'All platform accounts' : effectivePlatformAccount}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL_ACCOUNTS}>All platform accounts</SelectItem>
                {platformOptions.map(name => (
                  <SelectItem key={name} value={name}>{name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <div className="flex items-center gap-1 rounded-md border p-0.5 bg-muted/40">
              {STATUS_TABS.map(tab => (
                <button
                  key={tab.value}
                  onClick={() => { setStatus(tab.value); setPage(1) }}
                  className={`px-3 py-1 text-xs font-medium rounded transition-colors ${
                    status === tab.value
                      ? 'bg-background shadow-sm text-foreground'
                      : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="rounded-lg border overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[280px] min-w-[280px] max-w-[280px]">Instrument</TableHead>
                  <TableHead>Ticker / Folio</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead className="text-right">Lots</TableHead>
                  <TableHead className="text-right">Net Units</TableHead>
                  <TableHead className="text-right">Avg Cost</TableHead>
                  <TableHead className="text-right">Net Invested</TableHead>
                  <TableHead className="text-right">Current Value</TableHead>
                  <TableHead className="text-right">Unrealized</TableHead>
                  <TableHead className="text-right">Realized</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {paged.map(p => {
                  const closed = isClosed(p)
                  // Stocks → ticker. MFs → position.folio_number (server-derived from latest
                  // buy lot); fall back to "Set folio…" hint that opens the position sheet.
                  const folio = p.type === 'mutual_fund' ? p.folio_number : null
                  return (
                    <TableRow
                      key={p.user_instrument_id}
                      onClick={() => setSelectedPosition(p)}
                      className={`cursor-pointer ${closed ? 'opacity-60' : ''}`}
                    >
                      <TableCell className="font-medium w-[280px] min-w-[280px] max-w-[280px]">
                        <div className="overflow-x-auto whitespace-nowrap no-scrollbar" title={p.instrument_name}>
                          {p.instrument_name}
                        </div>
                      </TableCell>
                      <TableCell className="font-mono text-xs text-muted-foreground">
                        {p.type === 'stock' ? (
                          p.instrument_ticker || '—'
                        ) : folio ? (
                          folio
                        ) : (
                          <span className="italic text-muted-foreground/70">Set folio…</span>
                        )}
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">{INVESTMENT_TYPE_LABELS[p.type]}</Badge>
                        {closed && <Badge variant="secondary" className="ml-1.5">closed</Badge>}
                      </TableCell>
                      <TableCell className="text-right text-xs text-muted-foreground tabular-nums">
                        {p.buy_lots}B / {p.sell_lots}S
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm">
                        {p.total_units != null ? p.total_units.toLocaleString('en-IN', { maximumFractionDigits: 4 }) : '—'}
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm text-muted-foreground">
                        {p.avg_buy_price != null ? formatCurrency(p.avg_buy_price) : '—'}
                      </TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(p.total_invested)}</TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(p.current_value)}</TableCell>
                      <TableCell className={`text-right font-mono font-medium ${p.unrealized_gain >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                        {p.unrealized_gain >= 0 ? '+' : ''}{formatCurrency(p.unrealized_gain)}
                        <span className="text-xs text-muted-foreground ml-1">({p.unrealized_gain_pct.toFixed(1)}%)</span>
                      </TableCell>
                      <TableCell className={`text-right font-mono ${(p.realized_gain ?? 0) === 0 ? 'text-muted-foreground' : (p.realized_gain ?? 0) >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                        {p.realized_gain == null || p.realized_gain === 0 ? '—' : `${p.realized_gain > 0 ? '+' : ''}${formatCurrency(p.realized_gain)}`}
                      </TableCell>
                    </TableRow>
                  )
                })}
                {filtered.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={10} className="text-center text-muted-foreground py-8">
                      No {status === 'closed' ? 'closed' : status === 'active' ? 'active' : ''} holdings{type !== 'all' ? ` in ${INVESTMENT_TYPE_LABELS[type]}` : ''}.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        )}
      </div>

      {filtered.length > 0 && (
        <div className="min-h-14 border-t bg-background px-6 py-3 shrink-0 flex items-center justify-between text-sm gap-4 flex-wrap">
          <div className="flex items-center gap-3">
            <span className="text-muted-foreground">{filtered.length} positions</span>
            {totalPages > 1 && (
              <div className="flex items-center gap-1.5">
                <Button variant="outline" size="sm" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={safePage === 1}>
                  <ChevronLeft size={14} />Prev
                </Button>
                <span className="text-muted-foreground px-1 text-xs">Page {safePage} of {totalPages}</span>
                <Button variant="outline" size="sm" onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={safePage >= totalPages}>
                  Next<ChevronRight size={14} />
                </Button>
              </div>
            )}
          </div>
          <div className="flex items-center gap-6 font-mono">
            <span>Invested <strong className="ml-1">{formatCurrency(totals.inv)}</strong></span>
            <span>Current <strong className="ml-1">{formatCurrency(totals.live)}</strong></span>
            <span className={totals.unrl >= 0 ? 'text-green-600' : 'text-red-500'}>
              Unrealized <strong className="ml-1">{totals.unrl >= 0 ? '+' : ''}{formatCurrency(totals.unrl)}</strong>
            </span>
            <span className={totals.real >= 0 ? 'text-green-600' : 'text-red-500'}>
              Realized <strong className="ml-1">{totals.real >= 0 ? '+' : ''}{formatCurrency(totals.real)}</strong>
            </span>
          </div>
        </div>
      )}

      <PositionLotsSheet position={selectedPosition} onClose={() => setSelectedPosition(null)} />
    </div>
  )
}

// ── Right-side lots panel ─────────────────────────────────────────────────

// ── Folio editor (MF only) ────────────────────────────────────────────────
//
// Folio numbers come into the system via the import pipeline, where they may
// be auto-derived (or just blank if the broker file omitted them). Surfacing
// them here lets the user correct the value across every lot of the position
// in one shot — a single PATCH /investments/folio call updates them all.

function FolioEditor({ position }: { position: PortfolioPosition }) {
  // Distinct folios across this position's lots
  const folios = useMemo(() => Array.from(
    new Set(position.lots.map(l => l.folio_number).filter((f): f is string => !!f))
  ), [position])
  const initial = folios[0] ?? ''

  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(initial)
  const mutation = useUpdateInstrumentFolio()

  function startEdit() {
    setDraft(initial)
    setEditing(true)
  }
  async function save() {
    const next = draft.trim() || null
    if (next === (initial || null)) { setEditing(false); return }
    await mutation.mutateAsync({ user_instrument_id: position.user_instrument_id, folio_number: next })
    setEditing(false)
  }

  if (!editing) {
    return (
      <div className="flex items-center gap-2 mt-2 text-sm">
        <span className="text-muted-foreground">Folio:</span>
        {folios.length === 0 ? (
          <span className="text-muted-foreground italic">none</span>
        ) : folios.length === 1 ? (
          <span className="font-mono text-xs">{folios[0]}</span>
        ) : (
          <span className="font-mono text-xs">{folios.join(', ')}</span>
        )}
        <Button variant="ghost" size="icon-xs" onClick={startEdit} title="Edit folio number" className="h-6 w-6">
          <Pencil size={11} />
        </Button>
        {folios.length > 1 && (
          <span className="text-[10px] text-muted-foreground italic">— editing will overwrite all {folios.length} folios with one value</span>
        )}
      </div>
    )
  }

  return (
    <div className="flex items-center gap-2 mt-2 text-sm">
      <span className="text-muted-foreground">Folio:</span>
      <Input
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Enter') save()
          if (e.key === 'Escape') { setEditing(false); setDraft(initial) }
        }}
        autoFocus
        className="h-7 w-[260px] font-mono text-xs"
        placeholder="Enter folio number"
      />
      <Button size="icon-xs" variant="ghost" onClick={save} disabled={mutation.isPending} title="Save" className="h-6 w-6">
        {mutation.isPending ? <Loader2 size={11} className="animate-spin" /> : <Check size={11} />}
      </Button>
      <Button size="icon-xs" variant="ghost" onClick={() => { setEditing(false); setDraft(initial) }} title="Cancel" className="h-6 w-6">
        <X size={11} />
      </Button>
    </div>
  )
}

const SHEET_WIDTH_KEY = 'holdings.lotsSheet.widthPx'
const SHEET_MIN_PX = 480
const SHEET_MAX_PX_OFFSET = 200 // never let the user shrink the page beneath this

function PositionLotsSheet({ position, onClose }: { position: PortfolioPosition | null; onClose: () => void }) {
  const { formatCurrency } = useCurrency()
  const open = position !== null
  const isMf = position?.type === 'mutual_fund'

  // Drag-resizable width. Starts at 50vw (or last persisted value), persisted
  // to localStorage on mouseup. Dragging the left edge to the left widens it.
  const [sheetWidth, setSheetWidth] = useState<number>(() => {
    const stored = Number(localStorage.getItem(SHEET_WIDTH_KEY))
    if (Number.isFinite(stored) && stored >= SHEET_MIN_PX) return stored
    return Math.floor(window.innerWidth * 0.5)
  })

  function handleResizeMouseDown(e: React.MouseEvent) {
    e.preventDefault()
    const startX = e.clientX
    let latest = sheetWidth
    const startWidth = sheetWidth
    const onMove = (ev: MouseEvent) => {
      const next = startWidth + (startX - ev.clientX)
      const max = window.innerWidth - SHEET_MAX_PX_OFFSET
      latest = Math.max(SHEET_MIN_PX, Math.min(max, next))
      setSheetWidth(latest)
    }
    const onUp = () => {
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
      localStorage.setItem(SHEET_WIDTH_KEY, String(latest))
    }
    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }

  return (
    <Sheet open={open} onOpenChange={o => { if (!o) onClose() }}>
      <SheetContent
        side="right"
        style={{ width: `${sheetWidth}px` }}
        className="data-[side=right]:max-w-none data-[side=right]:sm:max-w-none flex flex-col p-0 overflow-hidden"
      >
        <div
          onMouseDown={handleResizeMouseDown}
          className="absolute left-0 top-0 bottom-0 w-1.5 cursor-ew-resize hover:bg-foreground/10 transition-colors z-10"
          title="Drag to resize"
        />
        <SheetHeader className="border-b px-6 py-5 shrink-0">
          {position && (
            <>
              <SheetTitle className="text-base flex items-center gap-2 flex-wrap">
                {position.instrument_name}
                {position.instrument_ticker && (
                  <span className="text-xs text-muted-foreground font-mono">{position.instrument_ticker}</span>
                )}
                <Badge variant="outline" className="ml-1">{INVESTMENT_TYPE_LABELS[position.type]}</Badge>
                {position.platform_accounts.map(pa => (
                  <Badge key={pa} variant="secondary" className="font-normal">{pa}</Badge>
                ))}
                {position.is_closed && <Badge variant="secondary">closed</Badge>}
              </SheetTitle>
              <p className="text-sm text-muted-foreground flex items-center gap-x-3 gap-y-1 flex-wrap mt-1">
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
              </p>
              {(position.long_term_units > 0.0001 || position.short_term_units > 0.0001) && (
                <p className="text-xs text-muted-foreground flex items-center gap-3 flex-wrap mt-1.5" title="Long-term: held > 365 days (server-computed FIFO)">
                  <span className="inline-flex items-center gap-1.5">
                    <span className="size-1.5 rounded-full bg-green-600" />
                    Long-term
                    <span className="font-mono text-foreground">{position.long_term_units.toLocaleString('en-IN', { maximumFractionDigits: 4 })}</span>
                    units
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <span className="size-1.5 rounded-full bg-amber-500" />
                    Short-term
                    <span className="font-mono text-foreground">{position.short_term_units.toLocaleString('en-IN', { maximumFractionDigits: 4 })}</span>
                    units
                  </span>
                </p>
              )}
              {isMf && <FolioEditor position={position} />}
            </>
          )}
        </SheetHeader>

        <div className="flex-1 overflow-auto">
          {position && (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[110px]">Date</TableHead>
                  <TableHead className="w-[70px]">Trade</TableHead>
                  <TableHead className="text-right">Qty / Units</TableHead>
                  <TableHead className="text-right w-[100px]">Price</TableHead>
                  <TableHead className="text-right w-[120px]">Amount</TableHead>
                  <TableHead className="text-right">P&amp;L</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {position.lots.map((lot: LotRead) => {
                  const qty    = lot.quantity ?? lot.units ?? null
                  const lotPnl = lot.pnl
                  return (
                    <TableRow key={lot.id}>
                      <TableCell className="text-muted-foreground text-sm">{lot.purchase_date}</TableCell>
                      <TableCell>
                        <Badge variant={lot.trade_type === 'sell' ? 'destructive' : 'default'} className="text-[10px] uppercase">
                          {lot.trade_type}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm">
                        {qty != null ? qty.toLocaleString('en-IN', { maximumFractionDigits: 4 }) : '—'}
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm text-muted-foreground">
                        {lot.price != null ? formatCurrency(lot.price) : '—'}
                      </TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(lot.amount_invested)}</TableCell>
                      <TableCell className={`text-right font-mono text-sm ${lotPnl == null ? 'text-muted-foreground' : lotPnl.value >= 0 ? 'text-green-600' : 'text-red-500'}`} title={[ lotPnl?.label, lot.platform_account_nickname && `Platform: ${lot.platform_account_nickname}`, lot.notes ].filter(Boolean).join(' · ') || undefined}>
                        {lotPnl == null ? '—' : (
                          <>
                            {lotPnl.value >= 0 ? '+' : ''}{formatCurrency(lotPnl.value)}
                            {lotPnl.pct != null && (
                              <span className="text-[10px] text-muted-foreground ml-1">({lotPnl.pct >= 0 ? '+' : ''}{lotPnl.pct.toFixed(1)}%)</span>
                            )}
                          </>
                        )}
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          )}
        </div>

        {position && !position.is_closed && (
          <div className="border-t px-6 py-3 shrink-0 flex items-center justify-between text-sm font-mono">
            <span className="text-muted-foreground">Position summary</span>
            <div className="flex items-center gap-5">
              <span>Invested <strong className="ml-1">{formatCurrency(position.total_invested)}</strong></span>
              <span>Current <strong className="ml-1">{formatCurrency(position.current_value)}</strong></span>
              <span className={position.unrealized_gain >= 0 ? 'text-green-600' : 'text-red-500'}>
                Unrealized <strong className="ml-1">{position.unrealized_gain >= 0 ? '+' : ''}{formatCurrency(position.unrealized_gain)}</strong>
              </span>
            </div>
          </div>
        )}
      </SheetContent>
    </Sheet>
  )
}
