import { useState } from 'react'
import { ArrowDownToLine, History, Pencil, Plus, SlidersHorizontal, XCircle } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { AuditLogSidebar } from '@/components/accounts/AuditLogSidebar'
import { useAccounts, useAdjustAccountBalance, useBanks, useCloseAccount, useCreateAccount, useUpdateAccount } from '@/hooks/useBanks'
import { useAdjustTermAccountBalance, useCloseTermAccount, useCreateTermAccount, useDepositPPF, useTermAccounts, useUpdateTermAccount } from '@/hooks/useTermAccounts'
import type { AuditTarget } from '@/hooks/useAuditLogs'
import { ACCOUNT_TYPE_LABELS, TERM_ACCOUNT_TYPE_LABELS } from '@/lib/labels'
import { formatCurrency, CURRENCY_SYMBOL } from '@/lib/currency'
import type { Account, AccountType, TermAccount, TermAccountType, TermAccountUpdate } from '@/types'

const fmt = { format: formatCurrency }


// ── Account form ─────────────────────────────────────────────────────────────

interface AccountFormState {
  bank_id: string
  nickname: string
  account_number: string
  account_type: AccountType
  balance: string
  open_date: string
}

const TODAY = new Date().toISOString().split('T')[0]

const DEFAULT_ACCOUNT_FORM: AccountFormState = {
  bank_id: '',
  nickname: '',
  account_number: '',
  account_type: 'savings',
  balance: '',
  open_date: TODAY,
}

// ── Term account form ────────────────────────────────────────────────────────

