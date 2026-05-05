import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SidebarShell } from './SidebarShell'
import { useCloseAccount } from '@/hooks/useBanks'
import type { Account } from '@/types'

const TODAY = new Date().toISOString().split('T')[0]

interface Props {
  open: boolean
  onClose: () => void
  account: Account | null
  currencySymbol: string
}

export function CloseAccountSheet({ open, onClose, account, currencySymbol }: Props) {
  const [closedDate, setClosedDate] = useState(TODAY)
  const [closedAmount, setClosedAmount] = useState('')
  const mutation = useCloseAccount()

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!account) return
    await mutation.mutateAsync({ id: account.id, data: { closed_date: closedDate, closed_amount: parseFloat(closedAmount) } })
    onClose()
  }

  return (
    <SidebarShell open={open} onClose={onClose} title="Close Account" subtitle={account?.nickname} onSubmit={handleSubmit} submitLabel="Close Account" submitVariant="destructive">
      <div className="flex flex-col gap-1.5">
        <Label>Closure Date</Label>
        <Input type="date" value={closedDate} onChange={e => setClosedDate(e.target.value)} required />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label>Final Balance at Closure ({currencySymbol})</Label>
        <Input type="number" step="0.01" value={closedAmount} onChange={e => setClosedAmount(e.target.value)} required />
      </div>
    </SidebarShell>
  )
}
