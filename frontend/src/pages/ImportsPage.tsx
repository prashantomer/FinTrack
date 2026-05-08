import { useEffect, useRef, useState } from 'react'
import { ChevronDown, ChevronRight, Upload } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { ImportWizard } from '@/components/imports/ImportWizard'
import { useInfiniteImports } from '@/hooks/useImports'
import type { ImportBatch, ImportStatus } from '@/types'

function statusVariant(status: ImportStatus): 'default' | 'secondary' | 'destructive' | 'outline' {
  switch (status) {
    case 'completed':  return 'default'
    case 'processing': return 'secondary'
    case 'pending':    return 'outline'
    case 'failed':     return 'destructive'
  }
}

function ExpandedRows({ batch }: { batch: ImportBatch }) {
  if (!batch.import_records.length) {
    return (
      <TableRow>
        <TableCell colSpan={7} className="bg-muted/30 text-center text-xs text-muted-foreground py-2">
          No row details available.
        </TableCell>
      </TableRow>
    )
  }
  const errors     = batch.import_records.filter(r => r.status === 'error')
  const duplicates = batch.import_records.filter(r => r.status === 'skipped')
  return (
    <TableRow>
      <TableCell colSpan={7} className="bg-muted/30 p-3">
        <div className="flex flex-wrap gap-2 text-xs">
          <span className="text-muted-foreground">
            <span className="font-medium text-green-600">{batch.import_records.filter(r => r.status === 'ok').length} ok</span>
            {' · '}
            <span className="font-medium text-yellow-600">{duplicates.length} duplicate{duplicates.length === 1 ? '' : 's'}</span>
            {' · '}
            <span className="font-medium text-destructive">{errors.length} error{errors.length === 1 ? '' : 's'}</span>
          </span>
        </div>
        {duplicates.length > 0 && (
          <ul className="mt-2 space-y-1">
            {duplicates.map(r => (
              <li key={`dup-${r.row_index}`} className="text-xs text-yellow-700 dark:text-yellow-500">
                Row {r.row_index + 1}: <span>{r.notes ?? 'Duplicate row'}</span>
              </li>
            ))}
          </ul>
        )}
        {errors.length > 0 && (
          <ul className="mt-2 space-y-1">
            {errors.map(r => (
              <li key={`err-${r.row_index}`} className="text-xs text-destructive">
                Row {r.row_index + 1}: <span>{r.notes ?? 'Unknown error'}</span>
              </li>
            ))}
          </ul>
        )}
      </TableCell>
    </TableRow>
  )
}

function BatchRow({ batch }: { batch: ImportBatch }) {
  const [expanded, setExpanded] = useState(false)
  const canExpand = batch.status === 'completed' || batch.status === 'failed'
  return (
    <>
      <TableRow
        className={canExpand ? 'cursor-pointer select-none' : ''}
        onClick={() => canExpand && setExpanded(v => !v)}
      >
        <TableCell className="w-8 text-muted-foreground">
          {canExpand
            ? (expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />)
            : null}
        </TableCell>
        <TableCell className="font-mono text-xs text-muted-foreground">
          v{batch.import_version}
        </TableCell>
        <TableCell className="capitalize">{batch.import_type}</TableCell>
        <TableCell className="max-w-[200px] truncate text-sm">{batch.file_name}</TableCell>
        <TableCell>
          <Badge variant={statusVariant(batch.status)} className="capitalize">
            {batch.status}
          </Badge>
        </TableCell>
        <TableCell className="text-sm">
          {batch.status === 'pending' ? (
            '—'
          ) : (
            <span>
              {batch.processed_rows} / {batch.total_rows}
              {batch.duplicate_rows > 0 && (
                <span className="ml-1.5 text-xs text-yellow-700 dark:text-yellow-500">
                  ({batch.duplicate_rows} dup)
                </span>
              )}
              {batch.failed_rows > 0 && (
                <span className="ml-1.5 text-xs text-destructive">
                  ({batch.failed_rows} err)
                </span>
              )}
            </span>
          )}
        </TableCell>
        <TableCell className="text-sm text-muted-foreground">
          {new Date(batch.created_at).toLocaleDateString()}
        </TableCell>
      </TableRow>
      {expanded && <ExpandedRows batch={batch} />}
    </>
  )
}

export function ImportsPage() {
  const [wizardOpen, setWizardOpen] = useState(false)
  const {
    data,
    isLoading,
    isFetchingNextPage,
    fetchNextPage,
    hasNextPage,
  } = useInfiniteImports()

  const items = data?.pages.flatMap(p => p.items) ?? []

  // Native scroll-listener — matches the InstrumentsPage pattern. Triggers
  // the next page when the bottom is within 300px of the viewport.
  const scrollContainerRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const container = scrollContainerRef.current
    if (!container || !hasNextPage || isFetchingNextPage) return

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = container
      if (scrollHeight - scrollTop - clientHeight < 300) fetchNextPage()
    }
    container.addEventListener('scroll', handleScroll)
    handleScroll() // trigger immediately if content is shorter than the container
    return () => container.removeEventListener('scroll', handleScroll)
  }, [hasNextPage, isFetchingNextPage, fetchNextPage])

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="flex items-center justify-between min-h-14 border-b px-6 py-3 shrink-0">
        <h1 className="text-lg font-semibold leading-none">Imports</h1>
        <Button size="sm" onClick={() => setWizardOpen(true)}>
          <Upload size={14} className="mr-1.5" />
          New Import
        </Button>
      </div>

      <div ref={scrollContainerRef} className="flex-1 overflow-auto p-6">
        {isLoading ? (
          <div className="flex items-center justify-center h-40 text-muted-foreground text-sm">
            Loading…
          </div>
        ) : !items.length ? (
          <div className="flex flex-col items-center justify-center h-40 gap-2 text-muted-foreground">
            <Upload size={32} className="opacity-30" />
            <p className="text-sm">No imports yet. Click "New Import" to get started.</p>
          </div>
        ) : (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-8" />
                  <TableHead>Version</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>File</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Rows</TableHead>
                  <TableHead>Date</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map(batch => (
                  <BatchRow key={batch.id} batch={batch} />
                ))}
              </TableBody>
            </Table>

            {isFetchingNextPage && (
              <div className="text-center text-xs text-muted-foreground py-4">Loading more…</div>
            )}
            {!hasNextPage && items.length > 0 && (
              <div className="text-center text-xs text-muted-foreground py-4">— end —</div>
            )}
          </>
        )}
      </div>

      <ImportWizard open={wizardOpen} onClose={() => setWizardOpen(false)} />
    </div>
  )
}
