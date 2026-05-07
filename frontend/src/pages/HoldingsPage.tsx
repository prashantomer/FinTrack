import { useMemo, useState } from 'react'
import { ChevronLeft, ChevronRight, Pencil, Plus, Trash2 } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { PageHeader } from '@/components/layout/PageHeader'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useCreateFollio, useDeleteFollio, useFollios, useUpdateFollio } from '@/hooks/useFollios'
import { useInvestments } from '@/hooks/useInvestments'
import { useUserInstruments } from '@/hooks/useInstruments'
import { usePlatformAccounts } from '@/hooks/usePlatforms'
import { useCurrency } from '@/hooks/useCurrency'
import { calcGainLoss } from '@/lib/finance'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Follio, InvestmentType, PlatformAccount } from '@/types'

interface FormState {
  follio_id: string
  user_instrument_id: string
  platform_account_id: string
}

const DEFAULT_FORM: FormState = { follio_id: '', user_instrument_id: '', platform_account_id: '' }
const PAGE_SIZE = 25
const TABS: { label: string; value: InvestmentType | 'all' }[] = [
  { label: 'All', value: 'all' },
  { label: 'Stocks', value: 'stock' },
  { label: 'Mutual Funds', value: 'mutual_fund' },
]

export function HoldingsPage() {
  const qc = useQueryClient()
  const { formatCurrency } = useCurrency()
  const [page, setPage] = useState(1)
  const [activeTab, setActiveTab] = useState<InvestmentType | 'all'>('all')

  const { data, isLoading, isFetching } = useInvestments(
    activeTab !== 'all' ? [activeTab] : undefined,
    page,
    PAGE_SIZE
  )
  const { data: platformAccounts = [] } = usePlatformAccounts()
  const { data: folliosData } = useFollios(1, 500)
  const { data: userInstruments = [] } = useUserInstruments()

  const investments = data?.items ?? []
  const total = data?.total ?? 0
  const totalPages = Math.ceil(total / PAGE_SIZE)

  const platformMap = useMemo(() => {
    const map = new Map<number, PlatformAccount>()
    for (const pa of platformAccounts) map.set(pa.id, pa)
    return map
  }, [platformAccounts])

  // Follio lookup by user_instrument_id for showing the follio ref
  const follioByInstrument = useMemo(() => {
    const map = new Map<number, Follio>()
    for (const f of folliosData?.items ?? []) {
      if (f.user_instrument_id != null) map.set(f.user_instrument_id, f)
    }
    return map
  }, [folliosData])

  const createMutation = useCreateFollio()
  const updateMutation = useUpdateFollio()
  const deleteMutation = useDeleteFollio()

  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Follio | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)

  function openCreate() {
    setEditing(null)
    setForm(DEFAULT_FORM)
    setOpen(true)
  }

  function openEdit(f: Follio) {
    setEditing(f)
    setForm({
      follio_id: f.follio_id,
      user_instrument_id: f.user_instrument_id.toString(),
      platform_account_id: f.platform_account_id.toString(),
    })
    setOpen(true)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (editing) {
      await updateMutation.mutateAsync({ id: editing.id, data: { follio_id: form.follio_id } })
    } else {
      await createMutation.mutateAsync({
        follio_id: form.follio_id,
        user_instrument_id: Number(form.user_instrument_id),
        platform_account_id: Number(form.platform_account_id),
      })
    }
    setOpen(false)
  }

  function handleTabChange(tab: InvestmentType | 'all') {
    setActiveTab(tab)
    setPage(1)
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Holdings"
        description="Investments you hold across platforms"
        onRefresh={() => {
          qc.invalidateQueries({ queryKey: ['investments'] })
          qc.invalidateQueries({ queryKey: ['follios'] })
        }}
        isRefreshing={isFetching}
      >
        <Button onClick={openCreate}><Plus size={16} className="mr-1" />Add Follio Ref</Button>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-4">
        {/* Type tabs */}
        <div className="flex gap-1 border-b">
          {TABS.map(tab => (
            <button
              key={tab.value}
              onClick={() => handleTabChange(tab.value)}
              className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors -mb-px ${
                activeTab === tab.value
                  ? 'border-primary text-primary'
                  : 'border-transparent text-muted-foreground hover:text-foreground'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="rounded-lg border overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Instrument</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Platform</TableHead>
                  <TableHead>Follio / Ref</TableHead>
                  <TableHead className="text-right">Units / Qty</TableHead>
                  <TableHead className="text-right">Invested</TableHead>
                  <TableHead className="text-right">Current Value</TableHead>
                  <TableHead className="text-right">Gain / Loss</TableHead>
                  <TableHead>Since</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {investments.map(inv => {
                  const platform = inv.platform_account_id ? platformMap.get(inv.platform_account_id) : null
                  const follio = inv.user_instrument_id ? follioByInstrument.get(inv.user_instrument_id) : null
                  const units = inv.units ?? inv.quantity ?? null
                  const currentVal = inv.current_value ?? inv.amount_invested
                  const { gain, pct, isPositive } = calcGainLoss(inv.amount_invested, currentVal)
                  return (
                    <TableRow key={inv.id}>
                      <TableCell className="font-medium">{inv.name}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{INVESTMENT_TYPE_LABELS[inv.type]}</Badge>
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm">
                        {platform
                          ? <>{platform.nickname} <span className="text-xs">({platform.platform.short_name})</span></>
                          : <span className="text-xs">—</span>}
                      </TableCell>
                      <TableCell className="font-mono text-xs text-muted-foreground">
                        {follio ? follio.follio_id : <span>—</span>}
                      </TableCell>
                      <TableCell className="text-right font-mono text-sm">
                        {units != null ? units.toLocaleString('en-IN') : <span className="text-muted-foreground">—</span>}
                      </TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(inv.amount_invested)}</TableCell>
                      <TableCell className="text-right font-mono">{formatCurrency(currentVal)}</TableCell>
                      <TableCell className={`text-right font-mono font-medium ${isPositive ? 'text-green-600' : 'text-red-500'}`}>
                        {isPositive ? '+' : ''}{formatCurrency(gain)} ({pct}%)
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm">{inv.purchase_date}</TableCell>
                      <TableCell className="text-right">
                        {follio && (
                          <div className="flex gap-1 justify-end">
                            <Button size="icon" variant="ghost" onClick={() => openEdit(follio)}><Pencil size={14} /></Button>
                            <Button size="icon" variant="ghost" onClick={() => deleteMutation.mutate(follio.id)}><Trash2 size={14} /></Button>
                          </div>
                        )}
                      </TableCell>
                    </TableRow>
                  )
                })}
                {investments.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={10} className="text-center text-muted-foreground py-8">
                      No holdings found{activeTab !== 'all' ? ` for ${INVESTMENT_TYPE_LABELS[activeTab]}` : ''}.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        )}

      </div>

      {totalPages > 1 ? (
        <div className="border-t bg-background px-6 py-3 shrink-0 flex items-center justify-between text-sm">
          <span className="text-muted-foreground">{total} total</span>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => setPage(p => p - 1)} disabled={page === 1}>
              <ChevronLeft size={14} />Prev
            </Button>
            <span className="text-muted-foreground px-1">Page {page} of {totalPages}</span>
            <Button variant="outline" size="sm" onClick={() => setPage(p => p + 1)} disabled={page >= totalPages}>
              Next<ChevronRight size={14} />
            </Button>
          </div>
        </div>
      ) : total > 0 && (
        <div className="border-t bg-background px-6 py-2 shrink-0 text-center text-xs text-muted-foreground">
          {total} holdings
        </div>
      )}

      {/* Sheet for adding/editing follio reference */}
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="right" className="w-[400px] sm:max-w-[420px] flex flex-col p-0 overflow-hidden">
          <SheetHeader className="border-b px-6 py-5 shrink-0">
            <SheetTitle className="text-base">{editing ? 'Edit Follio Ref' : 'Add Follio Ref'}</SheetTitle>
          </SheetHeader>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">
              {!editing && (
                <>
                  <div className="flex flex-col gap-1.5">
                    <Label>Instrument <span className="text-muted-foreground text-xs">(tracked only)</span></Label>
                    <Select
                      value={form.user_instrument_id}
                      onValueChange={v => v && setForm(f => ({ ...f, user_instrument_id: v }))}
                    >
                      <SelectTrigger><SelectValue placeholder="Select instrument…" /></SelectTrigger>
                      <SelectContent>
                        {userInstruments.map(ui => (
                          <SelectItem key={ui.id} value={ui.id.toString()}>
                            {ui.instrument.name}
                            <span className="ml-1 text-muted-foreground text-xs">
                              ({INVESTMENT_TYPE_LABELS[ui.instrument.type]})
                            </span>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col gap-1.5">
                    <Label>Platform Account</Label>
                    <Select
                      value={form.platform_account_id}
                      onValueChange={v => v && setForm(f => ({ ...f, platform_account_id: v }))}
                    >
                      <SelectTrigger><SelectValue placeholder="Select platform account…" /></SelectTrigger>
                      <SelectContent>
                        {platformAccounts.map(pa => (
                          <SelectItem key={pa.id} value={pa.id.toString()}>
                            {pa.nickname}
                            <span className="ml-1 text-muted-foreground text-xs">({pa.platform.short_name})</span>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </>
              )}
              <div className="flex flex-col gap-1.5">
                <Label>Follio / Reference ID</Label>
                <Input
                  value={form.follio_id}
                  onChange={e => setForm(f => ({ ...f, follio_id: e.target.value }))}
                  placeholder="e.g. 12345678 or ZER-RELIANCE-01"
                  required
                />
                <p className="text-xs text-muted-foreground">MF folio number, demat holding ref, or any unique identifier</p>
              </div>
            </div>
            <div className="border-t px-6 py-4 flex justify-end gap-2 shrink-0">
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
              <Button type="submit">{editing ? 'Update' : 'Create'}</Button>
            </div>
          </form>
        </SheetContent>
      </Sheet>
    </div>
  )
}