interface TermAccountFormState {
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

const DEFAULT_TERM_FORM: TermAccountFormState = {
  parent_account_id: '',
  type: 'fd',
  account_number: '',
  amount: '',
  open_date: TODAY,
  tenure_days: '',
  interest_rate: '',
  maturity_amount: '',
  balance: '',
}

// ── Close form ───────────────────────────────────────────────────────────────

interface CloseFormState {
  closed_date: string
  closed_amount: string
}

const DEFAULT_CLOSE_FORM: CloseFormState = {
  closed_date: TODAY,
  closed_amount: '',
}

// ── Term account edit form ───────────────────────────────────────────────────

interface TermEditFormState {
  account_number: string
  amount: string
  open_date: string
  interest_rate: string
  maturity_date: string
  maturity_amount: string
  balance: string
}

// ── Shared sidebar shell ─────────────────────────────────────────────────────

function SidebarShell({
  open,
  onClose,
  title,
  subtitle,
  onSubmit,
  submitLabel,
  submitVariant = 'default',
  children,
}: {
  open: boolean
  onClose: () => void
  title: string
  subtitle?: string
  onSubmit: (e: React.FormEvent) => void
  submitLabel: string
  submitVariant?: 'default' | 'destructive'
  children: React.ReactNode
}) {
  return (
    <Sheet open={open} onOpenChange={(o) => { if (!o) onClose() }}>
      <SheetContent side="right" className="w-[400px] sm:max-w-[420px] flex flex-col p-0 overflow-hidden">
        <SheetHeader className="border-b px-6 py-5 shrink-0">
          <SheetTitle className="text-base">{title}</SheetTitle>
          {subtitle && <p className="text-sm text-muted-foreground">{subtitle}</p>}
        </SheetHeader>
        <form onSubmit={onSubmit} className="flex flex-col flex-1 overflow-hidden">
          <div className="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">
            {children}
          </div>
          <div className="border-t px-6 py-4 flex justify-end gap-2 shrink-0">
            <Button type="button" variant="outline" onClick={onClose}>Cancel</Button>
            <Button type="submit" variant={submitVariant}>{submitLabel}</Button>
          </div>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ── Component ────────────────────────────────────────────────────────────────

export function AccountsPage() {
  const { data: accounts = [], isLoading } = useAccounts()
  const { data: banks = [] } = useBanks()
  const { data: termAccountsAll = [] } = useTermAccounts()
  const termAccounts = termAccountsAll.filter(ta => ta.is_active)
  const closedTermAccounts = termAccountsAll.filter(ta => !ta.is_active)

  const createAccountMutation = useCreateAccount()
  const updateAccountMutation = useUpdateAccount()
  const closeAccountMutation = useCloseAccount()
  const adjustAccountMutation = useAdjustAccountBalance()
  const createTermMutation = useCreateTermAccount()
  const updateTermMutation = useUpdateTermAccount()
  const depositPPFMutation = useDepositPPF()
  const closeTermMutation = useCloseTermAccount()
  const adjustTermMutation = useAdjustTermAccountBalance()

  // Account sidebar state
  const [accountOpen, setAccountOpen] = useState(false)
  const [editingAccount, setEditingAccount] = useState<Account | null>(null)
  const [accountForm, setAccountForm] = useState<AccountFormState>(DEFAULT_ACCOUNT_FORM)

  // Term account sidebar state
  const [termOpen, setTermOpen] = useState(false)
  const [termForm, setTermForm] = useState<TermAccountFormState>(DEFAULT_TERM_FORM)

  // Close sidebars
  const [closeAccountId, setCloseAccountId] = useState<number | null>(null)
  const [closeTermId, setCloseTermId] = useState<number | null>(null)
  const [closeForm, setCloseForm] = useState<CloseFormState>(DEFAULT_CLOSE_FORM)

  // Audit log sidebar
  const [auditTarget, setAuditTarget] = useState<AuditTarget>(null)

  // PPF deposit sidebar
  const [depositTarget, setDepositTarget] = useState<TermAccount | null>(null)
  const [depositForm, setDepositForm] = useState({ amount: '', date: TODAY })

  // Term account edit sidebar
  const [editingTermAccount, setEditingTermAccount] = useState<TermAccount | null>(null)
  const [termEditForm, setTermEditForm] = useState<TermEditFormState>({ account_number: '', amount: '', open_date: '', interest_rate: '', maturity_date: '', maturity_amount: '', balance: '' })

  // Adjust balance sidebars
  const [adjustAccount, setAdjustAccount] = useState<Account | null>(null)
  const [adjustTermAccount, setAdjustTermAccount] = useState<TermAccount | null>(null)
  const [adjustBalance, setAdjustBalance] = useState('')

  const totalBalance = accounts.reduce((sum, a) => sum + (a.balance ?? 0), 0)

  // ── Account handlers ────────────────────────────────────────────────────────

  function openCreateAccount() {
    setEditingAccount(null)
    setAccountForm(DEFAULT_ACCOUNT_FORM)
    setAccountOpen(true)
  }

  function openEditAccount(a: Account) {
    setEditingAccount(a)
    setAccountForm({
      bank_id: a.bank_id.toString(),
      nickname: a.nickname,
      account_number: a.account_number ?? '',
      account_type: a.account_type,
      balance: String(a.balance),
      open_date: a.open_date ?? '',
    })
    setAccountOpen(true)
  }

  async function handleAccountSubmit(e: React.FormEvent) {
    e.preventDefault()
    const balanceVal = accountForm.balance !== '' ? parseFloat(accountForm.balance) : undefined
    const payload = {
      bank_id: Number(accountForm.bank_id),
      nickname: accountForm.nickname,
      account_number: accountForm.account_number || undefined,
      account_type: accountForm.account_type,
      balance: balanceVal,
      open_date: accountForm.open_date || undefined,
    }
    if (editingAccount) {
      await updateAccountMutation.mutateAsync({ id: editingAccount.id, data: payload })
    } else {
      await createAccountMutation.mutateAsync(payload)
    }
    setAccountOpen(false)
  }

  async function handleCloseAccount(e: React.FormEvent) {
    e.preventDefault()
    if (!closeAccountId) return
    await closeAccountMutation.mutateAsync({
      id: closeAccountId,
      data: {
        closed_date: closeForm.closed_date,
        closed_amount: parseFloat(closeForm.closed_amount),
      },
    })
    setCloseAccountId(null)
  }

  // ── Term account handlers ───────────────────────────────────────────────────

  function openEditTerm(ta: TermAccount) {
    setEditingTermAccount(ta)
    setTermEditForm({
      account_number: ta.account_number ?? '',
      amount: String(ta.amount),
      open_date: ta.open_date,
      interest_rate: String(ta.interest_rate),
      maturity_date: ta.maturity_date,
      maturity_amount: ta.maturity_amount ? String(ta.maturity_amount) : '',
      balance: String(ta.balance),
    })
  }

  async function handleTermEditSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!editingTermAccount) return
    const payload: TermAccountUpdate = {}
    if (termEditForm.account_number !== (editingTermAccount.account_number ?? '')) {
      payload.account_number = termEditForm.account_number || null
    }
    if (termEditForm.amount) payload.amount = parseFloat(termEditForm.amount)
    if (termEditForm.open_date) payload.open_date = termEditForm.open_date
    if (termEditForm.interest_rate) payload.interest_rate = parseFloat(termEditForm.interest_rate)
    if (termEditForm.maturity_date) payload.maturity_date = termEditForm.maturity_date
    if (termEditForm.maturity_amount) payload.maturity_amount = parseFloat(termEditForm.maturity_amount)
    if (termEditForm.balance !== '') payload.balance = parseFloat(termEditForm.balance)
    await updateTermMutation.mutateAsync({ id: editingTermAccount.id, data: payload })
    setEditingTermAccount(null)
  }

  function openCreateTerm() {
    setTermForm(DEFAULT_TERM_FORM)
    setTermOpen(true)
  }

  async function handleTermSubmit(e: React.FormEvent) {
    e.preventDefault()
    const isFd = termForm.type === 'fd'
    await createTermMutation.mutateAsync({
      parent_account_id: Number(termForm.parent_account_id),
      type: termForm.type,
      account_number: termForm.account_number || undefined,
      amount: parseFloat(termForm.amount),
      open_date: termForm.open_date,
      tenure_days: isFd ? parseInt(termForm.tenure_days) : undefined,
      interest_rate: parseFloat(termForm.interest_rate),
      maturity_amount: termForm.maturity_amount ? parseFloat(termForm.maturity_amount) : undefined,
      balance: termForm.balance !== '' ? parseFloat(termForm.balance) : undefined,
    })
    setTermOpen(false)
  }

  async function handleCloseTerm(e: React.FormEvent) {
    e.preventDefault()
    if (!closeTermId) return
    await closeTermMutation.mutateAsync({
      id: closeTermId,
      data: {
        closed_date: closeForm.closed_date,
        closed_amount: parseFloat(closeForm.closed_amount),
      },
    })
    setCloseTermId(null)
  }

  async function handleAdjustAccount(e: React.FormEvent) {
    e.preventDefault()
    if (!adjustAccount) return
    await adjustAccountMutation.mutateAsync({ id: adjustAccount.id, data: { balance: parseFloat(adjustBalance) } })
    setAdjustAccount(null)
  }

  async function handleAdjustTerm(e: React.FormEvent) {
    e.preventDefault()
    if (!adjustTermAccount) return
    await adjustTermMutation.mutateAsync({ id: adjustTermAccount.id, data: { balance: parseFloat(adjustBalance) } })
    setAdjustTermAccount(null)
  }

  async function handlePPFDeposit(e: React.FormEvent) {
    e.preventDefault()
    if (!depositTarget) return
    await depositPPFMutation.mutateAsync({ id: depositTarget.id, data: { amount: parseFloat(depositForm.amount), date: depositForm.date } })
    setDepositTarget(null)
  }

  // Parent accounts selectable for term account creation (savings/current at selected bank)
  const parentCandidates = accounts.filter(
    a => !a.closed_date && (a.account_type === 'savings' || a.account_type === 'current')
  )

  return (
    <div className="flex flex-col gap-8">
      {/* ── Regular Accounts ── */}
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold">Bank Accounts</h1>
            {accounts.length > 0 && (
              <p className="text-sm text-muted-foreground mt-0.5">
                Total balance:{' '}
                <span className={`font-medium ${totalBalance >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                  {fmt.format(totalBalance)}
                </span>
              </p>
            )}
          </div>
          <Button onClick={openCreateAccount}><Plus size={16} className="mr-1" />Add Account</Button>
        </div>

        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="rounded-lg border overflow-hidden">
            <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nickname</TableHead>
                <TableHead>Bank</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Account No.</TableHead>
                <TableHead>Opened</TableHead>
                <TableHead className="text-right">Balance</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {accounts.map(a => (
                <TableRow key={a.id} className={a.closed_date ? 'opacity-50' : ''}>
                  <TableCell className="font-medium">{a.nickname}</TableCell>
                  <TableCell>
                    {a.bank.name}{' '}
                    <span className="text-muted-foreground text-xs">({a.bank.short_name})</span>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">{ACCOUNT_TYPE_LABELS[a.account_type]}</Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground font-mono text-sm">
                    {a.account_number || '—'}
                  </TableCell>
                  <TableCell className="text-muted-foreground text-sm">
                    {a.open_date || '—'}
                  </TableCell>
                  <TableCell className={`text-right font-mono font-medium ${(a.balance ?? 0) >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                    {fmt.format(a.balance ?? 0)}
                  </TableCell>
                  <TableCell className="flex gap-1 justify-end">
                    <Button size="icon" variant="ghost" title="Balance history" onClick={() => setAuditTarget({ id: a.id, type: 'account', label: a.nickname, subtitle: a.bank.name })}>
                      <History size={14} />
                    </Button>
                    {!a.closed_date && (
                      <>
                        <Button size="icon" variant="ghost" title="Adjust balance" onClick={() => { setAdjustAccount(a); setAdjustBalance(String(a.balance)) }}>
                          <SlidersHorizontal size={14} />
                        </Button>
                        <Button size="icon" variant="ghost" onClick={() => openEditAccount(a)}>
                          <Pencil size={14} />
                        </Button>
                        <Button
                          size="icon"
                          variant="ghost"
                          title="Close account"
                          onClick={() => { setCloseAccountId(a.id); setCloseForm(DEFAULT_CLOSE_FORM) }}
                        >
                          <XCircle size={14} />
                        </Button>
                      </>
                    )}
                  </TableCell>
                </TableRow>
              ))}
              {accounts.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-muted-foreground py-8">No accounts yet</TableCell>
                </TableRow>
              )}
            </TableBody>
            </Table>
          </div>
        )}
      </div>

