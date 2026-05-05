import { startTransition, useEffect, useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SidebarShell } from './SidebarShell'
import { useDepositPPF } from '@/hooks/useTermAccounts'
import type { TermAccount } from '@/types'

const TODAY = new Date().toISOString().split('T')[0]

interface Props {
  open: boolean
  onClose: () => void
  termAccount: TermAccount | null
  currencySymbol: string
}

export function PPFDepositSheet({ open, onClose, termAccount, currencySymbol }: Props) {
  const [amount, setAmount] = useState('')
  const [date, setDate] = useState(TODAY)
  const mutation = useDepositPPF()

  useEffect(() => { if (open) startTransition(() => { setAmount(''); setDate(TODAY) }) }, [open])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!termAccount) return
    await mutation.mutateAsync({ id: termAccount.id, data: { amount: parseFloat(amount), date } })
    onClose()
  }

  const subtitle = termAccount?.account_number ?? `PPF #${termAccount?.id}`

  return (
    <SidebarShell open={open} onClose={onClose} title="PPF Deposit" subtitle={subtitle} onSubmit={handleSubmit} submitLabel="Deposit">
      <div className="flex flex-col gap-1.5">
        <Label>Amount ({currencySymbol})</Label>
        <Input type="number" step="0.01" value={amount} onChange={e => setAmount(e.target.value)} required />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Date</Label>
        <Input type="date" value={date} onChange={e => setDate(e.target.value)} required />
      </div>
    </SidebarShell>
  )
}
