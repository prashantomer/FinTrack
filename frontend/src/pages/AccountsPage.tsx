import { useMemo, useState } from 'react'
import { CalendarClock, Plus } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { PageHeader } from '@/components/layout/PageHeader'
import { AuditLogSidebar } from '@/components/accounts/AuditLogSidebar'
import { AccountSheet } from '@/components/accounts/AccountSheet'
import { AccountsTable } from '@/components/accounts/AccountsTable'
import { AdjustBalanceSheet } from '@/components/accounts/AdjustBalanceSheet'
import { CloseAccountSheet } from '@/components/accounts/CloseAccountSheet'
import { CloseTermSheet } from '@/components/accounts/CloseTermSheet'
import { MaturitiesSheet } from '@/components/accounts/MaturitiesSheet'
import { PPFDepositSheet } from '@/components/accounts/PPFDepositSheet'
import { TermAccountEditSheet } from '@/components/accounts/TermAccountEditSheet'
import { TermAccountSheet } from '@/components/accounts/TermAccountSheet'
import { TermAccountsTable } from '@/components/accounts/TermAccountsTable'
import { useAccounts, useBanks } from '@/hooks/useBanks'
import { useTermAccounts } from '@/hooks/useTermAccounts'
import type { AuditTarget } from '@/hooks/useAuditLogs'
import { useCurrency } from '@/hooks/useCurrency'
import type { Account, TermAccount, TermAccountSummary } from '@/types'

const MATURITY_HORIZON_DAYS = 90

type SheetState =
  | { kind: 'account'; target: Account | null }
  | { kind: 'close-account'; target: Account }
  | { kind: 'adjust-account'; target: Account }
  | { kind: 'term-create' }
  | { kind: 'term-edit'; target: TermAccount }
  | { kind: 'close-term'; target: TermAccount }
  | { kind: 'adjust-term'; target: TermAccount }
  | { kind: 'ppf-deposit'; target: TermAccount }
  | { kind: 'audit'; target: NonNullable<AuditTarget> }
  | null

