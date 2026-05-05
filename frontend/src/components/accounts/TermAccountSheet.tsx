import { startTransition, useEffect, useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { SidebarShell } from './SidebarShell'
import { useCreateTermAccount } from '@/hooks/useTermAccounts'
import { ACCOUNT_TYPE_LABELS, TERM_ACCOUNT_TYPE_LABELS } from '@/lib/labels'
import type { Account, TermAccountType } from '@/types'

interface FormState {
  parent_account_id: string
  type: TermAccountType
  account_number: string
  amount: string
  open_date: string
  tenure_days: string
  interest_rate: string
  maturity_amount: string
  balance: string
}

const TODAY = new Date().toISOString().split('T')[0]

const DEFAULT: FormState = {
  parent_account_id: '', type: 'fd', account_number: '',
  amount: '', open_date: TODAY, tenure_days: '',
  interest_rate: '', maturity_amount: '', balance: '',
}

interface Props {
  open: boolean
  onClose: () => void
  parentCandidates: Account[]
  formatCurrency: (v: number) => string
  currencySymbol: string
}

export function TermAccountSheet({ open, onClose, parentCandidates, formatCurrency, currencySymbol }: Props) {
  const [form, setForm] = useState<FormState>(DEFAULT)
  const createMutation = useCreateTermAccount()

  useEffect(() => { if (open) startTransition(() => setForm(DEFAULT)) }, [open])

  function set<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm(f => ({ ...f, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    await createMutation.mutateAsync({
      parent_account_id: Number(form.parent_account_id),
      type: form.type,
      account_number: form.account_number || undefined,
      amount: parseFloat(form.amount),
      open_date: form.open_date,
      tenure_days: form.type === 'fd' ? parseInt(form.tenure_days) : undefined,
      interest_rate: parseFloat(form.interest_rate),
      maturity_amount: form.maturity_amount ? parseFloat(form.maturity_amount) : undefined,
      balance: form.balance !== '' ? parseFloat(form.balance) : undefined,
    })
    onClose()
  }

  return (
    <SidebarShell open={open} onClose={onClose} title="New FD / PPF Account" onSubmit={handleSubmit} submitLabel="Create">
      <div className="flex flex-col gap-1.5">
        <Label>Type</Label>
        <Select value={form.type} onValueChange={v => v && setForm(f => ({ ...f, type: v as TermAccountType, tenure_days: '', maturity_amount: '' }))}>
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            {(Object.keys(TERM_ACCOUNT_TYPE_LABELS) as TermAccountType[]).map(t => (
              <SelectItem key={t} value={t}>{TERM_ACCOUNT_TYPE_LABELS[t]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Linked Savings / Current Account</Label>
        <Select value={form.parent_account_id} onValueChange={v => v && set('parent_account_id', v)}>
          <SelectTrigger><SelectValue placeholder="Select account…" /></SelectTrigger>
          <SelectContent>
            {parentCandidates.map(a => (
              <SelectItem key={a.id} value={a.id.toString()}>
                {a.nickname} · {a.bank.short_name} ({ACCOUNT_TYPE_LABELS[a.account_type]}) — {formatCurrency(a.balance)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label>Opening Balance ({currencySymbol})</Label>
          <Input type="number" step="0.01" value={form.amount} onChange={e => set('amount', e.target.value)} required />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Open Date</Label>
          <Input type="date" value={form.open_date} onChange={e => set('open_date', e.target.value)} required />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label>Interest Rate (%)</Label>
          <Input type="number" step="0.01" value={form.interest_rate} onChange={e => set('interest_rate', e.target.value)} required />
        </div>
        {form.type === 'fd' && (
          <div className="flex flex-col gap-1.5">
            <Label>Tenure (days)</Label>
            <Input type="number" value={form.tenure_days} onChange={e => set('tenure_days', e.target.value)} required />
          </div>
        )}
      </div>
      {form.type === 'fd' && (
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between">
            <Label>Maturity Amount ({currencySymbol})</Label>
            <span className="text-xs text-muted-foreground">auto-calculated</span>
          </div>
          <Input type="number" step="0.01" value={form.maturity_amount} onChange={e => set('maturity_amount', e.target.value)} />
        </div>
      )}
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between">
            <Label>Account No.</Label>
            <span className="text-xs text-muted-foreground">optional</span>
          </div>
          <Input value={form.account_number} onChange={e => set('account_number', e.target.value)} />
        </div>
        {form.type === 'ppf' && (
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <Label>Balance ({currencySymbol})</Label>
              <span className="text-xs text-muted-foreground">optional</span>
            </div>
            <Input type="number" step="0.01" placeholder="0" value={form.balance} onChange={e => set('balance', e.target.value)} />
          </div>
        )}
      </div>
    </SidebarShell>
  )
}
