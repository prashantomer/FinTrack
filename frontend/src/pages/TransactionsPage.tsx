import { useEffect, useState } from 'react'
import { Plus, Search } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { TransactionForm } from '@/components/transactions/TransactionForm'
import { useAccounts } from '@/hooks/useBanks'
import { useTermAccounts } from '@/hooks/useTermAccounts'
import { useCreateTransaction, useTransactions } from '@/hooks/useTransactions'
import { TRANSACTION_TYPE_LABELS } from '@/lib/labels'
import { useCurrency } from '@/hooks/useCurrency'
import type { LinkedAccountType, TransactionCreate, TransactionType } from '@/types'
const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })

export function TransactionsPage() {
  const { formatCurrency } = useCurrency()
  const fmt = { format: formatCurrency }
  const [page, setPage] = useState(1)
  const [typeFilter, setTypeFilter] = useState<string>('all')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const t = setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, 350)
    return () => clearTimeout(t)
  }, [searchInput])

  const params = {
    page,
    page_size: 20,
    ...(typeFilter !== 'all' && { type: typeFilter as TransactionType }),
    ...(dateFrom && { date_from: dateFrom }),
    ...(dateTo && { date_to: dateTo }),
    ...(search && { search }),
  }

  const { data, isLoading } = useTransactions(params)
  const { data: accounts } = useAccounts()
  const { data: termAccounts } = useTermAccounts()
  const createMutation = useCreateTransaction()

  const accountLabel = (type: LinkedAccountType | null, id: number | null): string => {
    if (!type || !id) return '—'
    if (type === 'account') {
      const a = accounts?.find(a => a.id === id)
      return a ? `${a.bank.short_name} · ${a.nickname}` : `Account #${id}`
    }
    const ta = termAccounts?.find(ta => ta.id === id)
    if (!ta) return `Term #${id}`
    const label = ta.account_number || `#${ta.id}`
    return `${ta.bank.short_name} · ${ta.type.toUpperCase()} ${label}`
  }

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
    const tags = values.tags_input
      .split(',')
      .map(t => t.trim())
      .filter(Boolean)

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

  const items = data?.items ?? []

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Transactions</h1>
        <Button onClick={() => setOpen(true)}><Plus size={16} className="mr-1" />Add</Button>
      </div>

      <div className="flex flex-wrap gap-3">
        <div className="relative">
          <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
          <Input
            placeholder="Search description, ref, tags…"
            value={searchInput}
            onChange={e => setSearchInput(e.target.value)}
            className="pl-8 w-64"
          />
        </div>
        <Select value={typeFilter} onValueChange={(v) => { v && setTypeFilter(v); setPage(1) }}>
          <SelectTrigger className="w-32"><SelectValue placeholder="Type" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Types</SelectItem>
            {(Object.keys(TRANSACTION_TYPE_LABELS) as TransactionType[]).map(t => (
              <SelectItem key={t} value={t}>{TRANSACTION_TYPE_LABELS[t]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Input type="date" value={dateFrom} onChange={e => { setDateFrom(e.target.value); setPage(1) }} className="w-36" />
        <Input type="date" value={dateTo} onChange={e => { setDateTo(e.target.value); setPage(1) }} className="w-36" />
      </div>

      {isLoading ? (
        <div className="text-muted-foreground">Loading…</div>
      ) : (
        <div className="rounded-lg border overflow-hidden">
          <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Account</TableHead>
              <TableHead>Description</TableHead>
              <TableHead>Tags</TableHead>
              <TableHead>Type</TableHead>
              <TableHead className="text-right">Amount</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {items.map(t => (
              <TableRow key={t.id} className={t.is_active ? '' : 'opacity-40 line-through'}>
                <TableCell className="text-muted-foreground text-sm whitespace-nowrap">{fmtDate(t.date)}</TableCell>
                <TableCell className="text-sm whitespace-nowrap">{accountLabel(t.linked_account_type, t.linked_account_id)}</TableCell>
                <TableCell>
                  <div>{t.description || '—'}</div>
                  {t.public_id && (
                    <div className="text-xs text-muted-foreground font-mono">{t.public_id}</div>
                  )}
                  {t.bank_ref && t.bank_ref !== t.public_id && (
                    <div className="text-xs text-muted-foreground">Bank ref: <span className="font-mono">{t.bank_ref}</span></div>
                  )}
                </TableCell>
                <TableCell>
                  {t.tags && t.tags.length > 0 ? (
                    <div className="flex flex-wrap gap-1">
                      {t.tags.map(tag => (
                        <Badge key={tag} variant="secondary" className="text-xs">{tag}</Badge>
                      ))}
                    </div>
                  ) : (
                    <span className="text-muted-foreground text-xs">—</span>
                  )}
                </TableCell>
                <TableCell>
                  <Badge variant={t.type === 'credit' ? 'default' : 'secondary'}>
                    {TRANSACTION_TYPE_LABELS[t.type]}
                  </Badge>
                </TableCell>
                <TableCell className={`text-right font-mono font-medium ${t.type === 'credit' ? 'text-green-600' : 'text-red-500'}`}>
                  {t.type === 'credit' ? '+' : '-'}{fmt.format(t.amount)}
                </TableCell>
              </TableRow>
            ))}
            {items.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} className="text-center text-muted-foreground py-8">No transactions</TableCell>
              </TableRow>
            )}
          </TableBody>
          </Table>
        </div>
      )}

      {data && data.total > 20 && (
        <div className="flex items-center gap-3">
          <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(p => p - 1)}>Prev</Button>
          <span className="text-sm text-muted-foreground">Page {page}</span>
          <Button variant="outline" size="sm" disabled={items.length < 20} onClick={() => setPage(p => p + 1)}>Next</Button>
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>New Transaction</DialogTitle>
          </DialogHeader>
          <TransactionForm onSubmit={handleSubmit} onCancel={() => setOpen(false)} />
        </DialogContent>
      </Dialog>
    </div>
  )
}
