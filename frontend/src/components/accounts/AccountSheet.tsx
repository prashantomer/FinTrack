import { startTransition, useEffect, useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { SidebarShell } from './SidebarShell'
import { useCreateAccount, useUpdateAccount } from '@/hooks/useBanks'
import { ACCOUNT_TYPE_LABELS } from '@/lib/labels'
import type { Account, AccountType, Bank } from '@/types'

interface FormState {
  bank_id: string
  nickname: string
  account_number: string
  account_type: AccountType
  balance: string
  open_date: string
}

const TODAY = new Date().toISOString().split('T')[0]

const DEFAULT: FormState = {
  bank_id: '', nickname: '', account_number: '',
  account_type: 'savings', balance: '', open_date: TODAY,
}

interface Props {
  open: boolean
  onClose: () => void
  initial: Account | null
  banks: Bank[]
  currencySymbol: string
}

export function AccountSheet({ open, onClose, initial, banks, currencySymbol }: Props) {
  const [form, setForm] = useState<FormState>(DEFAULT)
  const createMutation = useCreateAccount()
  const updateMutation = useUpdateAccount()

  useEffect(() => {
    if (!open) return
    if (initial) {
      startTransition(() => setForm({
        bank_id: initial.bank_id.toString(),
        nickname: initial.nickname,
        account_number: initial.account_number ?? '',
        account_type: initial.account_type,
        balance: String(initial.balance),
        open_date: initial.open_date ?? '',
      }))
    } else {
      startTransition(() => setForm(DEFAULT))
    }
  }, [open, initial])

  function set<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm(f => ({ ...f, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const payload = {
      bank_id: Number(form.bank_id),
      nickname: form.nickname,
      account_number: form.account_number || undefined,
      account_type: form.account_type,
      balance: form.balance !== '' ? parseFloat(form.balance) : undefined,
      open_date: form.open_date || undefined,
    }
    if (initial) {
      await updateMutation.mutateAsync({ id: initial.id, data: payload })
    } else {
      await createMutation.mutateAsync(payload)
    }
    onClose()
  }

  return (
    <SidebarShell
      open={open} onClose={onClose}
      title={initial ? 'Edit Account' : 'New Bank Account'}
      subtitle={initial ? `${initial.nickname} · ${initial.bank?.name}` : undefined}
      onSubmit={handleSubmit}
      submitLabel={initial ? 'Update' : 'Create'}
    >
      <div className="flex flex-col gap-1.5">
        <Label>Bank</Label>
        <Select value={form.bank_id} onValueChange={v => v && set('bank_id', v)}>
          <SelectTrigger><SelectValue placeholder="Select bank…" /></SelectTrigger>
          <SelectContent>
            {banks.map(b => <SelectItem key={b.id} value={b.id.toString()}>{b.name}</SelectItem>)}
          </SelectContent>
        </Select>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Nickname</Label>
        <Input value={form.nickname} onChange={e => set('nickname', e.target.value)} required />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label>Account Type</Label>
          <Select value={form.account_type} onValueChange={v => v && set('account_type', v as AccountType)}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              {(Object.keys(ACCOUNT_TYPE_LABELS) as AccountType[]).map(t => (
                <SelectItem key={t} value={t}>{ACCOUNT_TYPE_LABELS[t]}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between">
            <Label>Account No.</Label>
            <span className="text-xs text-muted-foreground">optional</span>
          </div>
          <Input value={form.account_number} onChange={e => set('account_number', e.target.value)} />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between">
            <Label>Balance ({currencySymbol})</Label>
            <span className="text-xs text-muted-foreground">optional</span>
          </div>
          <Input type="number" step="0.01" placeholder="0" value={form.balance} onChange={e => set('balance', e.target.value)} />
        </div>
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between">
            <Label>Open Date</Label>
            <span className="text-xs text-muted-foreground">optional</span>
          </div>
          <Input type="date" value={form.open_date} onChange={e => set('open_date', e.target.value)} />
        </div>
      </div>
    </SidebarShell>
  )
}
