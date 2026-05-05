import { useState } from 'react'
import { ChevronDown, ChevronRight, Upload } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { ImportWizard } from '@/components/imports/ImportWizard'
import { useImports } from '@/hooks/useImports'
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
  const errors = batch.import_records.filter(r => r.status === 'error')
  return (
    <TableRow>
      <TableCell colSpan={7} className="bg-muted/30 p-3">
        <div className="flex flex-wrap gap-2 text-xs">
          <span className="text-muted-foreground">
            <span className="font-medium text-green-600">{batch.import_records.filter(r => r.status === 'ok').length} ok</span>
            {' · '}
            <span className="font-medium text-yellow-600">{batch.import_records.filter(r => r.status === 'skipped').length} skipped</span>
            {' · '}
            <span className="font-medium text-destructive">{errors.length} errors</span>
          </span>
        </div>
        {errors.length > 0 && (
          <ul className="mt-2 space-y-1">
            {errors.map(r => (
              <li key={r.row_index} className="text-xs text-destructive">
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
          {batch.status === 'pending'
            ? '—'
            : `${batch.processed_rows} / ${batch.total_rows}`}
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
  const [page, setPage] = useState(1)
  const [wizardOpen, setWizardOpen] = useState(false)
  const { data, isLoading } = useImports(page)

  const totalPages = data ? Math.ceil(data.total / data.page_size) : 1

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="flex items-center justify-between border-b px-6 py-4 shrink-0">
        <h1 className="text-lg font-semibold">Imports</h1>
        <Button size="sm" onClick={() => setWizardOpen(true)}>
          <Upload size={14} className="mr-1.5" />
          New Import
        </Button>
      </div>

      <div className="flex-1 overflow-auto p-6">
        {isLoading ? (
          <div className="flex items-center justify-center h-40 text-muted-foreground text-sm">
            Loading…
          </div>
        ) : !data?.items.length ? (
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
                {data.items.map(batch => (
                  <BatchRow key={batch.id} batch={batch} />
                ))}
              </TableBody>
            </Table>

            {totalPages > 1 && (
              <div className="flex items-center justify-end gap-2 mt-4">
                <Button
                  variant="outline" size="sm"
                  disabled={page <= 1}
                  onClick={() => setPage(p => p - 1)}
                >
                  Previous
                </Button>
                <span className="text-xs text-muted-foreground">
                  Page {page} of {totalPages}
                </span>
                <Button
                  variant="outline" size="sm"
                  disabled={page >= totalPages}
                  onClick={() => setPage(p => p + 1)}
                >
                  Next
                </Button>
              </div>
            )}
          </>
        )}
      </div>

      <ImportWizard open={wizardOpen} onClose={() => setWizardOpen(false)} />
    </div>
  )
}
