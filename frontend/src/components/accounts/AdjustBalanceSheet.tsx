import { startTransition, useEffect, useState } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SidebarShell } from './SidebarShell'
import { useAdjustAccountBalance } from '@/hooks/useBanks'
import { useAdjustTermAccountBalance } from '@/hooks/useTermAccounts'
import type { Account, TermAccount } from '@/types'

interface Props {
  open: boolean
  onClose: () => void
  account: Account | null
  termAccount: TermAccount | null
  currencySymbol: string
}

export function AdjustBalanceSheet({ open, onClose, account, termAccount, currencySymbol }: Props) {
  const [balance, setBalance] = useState('')
  const adjustAccount = useAdjustAccountBalance()
  const adjustTerm = useAdjustTermAccountBalance()

  useEffect(() => {
    if (!open) return
    if (account) startTransition(() => setBalance(String(account.balance)))
    else if (termAccount) startTransition(() => setBalance(String(termAccount.balance)))
  }, [open, account, termAccount])

  const subtitle = account?.nickname ?? termAccount?.account_number ?? `${termAccount?.type.toUpperCase()} #${termAccount?.id}`

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const data = { balance: parseFloat(balance) }
    if (account) await adjustAccount.mutateAsync({ id: account.id, data })
    else if (termAccount) await adjustTerm.mutateAsync({ id: termAccount.id, data })
    onClose()
  }

  return (
    <SidebarShell open={open} onClose={onClose} title="Adjust Balance" subtitle={subtitle} onSubmit={handleSubmit} submitLabel="Save">
      <div className="flex flex-col gap-1.5">
        <Label>New Balance ({currencySymbol})</Label>
        <Input type="number" step="0.01" value={balance} onChange={e => setBalance(e.target.value)} required />
      </div>
    </SidebarShell>
  )
}
