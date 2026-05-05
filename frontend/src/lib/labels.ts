import type { AccountType, InvestmentType, PlatformType, TermAccountType, TransactionType } from '@/types'

export const TRANSACTION_TYPE_LABELS: Record<TransactionType, string> = {
  credit: 'Credit',
  debit: 'Debit',
}

export const INVESTMENT_TYPE_LABELS: Record<InvestmentType, string> = {
  stock: 'Stock',
  mutual_fund: 'Mutual Fund',
}

export const ACCOUNT_TYPE_LABELS: Record<AccountType, string> = {
  savings: 'Savings',
  current: 'Current',
  salary: 'Salary',
  nre: 'NRE',
  nro: 'NRO',
}

export const TERM_ACCOUNT_TYPE_LABELS: Record<TermAccountType, string> = {
  fd: 'Fixed Deposit',
  ppf: 'PPF',
}

export const PLATFORM_TYPE_LABELS: Record<PlatformType, string> = {
  broker: 'Broker',
  mf_platform: 'MF Platform',
  direct: 'Direct',
  other: 'Other',
}
