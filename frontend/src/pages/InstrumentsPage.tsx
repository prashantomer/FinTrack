import { useState } from 'react'
import { Plus } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useCreateInstrument, useInstruments, useTrackInstrument, useUntrackInstrument } from '@/hooks/useInstruments'
import { useTrackedInstruments } from '@/hooks/useInstruments'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { InvestmentType } from '@/types'

const INVESTMENT_TYPES = Object.keys(INVESTMENT_TYPE_LABELS) as InvestmentType[]

interface FormState {
  name: string
  type: InvestmentType
  ticker_symbol: string
  isin: string
  exchange: string
  fund_house: string
}

const DEFAULT_FORM: FormState = {
  name: '', type: 'stock', ticker_symbol: '', isin: '', exchange: '', fund_house: '',
}

export function InstrumentsPage() {
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState<string>('all')
  const [open, setOpen] = useState(false)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)

  const { data: instruments = [], isLoading } = useInstruments({
    search: search || undefined,
    type: typeFilter !== 'all' ? typeFilter as InvestmentType : undefined,
  })
  const { data: tracked = [] } = useTrackedInstruments()
  const trackedIds = new Set(tracked.map(i => i.id))

  const createMutation = useCreateInstrument()
  const trackMutation = useTrackInstrument()
  const untrackMutation = useUntrackInstrument()

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    await createMutation.mutateAsync({
      name: form.name,
      type: form.type,
      ticker_symbol: form.ticker_symbol || undefined,
      isin: form.isin || undefined,
      exchange: form.exchange || undefined,
      fund_house: form.fund_house || undefined,
    })
    setOpen(false)
    setForm(DEFAULT_FORM)
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Instruments</h1>
        <Button onClick={() => setOpen(true)}><Plus size={16} className="mr-1" />Add Instrument</Button>
      </div>

      <div className="flex gap-3">
        <Input
          placeholder="Search by name…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="max-w-xs"
        />
        <Select value={typeFilter} onValueChange={(v) => v && setTypeFilter(v)}>
          <SelectTrigger className="w-40"><SelectValue placeholder="All types" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Types</SelectItem>
            {INVESTMENT_TYPES.map(t => <SelectItem key={t} value={t}>{INVESTMENT_TYPE_LABELS[t]}</SelectItem>)}
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
              <TableHead>Name</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Ticker</TableHead>
              <TableHead>Exchange</TableHead>
              <TableHead>Fund House</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {instruments.map(inst => (
              <TableRow key={inst.id}>
                <TableCell className="font-medium">{inst.name}</TableCell>
                <TableCell><Badge variant="outline">{INVESTMENT_TYPE_LABELS[inst.type]}</Badge></TableCell>
                <TableCell className="font-mono text-sm text-muted-foreground">{inst.ticker_symbol || '—'}</TableCell>
                <TableCell className="text-sm text-muted-foreground">{inst.exchange || '—'}</TableCell>
                <TableCell className="text-sm text-muted-foreground">{inst.fund_house || '—'}</TableCell>
                <TableCell className="text-right">
                  {trackedIds.has(inst.id) ? (
                    <Button size="sm" variant="outline" onClick={() => untrackMutation.mutate(inst.id)}>
                      Untrack
                    </Button>
                  ) : (
                    <Button size="sm" onClick={() => trackMutation.mutate(inst.id)}>
                      Track
                    </Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
            {instruments.length === 0 && (
              <TableRow><TableCell colSpan={6} className="text-center text-muted-foreground py-8">No instruments found</TableCell></TableRow>
            )}
          </TableBody>
          </Table>
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader><DialogTitle>Add Instrument</DialogTitle></DialogHeader>
          <form onSubmit={handleCreate} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Label>Name</Label>
              <Input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} required />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label>Type</Label>
              <Select value={form.type} onValueChange={(v) => v && setForm(f => ({ ...f, type: v as InvestmentType }))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {INVESTMENT_TYPES.map(t => <SelectItem key={t} value={t}>{INVESTMENT_TYPE_LABELS[t]}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="flex flex-col gap-1.5">
                <Label>Ticker Symbol</Label>
                <Input value={form.ticker_symbol} onChange={e => setForm(f => ({ ...f, ticker_symbol: e.target.value }))} />
              </div>
              <div className="flex flex-col gap-1.5">
                <Label>Exchange</Label>
                <Input value={form.exchange} onChange={e => setForm(f => ({ ...f, exchange: e.target.value }))} placeholder="NSE / BSE" />
              </div>
              <div className="flex flex-col gap-1.5">
                <Label>ISIN</Label>
                <Input value={form.isin} onChange={e => setForm(f => ({ ...f, isin: e.target.value }))} />
              </div>
              <div className="flex flex-col gap-1.5">
                <Label>Fund House</Label>
                <Input value={form.fund_house} onChange={e => setForm(f => ({ ...f, fund_house: e.target.value }))} />
              </div>
            </div>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
              <Button type="submit">Create</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}