export function AccountsPage() {
  const qc = useQueryClient()
  const { formatCurrency, symbol } = useCurrency()
  const [sheet, setSheet] = useState<SheetState>(null)
  const [maturitiesOpen, setMaturitiesOpen] = useState(false)

  const { data: accounts = [], isLoading, isFetching } = useAccounts()
  const { data: banks = [] } = useBanks()
  const { data: termAccountsAll = [] } = useTermAccounts()

  const close = () => setSheet(null)
  const totalBalance = accounts.reduce((sum, a) => sum + (a.balance ?? 0), 0)
  const parentCandidates = accounts.filter(a => !a.closed_date && (a.account_type === 'savings' || a.account_type === 'current'))

  const upcomingMaturities = useMemo<TermAccountSummary[]>(() => {
    const now = new Date()
    const todayMs = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    return termAccountsAll
      .filter(t => t.is_active && t.maturity_date)
      .map(t => {
        const [y, m, d] = t.maturity_date.split('-').map(Number)
        const maturityMs = new Date(y, m - 1, d).getTime()
        const days = Math.round((maturityMs - todayMs) / 86_400_000)
        return {
          id: t.id,
          account_number: t.account_number,
          type: t.type,
          bank_short_name: t.bank.short_name,
          balance: t.balance,
          maturity_date: t.maturity_date,
          maturity_amount: t.maturity_amount,
          days_remaining: days,
        }
      })
      .filter(t => t.days_remaining <= MATURITY_HORIZON_DAYS)
      .sort((a, b) => a.days_remaining - b.days_remaining)
  }, [termAccountsAll])

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Bank Accounts"
        description={accounts.length > 0 ? `Total balance: ${formatCurrency(totalBalance)}` : undefined}
        onRefresh={() => qc.invalidateQueries({ queryKey: ['accounts'] }).then(() => qc.invalidateQueries({ queryKey: ['term-accounts'] }))}
        isRefreshing={isFetching}
      >
        <Button onClick={() => setSheet({ kind: 'account', target: null })}>
          <Plus size={16} className="mr-1" />Add Account
        </Button>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-8">
        {/* ── Regular Accounts ── */}
        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <AccountsTable
            accounts={accounts}
            formatCurrency={formatCurrency}
            onEdit={a => setSheet({ kind: 'account', target: a })}
            onClose={a => setSheet({ kind: 'close-account', target: a })}
            onAdjust={a => setSheet({ kind: 'adjust-account', target: a })}
            onAudit={a => setSheet({ kind: 'audit', target: { id: a.id, type: 'account', label: a.nickname, subtitle: a.bank.name } })}
          />
        )}

        {/* ── Term Accounts ── */}
        <div className="flex flex-col gap-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">Term Accounts</h2>
            <div className="flex items-center gap-2">
              <Button variant="outline" onClick={() => setMaturitiesOpen(true)}>
                <CalendarClock size={16} className="mr-1" />
                Upcoming Maturities ({upcomingMaturities.length})
              </Button>
              <Button onClick={() => setSheet({ kind: 'term-create' })}>
                <Plus size={16} className="mr-1" />Add FD / PPF
              </Button>
            </div>
          </div>
          <TermAccountsTable
            activeTerms={termAccountsAll.filter(t => t.is_active)}
            closedTerms={termAccountsAll.filter(t => !t.is_active)}
            formatCurrency={formatCurrency}
            onEdit={t => setSheet({ kind: 'term-edit', target: t })}
            onClose={t => setSheet({ kind: 'close-term', target: t })}
            onAdjust={t => setSheet({ kind: 'adjust-term', target: t })}
            onDeposit={t => setSheet({ kind: 'ppf-deposit', target: t })}
            onAudit={t => setSheet({ kind: 'audit', target: { id: t.id, type: 'term_account', label: t.account_number ?? `${t.type.toUpperCase()} #${t.id}`, subtitle: t.bank.name } })}
          />
        </div>
      </div>

      {/* ── Sheets ── */}
      <AccountSheet
        open={sheet?.kind === 'account'}
        onClose={close}
        initial={sheet?.kind === 'account' ? sheet.target : null}
        banks={banks}
        currencySymbol={symbol}
      />
      <CloseAccountSheet
        open={sheet?.kind === 'close-account'}
        onClose={close}
        account={sheet?.kind === 'close-account' ? sheet.target : null}
        currencySymbol={symbol}
      />
      <AdjustBalanceSheet
        open={sheet?.kind === 'adjust-account' || sheet?.kind === 'adjust-term'}
        onClose={close}
        account={sheet?.kind === 'adjust-account' ? sheet.target : null}
        termAccount={sheet?.kind === 'adjust-term' ? sheet.target : null}
        currencySymbol={symbol}
      />
      <TermAccountSheet
        open={sheet?.kind === 'term-create'}
        onClose={close}
        parentCandidates={parentCandidates}
        formatCurrency={formatCurrency}
        currencySymbol={symbol}
      />
      <TermAccountEditSheet
        open={sheet?.kind === 'term-edit'}
        onClose={close}
        termAccount={sheet?.kind === 'term-edit' ? sheet.target : null}
        currencySymbol={symbol}
      />
      <CloseTermSheet
        open={sheet?.kind === 'close-term'}
        onClose={close}
        termAccount={sheet?.kind === 'close-term' ? sheet.target : null}
        currencySymbol={symbol}
      />
      <PPFDepositSheet
        open={sheet?.kind === 'ppf-deposit'}
        onClose={close}
        termAccount={sheet?.kind === 'ppf-deposit' ? sheet.target : null}
        currencySymbol={symbol}
      />
      <AuditLogSidebar
        target={sheet?.kind === 'audit' ? sheet.target : null}
        onClose={close}
      />
      <MaturitiesSheet
        open={maturitiesOpen}
        onClose={() => setMaturitiesOpen(false)}
        maturities={upcomingMaturities}
        formatCurrency={formatCurrency}
        showAccountsLink={false}
      />
    </div>
  )
}
