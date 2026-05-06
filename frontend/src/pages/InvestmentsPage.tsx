import { useState } from 'react'
import { ChevronLeft, ChevronRight, Pencil, Plus, Trash2 } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { PageHeader } from '@/components/layout/PageHeader'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { InvestmentForm } from '@/components/investments/InvestmentForm'
import { useCreateInvestment, useDeleteInvestment, useInvestments, useUpdateInvestment } from '@/hooks/useInvestments'
import { useCurrency } from '@/hooks/useCurrency'
import { calcGainLoss } from '@/lib/finance'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Investment, InvestmentType } from '@/types'

const PAGE_SIZE = 15
const ALL_TYPES: InvestmentType[] = ['stock', 'mutual_fund']

export function InvestmentsPage() {
  const qc = useQueryClient()
  const { formatCurrency } = useCurrency()
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Investment | null>(null)
  const [page, setPage] = useState(1)
  const [typeFilter, setTypeFilter] = useState<InvestmentType | undefined>(undefined)

  const { data, isLoading, isFetching } = useInvestments(typeFilter ? [typeFilter] : undefined, page, PAGE_SIZE)
  const createMutation = useCreateInvestment()
  const updateMutation = useUpdateInvestment()
  const deleteMutation = useDeleteInvestment()

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

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-4">
        <div className="flex flex-wrap gap-3">
          <Select
            value={typeFilter ?? 'all'}
            onValueChange={v => { setTypeFilter(v === 'all' ? undefined : v as InvestmentType); setPage(1) }}
          >
            <SelectTrigger className="w-44"><SelectValue placeholder="All Types" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
              {ALL_TYPES.map(t => (
                <SelectItem key={t} value={t}>{INVESTMENT_TYPE_LABELS[t]}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="rounded-lg border overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead><TableHead>Type</TableHead><TableHead>Purchase Date</TableHead>
                  <TableHead className="text-right">Invested</TableHead><TableHead className="text-right">Current Value</TableHead>
                  <TableHead className="text-right">Gain / Loss</TableHead><TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {investments.map(inv => {
                  const { gain, pct, isPositive } = calcGainLoss(inv.amount_invested, inv.current_value)
                  return (
                    <TableRow key={inv.id}>
                      <TableCell className="font-medium">{inv.name}</TableCell>
                      <TableCell><Badge variant="outline">{INVESTMENT_TYPE_LABELS[inv.type]}</Badge></TableCell>
                      <TableCell className="text-muted-foreground text-sm">{inv.purchase_date}</TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(inv.amount_invested)}</TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(inv.current_value ?? inv.amount_invested)}</TableCell>
                      <TableCell className={`text-right font-mono font-medium ${isPositive ? 'text-green-600' : 'text-red-500'}`}>
                        {isPositive ? '+' : ''}{formatCurrency(gain)} ({pct}%)
                      </TableCell>
                      <TableCell className="flex gap-1 justify-end">
                        <Button size="icon" variant="ghost" onClick={() => { setEditing(inv); setOpen(true) }}><Pencil size={14} /></Button>
                        <Button size="icon" variant="ghost" onClick={() => deleteMutation.mutate(inv.id)}><Trash2 size={14} /></Button>
                      </TableCell>
                    </TableRow>
                  )
                })}
                {investments.length === 0 && (
                  <TableRow><TableCell colSpan={7} className="text-center text-muted-foreground py-8">No investments yet</TableCell></TableRow>
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
              onSubmit={handleSubmit}
              onCancel={() => { setOpen(false); setEditing(null) }}
            />
          </div>
        </SheetContent>
      </Sheet>
    </div>
  )
}
