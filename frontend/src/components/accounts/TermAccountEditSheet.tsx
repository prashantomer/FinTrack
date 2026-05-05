import { startTransition, useEffect, useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SidebarShell } from './SidebarShell'
import { useUpdateTermAccount } from '@/hooks/useTermAccounts'
import type { TermAccount } from '@/types'

interface FormState {
  account_number: string
  amount: string
  open_date: string
  interest_rate: string
  maturity_date: string
  maturity_amount: string
  balance: string
}

interface Props {
  open: boolean
  onClose: () => void
  termAccount: TermAccount | null
  currencySymbol: string
}

export function TermAccountEditSheet({ open, onClose, termAccount, currencySymbol }: Props) {
  const [form, setForm] = useState<FormState>({ account_number: '', amount: '', open_date: '', interest_rate: '', maturity_date: '', maturity_amount: '', balance: '' })
  const mutation = useUpdateTermAccount()

  useEffect(() => {
    if (!open || !termAccount) return
    startTransition(() => setForm({
      account_number: termAccount.account_number ?? '',
      amount: String(termAccount.amount),
      open_date: termAccount.open_date,
      interest_rate: String(termAccount.interest_rate),
      maturity_date: termAccount.maturity_date,
      maturity_amount: termAccount.maturity_amount ? String(termAccount.maturity_amount) : '',
      balance: String(termAccount.balance),
    }))
  }, [open, termAccount])

  function set<K extends keyof FormState>(key: K, value: string) {
    setForm(f => ({ ...f, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!termAccount) return
    await mutation.mutateAsync({
      id: termAccount.id,
      data: {
        account_number: form.account_number || null,
        amount: form.amount ? parseFloat(form.amount) : undefined,
        open_date: form.open_date || undefined,
        interest_rate: form.interest_rate ? parseFloat(form.interest_rate) : undefined,
        maturity_date: form.maturity_date || undefined,
        maturity_amount: form.maturity_amount ? parseFloat(form.maturity_amount) : undefined,
        balance: form.balance !== '' ? parseFloat(form.balance) : undefined,
      },
    })
    onClose()
  }

  const subtitle = termAccount?.account_number ?? `${termAccount?.type.toUpperCase()} #${termAccount?.id}`

  return (
    <SidebarShell open={open} onClose={onClose} title="Edit Term Account" subtitle={subtitle} onSubmit={handleSubmit} submitLabel="Save">
      <div className="flex flex-col gap-1.5">
        <div className="flex items-center justify-between">
          <Label>Account No.</Label>
          <span className="text-xs text-muted-foreground">optional</span>
        </div>
        <Input value={form.account_number} onChange={e => set('account_number', e.target.value)} />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Amount ({currencySymbol})</Label>
        <Input type="number" step="0.01" value={form.amount} onChange={e => set('amount', e.target.value)} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label>Open Date</Label>
          <Input type="date" value={form.open_date} onChange={e => set('open_date', e.target.value)} />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Interest Rate (%)</Label>
          <Input type="number" step="0.01" value={form.interest_rate} onChange={e => set('interest_rate', e.target.value)} />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label>Maturity Date</Label>
          <Input type="date" value={form.maturity_date} onChange={e => set('maturity_date', e.target.value)} />
        </div>
        {termAccount?.type === 'fd' && (
          <div className="flex flex-col gap-1.5">
            <Label>Maturity Amt ({currencySymbol})</Label>
            <Input type="number" step="0.01" value={form.maturity_amount} onChange={e => set('maturity_amount', e.target.value)} />
          </div>
        )}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Current Balance ({currencySymbol})</Label>
        <Input type="number" step="0.01" value={form.balance} onChange={e => set('balance', e.target.value)} />
      </div>
    </SidebarShell>
  )
}
