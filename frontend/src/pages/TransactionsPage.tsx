import { useState } from 'react'
import { ChevronLeft, ChevronRight, Lock, Pencil, Plus, Search } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Textarea } from '@/components/ui/textarea'
import { TransactionForm } from '@/components/transactions/TransactionForm'
import { useAccounts } from '@/hooks/useBanks'
import { useTermAccounts } from '@/hooks/useTermAccounts'
import { useCreateTransaction, useTransactions, useUpdateTransaction } from '@/hooks/useTransactions'
import { useTransactionFilters } from '@/hooks/useTransactionFilters'
import { useCurrency } from '@/hooks/useCurrency'
import { resolveAccountLabel } from '@/lib/finance'
import { TRANSACTION_TYPE_LABELS } from '@/lib/labels'
import type { LinkedAccountType, Transaction, TransactionCreate, TransactionType } from '@/types'

const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })

export function TransactionsPage() {
  const qc = useQueryClient()
  const { formatCurrency } = useCurrency()
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Transaction | null>(null)

  const filters = useTransactionFilters()
  const { data, isLoading, isFetching } = useTransactions(filters.params)
  const { data: accounts = [] } = useAccounts()
  const { data: termAccounts = [] } = useTermAccounts()
  const createMutation = useCreateTransaction()

  const items = data?.items ?? []

  async function handleSubmit(values: {
    amount: number
    type: TransactionType
    linked_account_type: LinkedAccountType | ''
    linked_account_id: number | null
    tags_input: string
    bank_ref: string
    description: string
    date: string
    instrument_id: number | null
  }) {
    const tags = values.tags_input.split(',').map(t => t.trim()).filter(Boolean)
    const payload: TransactionCreate = {
      amount: values.amount,
      type: values.type,
      linked_account_type: values.linked_account_type || null,
      linked_account_id: values.linked_account_id,
      tags: tags.length > 0 ? tags : undefined,
      bank_ref: values.bank_ref || undefined,
      description: values.description || undefined,
      date: values.date,
      instrument_id: values.instrument_id,
    }
    await createMutation.mutateAsync(payload)
    setOpen(false)
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Transactions"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['transactions'] })}
        isRefreshing={isFetching}
      >
        <Button onClick={() => setOpen(true)}><Plus size={16} className="mr-1" />Add</Button>
      </PageHeader>

      <div className="flex-1 min-h-0 px-6 py-6 flex flex-col gap-4 overflow-hidden">
        <div className="flex flex-wrap gap-3 shrink-0">
          <div className="relative">
            <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
            <Input
              placeholder="Search description, ref, tags…"
              value={filters.searchInput}
              onChange={e => filters.setSearchInput(e.target.value)}
              className="pl-8 w-64"
            />
          </div>
          <Select value={filters.type} onValueChange={filters.setType}>
            <SelectTrigger className="w-32"><SelectValue placeholder="Type" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
              {(Object.keys(TRANSACTION_TYPE_LABELS) as TransactionType[]).map(t => (
                <SelectItem key={t} value={t}>{TRANSACTION_TYPE_LABELS[t]}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Input type="date" value={filters.dateFrom} onChange={e => filters.setDateFrom(e.target.value)} className="w-36" />
          <Input type="date" value={filters.dateTo} onChange={e => filters.setDateTo(e.target.value)} className="w-36" />
        </div>

        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="flex-1 min-h-0 rounded-lg border overflow-auto">
            <Table>
              <TableHeader className="sticky top-0 z-10 bg-muted/60 backdrop-blur supports-[backdrop-filter]:bg-muted/70 [&_th]:shadow-[inset_0_-1px_0_var(--border)]">
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Source</TableHead>
                  <TableHead>Account</TableHead>
                  <TableHead>Description</TableHead>
                  <TableHead>Tags</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead className="text-right">Amount</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map(t => (
                  <TableRow key={t.id} className={t.is_active ? '' : 'opacity-40 line-through'}>
                    <TableCell className="text-muted-foreground text-sm whitespace-nowrap">{fmtDate(t.date)}</TableCell>
                    <TableCell>
                      <Badge
                        variant={t.source === 'imported' ? 'secondary' : 'outline'}
                        className="text-[10px] uppercase tracking-wide gap-1"
                      >
                        {t.source === 'imported' && <Lock size={9} />}
                        {t.source}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm whitespace-nowrap">
                      {resolveAccountLabel(t.linked_account_type, t.linked_account_id, accounts, termAccounts)}
                    </TableCell>
                    <TableCell>
                      <div>{t.description || '—'}</div>
                      {t.public_id && <div className="text-xs text-muted-foreground font-mono">{t.public_id}</div>}
                      {t.bank_ref && t.bank_ref !== t.public_id && (
                        <div className="text-xs text-muted-foreground">Bank ref: <span className="font-mono">{t.bank_ref}</span></div>
                      )}
                    </TableCell>
                    <TableCell>
                      {t.tags && t.tags.length > 0 ? (
                        <div className="flex flex-wrap gap-1">
                          {t.tags.map((tag, i) => <Badge key={`${tag}-${i}`} variant="secondary" className="text-xs">{tag}</Badge>)}
                        </div>
                      ) : (
                        <span className="text-muted-foreground text-xs">—</span>
                      )}
                    </TableCell>
                    <TableCell>
                      <Badge variant={t.type === 'credit' ? 'default' : 'secondary'}>{TRANSACTION_TYPE_LABELS[t.type]}</Badge>
                    </TableCell>
                    <TableCell className={`text-right font-mono font-medium ${t.type === 'credit' ? 'text-green-600' : 'text-red-500'}`}>
                      {t.type === 'credit' ? '+' : '-'}{formatCurrency(t.amount)}
                    </TableCell>
                    <TableCell className="text-right">
                      {t.source === 'manual' ? (
                        <Button size="icon" variant="ghost" onClick={() => setEditing(t)} title="Edit description / tags">
                          <Pencil size={14} />
                        </Button>
                      ) : (
                        <Button size="icon" variant="ghost" disabled title="Imported rows are read-only">
                          <Lock size={14} className="text-muted-foreground" />
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
                {items.length === 0 && (
                  <TableRow><TableCell colSpan={8} className="text-center text-muted-foreground py-8">No transactions</TableCell></TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        )}
      </div>

      {data && data.total > 0 && (
        <div className="min-h-14 border-t bg-background px-6 py-3 flex items-center gap-3 shrink-0">
          <span className="text-muted-foreground text-sm flex-1">{data.total.toLocaleString()} total</span>
          {data.total > 20 && (
            <>
              <Button variant="outline" size="sm" disabled={filters.page === 1} onClick={() => filters.setPage(p => p - 1)}>
                <ChevronLeft size={14} />Prev
              </Button>
              <span className="text-sm text-muted-foreground px-1">Page {filters.page}</span>
              <Button variant="outline" size="sm" disabled={items.length < 20} onClick={() => filters.setPage(p => p + 1)}>
                Next<ChevronRight size={14} />
              </Button>
            </>
          )}
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader><DialogTitle>New Transaction</DialogTitle></DialogHeader>
          <TransactionForm onSubmit={handleSubmit} onCancel={() => setOpen(false)} />
        </DialogContent>
      </Dialog>

      <EditTransactionDialog txn={editing} onClose={() => setEditing(null)} />
    </div>
  )
}

// Narrow edit surface — description + tags only — matching the server's
// editable_transaction_params whitelist. Anything else (amount, type, date)
// would desync the linked-account balance and stays a CLI-only correction.
function EditTransactionDialog({ txn, onClose }: { txn: Transaction | null; onClose: () => void }) {
  return (
    <Dialog open={!!txn} onOpenChange={v => { if (!v) onClose() }}>
      <DialogContent className="max-w-lg">
        <DialogHeader><DialogTitle>Edit Transaction</DialogTitle></DialogHeader>
        {/* Remount on txn change so the form's useState initializers re-run with
         * the new row's data — avoids the setState-in-useEffect anti-pattern. */}
        {txn && <EditForm key={txn.id} txn={txn} onClose={onClose} />}
      </DialogContent>
    </Dialog>
  )
}

function EditForm({ txn, onClose }: { txn: Transaction; onClose: () => void }) {
  const update = useUpdateTransaction()
  const [description, setDescription] = useState(txn.description ?? '')
  const [tagsInput, setTagsInput] = useState((txn.tags ?? []).join(', '))

  async function save(e: React.FormEvent) {
    e.preventDefault()
    const tags = tagsInput.split(',').map(t => t.trim()).filter(Boolean)
    await update.mutateAsync({
      id: txn.id,
      data: { description: description || null, tags },
    })
    onClose()
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-4">
      <div className="rounded-md border bg-muted/40 px-3 py-2 text-xs text-muted-foreground">
        Only description and tags are editable. Amount, type, account, and date
        are locked once a transaction exists.
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Description</Label>
        <Textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Tags <span className="text-muted-foreground text-xs">(comma-separated)</span></Label>
        <Input value={tagsInput} onChange={e => setTagsInput(e.target.value)} placeholder="rent, utilities" />
      </div>
      <DialogFooter>
        <Button type="button" variant="outline" onClick={onClose}>Cancel</Button>
        <Button type="submit" disabled={update.isPending}>
          {update.isPending ? 'Saving…' : 'Update'}
        </Button>
      </DialogFooter>
    </form>
  )
}
