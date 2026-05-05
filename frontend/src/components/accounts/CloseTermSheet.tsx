import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SidebarShell } from './SidebarShell'
import { useCloseTermAccount } from '@/hooks/useTermAccounts'
import type { TermAccount } from '@/types'

const TODAY = new Date().toISOString().split('T')[0]

interface Props {
  open: boolean
  onClose: () => void
  termAccount: TermAccount | null
  currencySymbol: string
}

export function CloseTermSheet({ open, onClose, termAccount, currencySymbol }: Props) {
  const [closedDate, setClosedDate] = useState(TODAY)
  const [closedAmount, setClosedAmount] = useState('')
  const mutation = useCloseTermAccount()

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!termAccount) return
    await mutation.mutateAsync({ id: termAccount.id, data: { closed_date: closedDate, closed_amount: parseFloat(closedAmount) } })
    onClose()
  }

  return (
    <SidebarShell open={open} onClose={onClose} title="Close / Mature Term Account" subtitle={termAccount?.account_number ?? undefined} onSubmit={handleSubmit} submitLabel="Confirm" submitVariant="destructive">
      <div className="flex flex-col gap-1.5">
        <Label>Maturity / Closure Date</Label>
        <Input type="date" value={closedDate} onChange={e => setClosedDate(e.target.value)} required />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Proceeds Received ({currencySymbol})</Label>
        <Input type="number" step="0.01" value={closedAmount} onChange={e => setClosedAmount(e.target.value)} required />
      </div>
    </SidebarShell>
  )
}
