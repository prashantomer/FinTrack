import type { Account, LinkedAccountType, TermAccount } from '@/types'

export function resolveAccountLabel(
  type: LinkedAccountType | null,
  id: number | null,
  accounts: Account[],
  termAccounts: TermAccount[],
): string {
  if (!type || !id) return '—'
  if (type === 'account') {
    const a = accounts.find(a => a.id === id)
    return a ? `${a.bank.short_name} · ${a.nickname}` : `Account #${id}`
  }
  const ta = termAccounts.find(ta => ta.id === id)
  if (!ta) return `Term #${id}`
  const label = ta.account_number || `#${ta.id}`
  return `${ta.bank.short_name} · ${ta.type.toUpperCase()} ${label}`
}

export interface GainLoss {
  gain: number
  pct: string
  isPositive: boolean
}

export function calcGainLoss(amountInvested: number, currentValue: number | null): GainLoss {
  const cv = currentValue ?? amountInvested
  const gain = cv - amountInvested
  const pct = amountInvested !== 0 ? ((gain / amountInvested) * 100).toFixed(1) : '0.0'
  return { gain, pct, isPositive: gain >= 0 }
}
