import { useEffect, useRef, useState } from 'react'
import { BookOpen } from 'lucide-react'
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
import { useInvestments } from '@/hooks/useInvestments'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Instrument, InvestmentType } from '@/types'

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
                    <TableHead />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {instruments.map(inst => (
                    <TableRow key={inst.id}>
                      <TableCell className="font-medium">{inst.name}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{INVESTMENT_TYPE_LABELS[inst.type]}</Badge>
                      </TableCell>
                      <TableCell className="font-mono text-sm text-muted-foreground">
                        {inst.ticker_symbol || '—'}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {inst.fund_house || '—'}
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
                      <TableCell colSpan={5} className="text-center text-muted-foreground py-10">
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
  title: string
  instruments: Instrument[]
  emptyMessage: string
}

function TrackedTable({ title, instruments, emptyMessage }: TrackedTableProps) {
  const untrackMutation = useUntrackInstrument()

  return (
    <div className="flex flex-col gap-3">
      <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">{title}</h2>
      <div className="rounded-lg border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Ticker</TableHead>
              <TableHead>Fund House</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {instruments.map(inst => (
              <TableRow key={inst.id}>
                <TableCell className="font-medium">{inst.name}</TableCell>
                <TableCell>
                  <Badge variant="outline">{INVESTMENT_TYPE_LABELS[inst.type]}</Badge>
                </TableCell>
                <TableCell className="font-mono text-sm text-muted-foreground">
                  {inst.ticker_symbol || '—'}
                </TableCell>
                <TableCell className="text-sm text-muted-foreground">
                  {inst.fund_house || '—'}
                </TableCell>
                <TableCell className="text-right">
                  <Button
                    size="sm"
                    variant="ghost"
                    className="text-muted-foreground hover:text-destructive"
                    onClick={() => untrackMutation.mutate(inst.id)}
                    disabled={untrackMutation.isPending}
                  >
                    Untrack
                  </Button>
                </TableCell>
              </TableRow>
            ))}
            {instruments.length === 0 && (
              <TableRow>
                <TableCell colSpan={5} className="text-center text-muted-foreground py-8">
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

export function InstrumentsPage() {
  const qc = useQueryClient()
  const [browseOpen, setBrowseOpen] = useState(false)

  const { data: tracked = [], isLoading: trackedLoading, isFetching } = useTrackedInstruments()
  const { data: investmentsData } = useInvestments(undefined, 1, 200)
  const trackedIds = new Set(tracked.map(i => i.id))

  // Instrument IDs that have at least one investment
  const instrumentIdsInPortfolio = new Set(
    (investmentsData?.items ?? [])
      .map(inv => inv.instrument_id)
      .filter((id): id is number => id !== null)
  )

  const inPortfolio = tracked.filter(i => instrumentIdsInPortfolio.has(i.id))
  const notYetInPortfolio = tracked.filter(i => !instrumentIdsInPortfolio.has(i.id))

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

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-8">
        {trackedLoading ? (
          <div className="text-muted-foreground text-sm">Loading…</div>
        ) : (
          <>
            <TrackedTable
              title="In Portfolio"
              instruments={inPortfolio}
              emptyMessage="No tracked instruments with investments yet"
            />
            <TrackedTable
              title="Not Yet Invested"
              instruments={notYetInPortfolio}
              emptyMessage="All tracked instruments have investments — or track one via Browse All"
            />
          </>
        )}
      </div>

      <BrowseSheet
        open={browseOpen}
        onClose={() => setBrowseOpen(false)}
        trackedIds={trackedIds}
      />
    </div>
  )
}
