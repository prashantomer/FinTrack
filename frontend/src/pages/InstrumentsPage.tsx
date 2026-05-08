import { useEffect, useMemo, useRef, useState } from 'react'
// (useEffect kept for the BrowseSheet infinite-scroll listener below)
import { Link } from 'react-router-dom'
import { BookOpen, ChevronLeft, ChevronRight } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { useDebounce } from '@/hooks/useDebounce'
import { PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import {
  useInfiniteInstruments,
  useInstrumentTypes,
  useTrackInstrument,
  useTrackedInstruments,
  useUntrackInstrument,
} from '@/hooks/useInstruments'
import { usePortfolio } from '@/hooks/useReports'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Instrument, InvestmentType } from '@/types'

function formatPrice(p: number): string {
  return new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 4 }).format(p)
}

function shortDate(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
}

// ── Browse sheet ──────────────────────────────────────────────────────────────

interface BrowseSheetProps {
  open: boolean
  onClose: () => void
  trackedIds: Set<number>
}

function BrowseSheet({ open, onClose, trackedIds }: BrowseSheetProps) {
  const [search, setSearch] = useState('')
  const debouncedSearch = useDebounce(search, 300)
  const [typeFilter, setTypeFilter] = useState<string>('stock')
  const scrollContainerRef = useRef<HTMLDivElement>(null)
  const trackMutation = useTrackInstrument()
  const untrackMutation = useUntrackInstrument()
  const { data: availableTypes = [] } = useInstrumentTypes()

  const {
    data,
    isLoading,
    isFetchingNextPage,
    fetchNextPage,
    hasNextPage,
  } = useInfiniteInstruments({
    search: debouncedSearch || undefined,
    type: typeFilter as InvestmentType,
  })

  const instruments = data?.pages.flatMap(p => p.items) ?? []

  useEffect(() => {
    const container = scrollContainerRef.current
    if (!container || !hasNextPage || isFetchingNextPage) return

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = container
      if (scrollHeight - scrollTop - clientHeight < 300) fetchNextPage()
    }

    container.addEventListener('scroll', handleScroll)
    handleScroll() // trigger immediately if content shorter than container
    return () => container.removeEventListener('scroll', handleScroll)
  }, [hasNextPage, isFetchingNextPage, fetchNextPage])

  function handleClose() {
    setSearch('')
    setTypeFilter('stock')
    onClose()
  }

  return (
    <Sheet open={open} onOpenChange={v => !v && handleClose()}>
      <SheetContent
        side="right"
        style={{ width: 'calc((100vw - 14rem) * 0.92)', maxWidth: 'calc((100vw - 14rem) * 0.92)' }}
        className="flex flex-col p-0 overflow-hidden"
      >
        <SheetHeader className="border-b px-6 py-4 shrink-0">
          <SheetTitle className="text-base">Browse Instruments</SheetTitle>
        </SheetHeader>

        <div className="flex gap-3 px-6 py-4 border-b shrink-0">
          <Input
            placeholder="Search by name, ticker or fund house…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="flex-1"
            autoFocus
          />
          <Select value={typeFilter} onValueChange={v => v && setTypeFilter(v)}>
            <SelectTrigger className="w-44 shrink-0">
              <SelectValue>
                {INVESTMENT_TYPE_LABELS[typeFilter as InvestmentType] ?? typeFilter}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {availableTypes.map(t => (
                <SelectItem key={t} value={t}>
                  {INVESTMENT_TYPE_LABELS[t] ?? t}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div ref={scrollContainerRef} className="flex-1 min-h-0 overflow-y-auto">
          {isLoading ? (
            <div className="px-6 py-8 text-sm text-muted-foreground">Loading…</div>
          ) : (
            <>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Ticker</TableHead>
                    <TableHead>Fund House</TableHead>
                    <TableHead className="text-right">Last Price</TableHead>
                    <TableHead />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {instruments.map(inst => (
                    <TableRow key={inst.id}>
                      <TableCell className="font-medium">
                  <Link to={`/instruments/${inst.id}`} className="hover:underline">{inst.name}</Link>
                </TableCell>
                      <TableCell>
                        <Badge variant="outline">{INVESTMENT_TYPE_LABELS[inst.type]}</Badge>
                      </TableCell>
                      <TableCell className="font-mono text-sm text-muted-foreground">
                        {inst.ticker_symbol || '—'}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {inst.fund_house || '—'}
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm">
                        {inst.last_price != null ? (
                          <div className="flex flex-col items-end leading-tight">
                            <span>{formatPrice(inst.last_price)}</span>
                            {inst.last_price_at && (
                              <span className="text-[10px] text-muted-foreground">{shortDate(inst.last_price_at)}</span>
                            )}
                          </div>
                        ) : <span className="text-muted-foreground">—</span>}
                      </TableCell>
                      <TableCell className="text-right">
                        {trackedIds.has(inst.id) ? (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => untrackMutation.mutate(inst.id)}
                            disabled={untrackMutation.isPending}
                          >
                            Untrack
                          </Button>
                        ) : (
                          <Button
                            size="sm"
                            onClick={() => trackMutation.mutate(inst.id)}
                            disabled={trackMutation.isPending}
                          >
                            Track
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                  {instruments.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center text-muted-foreground py-10">
                        No instruments found
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>

              {isFetchingNextPage && (
                <div className="text-center text-sm text-muted-foreground py-3">Loading more…</div>
              )}
              {!hasNextPage && instruments.length > 0 && (
                <div className="text-center text-xs text-muted-foreground py-3">
                  {instruments.length} instrument{instruments.length !== 1 ? 's' : ''}
                </div>
              )}
            </>
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}

// ── Tracked instrument table ──────────────────────────────────────────────────

interface TrackedTableProps {
  instruments: Instrument[]
  emptyMessage: string
  allowUntrack?: boolean
}

function TrackedTable({ instruments, emptyMessage, allowUntrack = false }: TrackedTableProps) {
  const untrackMutation = useUntrackInstrument()

  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-lg border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Ticker</TableHead>
              <TableHead>Fund House</TableHead>
              <TableHead className="text-right">Last Price</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {instruments.map(inst => (
              <TableRow key={inst.id}>
                <TableCell className="font-medium">
                  <Link to={`/instruments/${inst.id}`} className="hover:underline">{inst.name}</Link>
                </TableCell>
                <TableCell>
                  <Badge variant="outline">{INVESTMENT_TYPE_LABELS[inst.type]}</Badge>
                </TableCell>
                <TableCell className="font-mono text-sm text-muted-foreground">
                  {inst.ticker_symbol || '—'}
                </TableCell>
                <TableCell className="text-sm text-muted-foreground">
                  {inst.fund_house || '—'}
                </TableCell>
                <TableCell className="text-right font-mono text-sm">
                  {inst.last_price != null ? (
                    <div className="flex flex-col items-end leading-tight">
                      <span>{formatPrice(inst.last_price)}</span>
                      {inst.last_price_at && (
                        <span className="text-[10px] text-muted-foreground">{shortDate(inst.last_price_at)}</span>
                      )}
                    </div>
                  ) : <span className="text-muted-foreground">—</span>}
                </TableCell>
                <TableCell className="text-right">
                  {allowUntrack ? (
                    <Button
                      size="sm"
                      variant="ghost"
                      className="text-muted-foreground hover:text-destructive"
                      onClick={() => untrackMutation.mutate(inst.id)}
                      disabled={untrackMutation.isPending}
                    >
                      Untrack
                    </Button>
                  ) : (
                    <span className="text-[11px] text-muted-foreground italic" title="Cannot untrack — has trades. Delete all trades first.">
                      has trades
                    </span>
                  )}
                </TableCell>
              </TableRow>
            ))}
            {instruments.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                  {emptyMessage}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

type TabKey = 'held' | 'withdrawn' | 'idle'
const PAGE_SIZE = 25

export function InstrumentsPage() {
  const qc = useQueryClient()
  const [browseOpen, setBrowseOpen] = useState(false)
  const [tab, setTab] = useState<TabKey>('held')
  const [page, setPage] = useState(1)

  const { data: tracked = [], isLoading: trackedLoading, isFetching } = useTrackedInstruments()
  const { data: portfolio } = usePortfolio()
  const trackedIds = new Set(tracked.map(i => i.id))

  // Bucket each tracked instrument using portfolio aggregation:
  //   held       → position with is_closed=false (net qty > 0)
  //   withdrawn  → position but is_closed=true (all sold off)
  //   idle       → no position at all
  const buckets = useMemo(() => {
    const positions    = portfolio?.positions ?? []
    const heldIds      = new Set(positions.filter(p => !p.is_closed).map(p => p.instrument_id))
    const withdrawnIds = new Set(positions.filter(p =>  p.is_closed).map(p => p.instrument_id))
    return {
      held:      tracked.filter(i =>  heldIds.has(i.id)),
      withdrawn: tracked.filter(i => !heldIds.has(i.id) &&  withdrawnIds.has(i.id)),
      idle:      tracked.filter(i => !heldIds.has(i.id) && !withdrawnIds.has(i.id)),
    }
  }, [tracked, portfolio])

  const TABS: { value: TabKey; label: string; count: number; emptyMessage: string }[] = [
    { value: 'held',      label: 'Currently Held',  count: buckets.held.length,      emptyMessage: 'No tracked instruments are currently held — buy some to see positions here' },
    { value: 'withdrawn', label: 'Fully Withdrawn', count: buckets.withdrawn.length, emptyMessage: 'No tracked instruments have been fully sold off' },
    { value: 'idle',      label: 'Not Yet Invested', count: buckets.idle.length,    emptyMessage: 'All tracked instruments have at least one trade' },
  ]

  const active     = buckets[tab]
  const totalPages = Math.max(1, Math.ceil(active.length / PAGE_SIZE))
  const safePage   = Math.min(page, totalPages)
  const paged      = useMemo(() => active.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE), [active, safePage])

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="My Instruments"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['instruments'] })}
        isRefreshing={isFetching}
      >
        <Button onClick={() => setBrowseOpen(true)}>
          <BookOpen size={16} className="mr-1.5" />
          Browse All
        </Button>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-4">
        <div className="flex gap-1 border-b">
          {TABS.map(t => (
            <button
              key={t.value}
              onClick={() => { setTab(t.value); setPage(1) }}
              className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors -mb-px flex items-center gap-2 ${
                tab === t.value
                  ? 'border-primary text-primary'
                  : 'border-transparent text-muted-foreground hover:text-foreground'
              }`}
            >
              {t.label}
              <Badge variant={tab === t.value ? 'default' : 'outline'} className="text-[10px] px-1.5">
                {t.count}
              </Badge>
            </button>
          ))}
        </div>

        {trackedLoading ? (
          <div className="text-muted-foreground text-sm">Loading…</div>
        ) : (
          <TrackedTable
            instruments={paged}
            emptyMessage={TABS.find(t => t.value === tab)?.emptyMessage ?? ''}
            allowUntrack={tab === 'idle'}
          />
        )}
      </div>

      {active.length > 0 && (
        <div className="min-h-14 border-t bg-background px-6 py-3 shrink-0 flex items-center justify-between text-sm gap-4">
          <span className="text-muted-foreground">
            {active.length} {active.length === 1 ? 'instrument' : 'instruments'}
          </span>
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
      )}

      <BrowseSheet
        open={browseOpen}
        onClose={() => setBrowseOpen(false)}
        trackedIds={trackedIds}
      />
    </div>
  )
}