      {/* ── Term Accounts (FD / PPF) — Active ── */}
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold">Term Accounts</h2>
          <Button onClick={openCreateTerm}><Plus size={16} className="mr-1" />Add FD / PPF</Button>
        </div>

        <div className="rounded-lg border overflow-hidden">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Type</TableHead>
                <TableHead>Bank</TableHead>
                <TableHead>Account No.</TableHead>
                <TableHead className="text-right">Amount</TableHead>
                <TableHead className="text-right">Rate</TableHead>
                <TableHead>Open Date</TableHead>
                <TableHead>Maturity Date</TableHead>
                <TableHead className="text-right">Maturity Amt</TableHead>
                <TableHead className="text-right">Balance</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {termAccounts.map(ta => (
                <TableRow key={ta.id}>
                  <TableCell>
                    <Badge variant={ta.type === 'fd' ? 'default' : 'secondary'}>
                      {TERM_ACCOUNT_TYPE_LABELS[ta.type]}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    {ta.bank.name}{' '}
                    <span className="text-muted-foreground text-xs">({ta.bank.short_name})</span>
                  </TableCell>
                  <TableCell className="text-muted-foreground font-mono text-sm">
                    {ta.account_number || '—'}
                  </TableCell>
                  <TableCell className="text-right font-mono">{fmt.format(ta.amount)}</TableCell>
                  <TableCell className="text-right font-mono">{ta.interest_rate}%</TableCell>
                  <TableCell className="text-muted-foreground text-sm">{ta.open_date}</TableCell>
                  <TableCell className="text-muted-foreground text-sm">{ta.maturity_date}</TableCell>
                  <TableCell className="text-right font-mono text-green-600">{ta.maturity_amount ? fmt.format(ta.maturity_amount) : '—'}</TableCell>
                  <TableCell className="text-right font-mono">{fmt.format(ta.balance)}</TableCell>
                  <TableCell className="flex gap-1 justify-end">
                    <Button
                      size="icon"
                      variant="ghost"
                      title="Balance history"
                      onClick={() => setAuditTarget({ id: ta.id, type: 'term_account', label: ta.account_number ?? `${TERM_ACCOUNT_TYPE_LABELS[ta.type]} #${ta.id}`, subtitle: ta.bank.name })}
                    >
                      <History size={14} />
                    </Button>
                    {ta.type === 'ppf' && (
                      <Button size="icon" variant="ghost" title="Deposit" onClick={() => { setDepositTarget(ta); setDepositForm({ amount: '', date: TODAY }) }}>
                        <ArrowDownToLine size={14} />
                      </Button>
                    )}
                    <Button size="icon" variant="ghost" title="Edit" onClick={() => openEditTerm(ta)}>
                      <Pencil size={14} />
                    </Button>
                    <Button size="icon" variant="ghost" title="Adjust balance" onClick={() => { setAdjustTermAccount(ta); setAdjustBalance(String(ta.balance)) }}>
                      <SlidersHorizontal size={14} />
                    </Button>
                    <Button
                      size="icon"
                      variant="ghost"
                      title="Close / mature"
                      onClick={() => { setCloseTermId(ta.id); setCloseForm(DEFAULT_CLOSE_FORM) }}
                    >
                      <XCircle size={14} />
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
              {termAccounts.length === 0 && (
                <TableRow>
                  <TableCell colSpan={10} className="text-center text-muted-foreground py-8">
                    No active FD / PPF accounts
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </div>

      {/* ── Term Accounts — Closed ── */}
      {closedTermAccounts.length > 0 && (
        <div className="flex flex-col gap-4">
          <h2 className="text-base font-medium text-muted-foreground">Closed Term Accounts</h2>
          <div className="rounded-lg border overflow-hidden opacity-60">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Type</TableHead>
                  <TableHead>Bank</TableHead>
                  <TableHead>Account No.</TableHead>
                  <TableHead className="text-right">Amount</TableHead>
                  <TableHead className="text-right">Rate</TableHead>
                  <TableHead>Open Date</TableHead>
                  <TableHead>Closed Date</TableHead>
                  <TableHead className="text-right">Closing Balance</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {closedTermAccounts.map(ta => (
                  <TableRow key={ta.id}>
                    <TableCell>
                      <Badge variant="outline">
                        {TERM_ACCOUNT_TYPE_LABELS[ta.type]}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {ta.bank.name}{' '}
                      <span className="text-muted-foreground text-xs">({ta.bank.short_name})</span>
                    </TableCell>
                    <TableCell className="text-muted-foreground font-mono text-sm">
                      {ta.account_number || '—'}
                    </TableCell>
                    <TableCell className="text-right font-mono">{fmt.format(ta.amount)}</TableCell>
                    <TableCell className="text-right font-mono">{ta.interest_rate}%</TableCell>
                    <TableCell className="text-muted-foreground text-sm">{ta.open_date}</TableCell>
                    <TableCell className="text-muted-foreground text-sm">{ta.closed_date ?? '—'}</TableCell>
                    <TableCell className="text-right font-mono">
                      {ta.closed_amount != null ? fmt.format(ta.closed_amount) : '—'}
                    </TableCell>
                    <TableCell className="flex gap-1 justify-end">
                      <Button
                        size="icon"
                        variant="ghost"
                        title="Balance history"
                        onClick={() => setAuditTarget({ id: ta.id, type: 'term_account', label: ta.account_number ?? `${TERM_ACCOUNT_TYPE_LABELS[ta.type]} #${ta.id}`, subtitle: ta.bank.name })}
                      >
                        <History size={14} />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </div>
      )}

      {/* ── Sidebars ── */}

      {/* Create / edit account */}
      <SidebarShell
        open={accountOpen}
        onClose={() => setAccountOpen(false)}
        title={editingAccount ? 'Edit Account' : 'New Bank Account'}
        subtitle={editingAccount ? `${editingAccount.nickname} · ${editingAccount.bank?.name}` : undefined}
        onSubmit={handleAccountSubmit}
        submitLabel={editingAccount ? 'Update' : 'Create'}
      >
        <div className="flex flex-col gap-1.5">
          <Label>Bank</Label>
          <Select
            value={accountForm.bank_id}
            onValueChange={(v) => v && setAccountForm(f => ({ ...f, bank_id: v }))}
          >
            <SelectTrigger><SelectValue placeholder="Select bank…" /></SelectTrigger>
            <SelectContent>
              {banks.map(b => <SelectItem key={b.id} value={b.id.toString()}>{b.name}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Nickname</Label>
          <Input
            value={accountForm.nickname}
            onChange={e => setAccountForm(f => ({ ...f, nickname: e.target.value }))}
            required
          />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Account Type</Label>
            <Select
              value={accountForm.account_type}
              onValueChange={(v) => v && setAccountForm(f => ({ ...f, account_type: v as AccountType }))}
            >
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
            <Input
              value={accountForm.account_number}
              onChange={e => setAccountForm(f => ({ ...f, account_number: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <Label>Balance ({CURRENCY_SYMBOL})</Label>
              <span className="text-xs text-muted-foreground">optional</span>
            </div>
            <Input
              type="number"
              step="0.01"
              placeholder="0"
              value={accountForm.balance}
              onChange={e => setAccountForm(f => ({ ...f, balance: e.target.value }))}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <Label>Open Date</Label>
              <span className="text-xs text-muted-foreground">optional</span>
            </div>
            <Input
              type="date"
              value={accountForm.open_date}
              onChange={e => setAccountForm(f => ({ ...f, open_date: e.target.value }))}
            />
          </div>
        </div>
      </SidebarShell>

      {/* Close account */}
      <SidebarShell
        open={closeAccountId !== null}
        onClose={() => setCloseAccountId(null)}
        title="Close Account"
        subtitle={accounts.find(a => a.id === closeAccountId)?.nickname}
        onSubmit={handleCloseAccount}
        submitLabel="Close Account"
        submitVariant="destructive"
      >
        <div className="flex flex-col gap-1.5">
          <Label>Closure Date</Label>
          <Input
            type="date"
            value={closeForm.closed_date}
            onChange={e => setCloseForm(f => ({ ...f, closed_date: e.target.value }))}
            required
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Final Balance at Closure ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={closeForm.closed_amount}
            onChange={e => setCloseForm(f => ({ ...f, closed_amount: e.target.value }))}
            required
          />
        </div>
      </SidebarShell>

      {/* Create term account */}
      <SidebarShell
        open={termOpen}
        onClose={() => setTermOpen(false)}
        title="New FD / PPF Account"
        onSubmit={handleTermSubmit}
        submitLabel="Create"
      >
        <div className="flex flex-col gap-1.5">
          <Label>Type</Label>
          <Select
            value={termForm.type}
            onValueChange={(v) => v && setTermForm(f => ({ ...f, type: v as TermAccountType, tenure_days: '', maturity_amount: '' }))}
          >
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
          <Select
            value={termForm.parent_account_id}
            onValueChange={(v) => v && setTermForm(f => ({ ...f, parent_account_id: v }))}
          >
            <SelectTrigger><SelectValue placeholder="Select account…" /></SelectTrigger>
            <SelectContent>
              {parentCandidates.map(a => (
                <SelectItem key={a.id} value={a.id.toString()}>
                  {a.nickname} · {a.bank.short_name} ({ACCOUNT_TYPE_LABELS[a.account_type]}) — {fmt.format(a.balance)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Opening Balance ({CURRENCY_SYMBOL})</Label>
            <Input
              type="number"
              step="0.01"
              value={termForm.amount}
              onChange={e => setTermForm(f => ({ ...f, amount: e.target.value }))}
              required
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Open Date</Label>
            <Input
              type="date"
              value={termForm.open_date}
              onChange={e => setTermForm(f => ({ ...f, open_date: e.target.value }))}
              required
            />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Interest Rate (%)</Label>
            <Input
              type="number"
              step="0.01"
              value={termForm.interest_rate}
              onChange={e => setTermForm(f => ({ ...f, interest_rate: e.target.value }))}
              required
            />
          </div>
          {termForm.type === 'fd' && (
            <div className="flex flex-col gap-1.5">
              <Label>Tenure (days)</Label>
              <Input
                type="number"
                value={termForm.tenure_days}
                onChange={e => setTermForm(f => ({ ...f, tenure_days: e.target.value }))}
                required
              />
            </div>
          )}
        </div>

        {termForm.type === 'fd' && (
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <Label>Maturity Amount ({CURRENCY_SYMBOL})</Label>
              <span className="text-xs text-muted-foreground">auto-calculated</span>
            </div>
            <Input
              type="number"
              step="0.01"
              value={termForm.maturity_amount}
              onChange={e => setTermForm(f => ({ ...f, maturity_amount: e.target.value }))}
            />
          </div>
        )}

        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <Label>Account No.</Label>
              <span className="text-xs text-muted-foreground">optional</span>
            </div>
            <Input
              value={termForm.account_number}
              onChange={e => setTermForm(f => ({ ...f, account_number: e.target.value }))}
            />
          </div>
          {termForm.type === 'ppf' && (
            <div className="flex flex-col gap-1.5">
              <div className="flex items-center justify-between">
                <Label>Balance ({CURRENCY_SYMBOL})</Label>
                <span className="text-xs text-muted-foreground">optional</span>
              </div>
              <Input
                type="number"
                step="0.01"
                placeholder="0"
                value={termForm.balance}
                onChange={e => setTermForm(f => ({ ...f, balance: e.target.value }))}
              />
            </div>
          )}
        </div>
      </SidebarShell>

      {/* Adjust account balance */}
      <SidebarShell
        open={adjustAccount !== null}
        onClose={() => setAdjustAccount(null)}
        title="Adjust Balance"
        subtitle={adjustAccount?.nickname}
        onSubmit={handleAdjustAccount}
        submitLabel="Save"
      >
        <div className="flex flex-col gap-1.5">
          <Label>New Balance ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={adjustBalance}
            onChange={e => setAdjustBalance(e.target.value)}
            required
          />
        </div>
      </SidebarShell>

      {/* Adjust term account balance */}
      <SidebarShell
        open={adjustTermAccount !== null}
        onClose={() => setAdjustTermAccount(null)}
        title="Adjust Balance"
        subtitle={adjustTermAccount?.account_number ?? `${adjustTermAccount?.type.toUpperCase()} #${adjustTermAccount?.id}`}
        onSubmit={handleAdjustTerm}
        submitLabel="Save"
      >
        <div className="flex flex-col gap-1.5">
          <Label>New Balance ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={adjustBalance}
            onChange={e => setAdjustBalance(e.target.value)}
            required
          />
        </div>
      </SidebarShell>

      {/* PPF deposit */}
      <SidebarShell
        open={depositTarget !== null}
        onClose={() => setDepositTarget(null)}
        title="PPF Deposit"
        subtitle={depositTarget?.account_number ?? `PPF #${depositTarget?.id}`}
        onSubmit={handlePPFDeposit}
        submitLabel="Deposit"
      >
        <div className="flex flex-col gap-1.5">
          <Label>Amount ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={depositForm.amount}
            onChange={e => setDepositForm(f => ({ ...f, amount: e.target.value }))}
            required
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Date</Label>
          <Input
            type="date"
            value={depositForm.date}
            onChange={e => setDepositForm(f => ({ ...f, date: e.target.value }))}
            required
          />
        </div>
      </SidebarShell>

      {/* Edit term account */}
      <SidebarShell
        open={editingTermAccount !== null}
        onClose={() => setEditingTermAccount(null)}
        title="Edit Term Account"
        subtitle={editingTermAccount?.account_number ?? `${editingTermAccount?.type.toUpperCase()} #${editingTermAccount?.id}`}
        onSubmit={handleTermEditSubmit}
        submitLabel="Save"
      >
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between">
            <Label>Account No.</Label>
            <span className="text-xs text-muted-foreground">optional</span>
          </div>
          <Input
            value={termEditForm.account_number}
            onChange={e => setTermEditForm(f => ({ ...f, account_number: e.target.value }))}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Amount ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={termEditForm.amount}
            onChange={e => setTermEditForm(f => ({ ...f, amount: e.target.value }))}
          />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Open Date</Label>
            <Input
              type="date"
              value={termEditForm.open_date}
              onChange={e => setTermEditForm(f => ({ ...f, open_date: e.target.value }))}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Interest Rate (%)</Label>
            <Input
              type="number"
              step="0.01"
              value={termEditForm.interest_rate}
              onChange={e => setTermEditForm(f => ({ ...f, interest_rate: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Maturity Date</Label>
            <Input
              type="date"
              value={termEditForm.maturity_date}
              onChange={e => setTermEditForm(f => ({ ...f, maturity_date: e.target.value }))}
            />
          </div>
          {editingTermAccount?.type === 'fd' && (
            <div className="flex flex-col gap-1.5">
              <Label>Maturity Amt ({CURRENCY_SYMBOL})</Label>
              <Input
                type="number"
                step="0.01"
                value={termEditForm.maturity_amount}
                onChange={e => setTermEditForm(f => ({ ...f, maturity_amount: e.target.value }))}
              />
            </div>
          )}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Current Balance ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={termEditForm.balance}
            onChange={e => setTermEditForm(f => ({ ...f, balance: e.target.value }))}
          />
        </div>
      </SidebarShell>

      {/* Close term account */}
      <SidebarShell
        open={closeTermId !== null}
        onClose={() => setCloseTermId(null)}
        title="Close / Mature Term Account"
        subtitle={termAccountsAll.find(t => t.id === closeTermId)?.account_number ?? undefined}
        onSubmit={handleCloseTerm}
        submitLabel="Confirm"
        submitVariant="destructive"
      >
        <div className="flex flex-col gap-1.5">
          <Label>Maturity / Closure Date</Label>
          <Input
            type="date"
            value={closeForm.closed_date}
            onChange={e => setCloseForm(f => ({ ...f, closed_date: e.target.value }))}
            required
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Proceeds Received ({CURRENCY_SYMBOL})</Label>
          <Input
            type="number"
            step="0.01"
            value={closeForm.closed_amount}
            onChange={e => setCloseForm(f => ({ ...f, closed_amount: e.target.value }))}
            required
          />
        </div>
      </SidebarShell>

      {/* Audit log sidebar */}
      <AuditLogSidebar target={auditTarget} onClose={() => setAuditTarget(null)} />
    </div>
  )
}
