import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { InvestmentForm } from '@/components/investments/InvestmentForm'
import {
  useCreateInvestment,
  useDeleteInvestment,
  useInvestments,
  useUpdateInvestment,
} from '@/hooks/useInvestments'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Investment, InvestmentType } from '@/types'

const fmt = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 })

export function InvestmentsPage() {
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Investment | null>(null)

  const { data, isLoading } = useInvestments()
  const createMutation = useCreateInvestment()
  const updateMutation = useUpdateInvestment()
  const deleteMutation = useDeleteInvestment()

  async function handleSubmit(values: Partial<Investment> & {
    type: InvestmentType; name: string; amount_invested: number; purchase_date: string
  }) {
    if (editing) {
      await updateMutation.mutateAsync({ id: editing.id, data: values })
    } else {
      await createMutation.mutateAsync(values)
    }
    setOpen(false)
    setEditing(null)
  }

  function openEdit(inv: Investment) { setEditing(inv); setOpen(true) }
  function openCreate() { setEditing(null); setOpen(true) }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Investments</h1>
        <Button onClick={openCreate}><Plus size={16} className="mr-1" />Add</Button>
      </div>

      {isLoading ? (
        <div className="text-muted-foreground">Loading…</div>
      ) : (
        <div className="rounded-lg border overflow-hidden">
          <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Purchase Date</TableHead>
              <TableHead className="text-right">Invested</TableHead>
              <TableHead className="text-right">Current Value</TableHead>
              <TableHead className="text-right">Gain / Loss</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {data?.items.map(inv => {
              const cv = inv.current_value ?? inv.amount_invested
              const gain = cv - inv.amount_invested
              const pct = ((gain / inv.amount_invested) * 100).toFixed(1)
              return (
                <TableRow key={inv.id}>
                  <TableCell className="font-medium">{inv.name}</TableCell>
                  <TableCell><Badge variant="outline">{INVESTMENT_TYPE_LABELS[inv.type]}</Badge></TableCell>
                  <TableCell className="text-muted-foreground text-sm">{inv.purchase_date}</TableCell>
                  <TableCell className="text-right font-mono">{fmt.format(inv.amount_invested)}</TableCell>
                  <TableCell className="text-right font-mono">{fmt.format(cv)}</TableCell>
                  <TableCell className={`text-right font-mono font-medium ${gain >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                    {gain >= 0 ? '+' : ''}{fmt.format(gain)} ({pct}%)
                  </TableCell>
                  <TableCell className="flex gap-1 justify-end">
                    <Button size="icon" variant="ghost" onClick={() => openEdit(inv)}><Pencil size={14} /></Button>
                    <Button size="icon" variant="ghost" onClick={() => deleteMutation.mutate(inv.id)}><Trash2 size={14} /></Button>
                  </TableCell>
                </TableRow>
              )
            })}
            {data?.items.length === 0 && (
              <TableRow><TableCell colSpan={7} className="text-center text-muted-foreground py-8">No investments yet</TableCell></TableRow>
            )}
          </TableBody>
          </Table>
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{editing ? 'Edit Investment' : 'New Investment'}</DialogTitle>
          </DialogHeader>
          <InvestmentForm
            initial={editing ?? undefined}
            onSubmit={handleSubmit}
            onCancel={() => setOpen(false)}
          />
        </DialogContent>
      </Dialog>
    </div>
  )
}
