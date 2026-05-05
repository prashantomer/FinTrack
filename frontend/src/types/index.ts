export type TransactionType = 'credit' | 'debit'
export type LinkedAccountType = 'account' | 'term_account'
export type TermAccountType = 'fd' | 'ppf'

export type InvestmentType =
  | 'stock'
  | 'mutual_fund'
  | 'fixed_deposit'
  | 'gold'
  | 'crypto'
  | 'ppf'
  | 'nps'
  | 'real_estate'

export type AccountType = 'savings' | 'current' | 'salary' | 'nre' | 'nro'

export type PlatformType = 'broker' | 'mf_platform' | 'direct' | 'other'

export interface User {
  id: number
  email: string
  first_name: string
  last_name: string
  full_name: string
  is_active: boolean
  is_superuser: boolean
  created_at: string
}

// ── Banks & Accounts ────────────────────────────────────────────────────────

export interface Bank {
  id: number
  name: string
  short_name: string
  is_system: boolean
  created_at: string
}

export interface Account {
  id: number
  user_id: number
  bank_id: number
  nickname: string
  account_number: string | null
  account_type: AccountType
  balance: number
  open_date: string | null
  closed_date: string | null
  closed_amount: number | null
  created_at: string
  bank: Bank
}

export interface AccountCreate {
  bank_id: number
  nickname: string
  account_number?: string
  account_type?: AccountType
  balance?: number
  open_date?: string
}

export interface AccountUpdate {
  nickname?: string
  account_number?: string
  account_type?: AccountType
  balance?: number
}

export interface AccountClose {
  closed_date: string
  closed_amount: number
}

export interface BalanceAdjust {
  balance: number
}

// ── Term Accounts (FD / PPF) ─────────────────────────────────────────────────

export interface TermAccount {
  id: number
  user_id: number
  parent_account_id: number
  type: TermAccountType
  account_number: string | null
  amount: number
  open_date: string
  tenure_days: number | null
  interest_rate: number
  maturity_date: string
  maturity_amount: number
  balance: number
  closed_date: string | null
  closed_amount: number | null
  is_active: boolean
  created_at: string
  bank: Bank
}

export interface TermAccountCreate {
  parent_account_id: number
  type: TermAccountType
  account_number?: string
  amount: number
  open_date: string
  tenure_days?: number
  interest_rate: number
  maturity_amount?: number
  balance?: number
}

export interface TermAccountUpdate {
  account_number?: string | null
  amount?: number
  open_date?: string
  interest_rate?: number
  maturity_date?: string
  maturity_amount?: number
  balance?: number
}

export interface PPFDeposit {
  amount: number
  date: string
}

export interface TermAccountClose {
  closed_date: string
  closed_amount: number
}

// ── Platforms & Platform Accounts ───────────────────────────────────────────

export interface Platform {
  id: number
  name: string
  short_name: string
  type: PlatformType
  is_system: boolean
  created_at: string
}

export interface PlatformAccount {
  id: number
  user_id: number
  platform_id: number
  nickname: string
  account_id: string | null
  created_at: string
  platform: Platform
}

export interface PlatformAccountCreate {
  platform_id: number
  nickname: string
  account_id?: string
}

export interface PlatformAccountUpdate {
  nickname?: string
  account_id?: string
}

// ── Instruments ─────────────────────────────────────────────────────────────

export interface Instrument {
  id: number
  name: string
  type: InvestmentType
  ticker_symbol: string | null
  isin: string | null
  exchange: string | null
  fund_house: string | null
  created_at: string
}

export interface InstrumentCreate {
  name: string
  type: InvestmentType
  ticker_symbol?: string
  isin?: string
  exchange?: string
  fund_house?: string
}

// ── Follios ──────────────────────────────────────────────────────────────────

export interface Follio {
  id: number
  follio_id: string
  user_id: number
  platform_id: number
  instrument_id: number
  created_at: string
  platform: Platform
  instrument: Instrument
}

export interface FollioCreate {
  follio_id: string
  platform_id: number
  instrument_id: number
}

export interface FollioUpdate {
  follio_id?: string
}

// ── Transactions ─────────────────────────────────────────────────────────────

export interface Transaction {
  id: number
  user_id: number
  amount: number
  type: TransactionType
  linked_account_type: LinkedAccountType | null
  linked_account_id: number | null
  instrument_id: number | null
  description: string | null
  tags: string[] | null
  bank_ref: string | null
  date: string
  public_id: string | null
  is_active: boolean
  created_at: string
}

export interface TransactionListResponse {
  items: Transaction[]
  total: number
  page: number
  page_size: number
  next_cursor: string | null
}

export interface TransactionCreate {
  amount: number
  type: TransactionType
  linked_account_type?: LinkedAccountType | null
  linked_account_id?: number | null
  instrument_id?: number | null
  description?: string
  tags?: string[]
  bank_ref?: string
  date: string
}

// ── Investments ──────────────────────────────────────────────────────────────

export interface Investment {
  id: number
  user_id: number
  type: InvestmentType
  name: string
  amount_invested: number
  current_value: number | null
  purchase_date: string
  notes: string | null
  platform_account_id: number | null
  instrument_id: number | null
  created_at: string
  quantity: number | null
  avg_buy_price: number | null
  folio_number: string | null
  units: number | null
  nav_at_purchase: number | null
  bank_name: string | null
  fd_number: string | null
  interest_rate: number | null
  tenure_months: number | null
  maturity_date: string | null
  maturity_amount: number | null
  compounding: string | null
  gold_form: string | null
  weight_grams: number | null
  purity: string | null
  transaction_public_id: string | null
}

export interface InvestmentListResponse {
  items: Investment[]
  total: number
}

// ── Audit Logs ───────────────────────────────────────────────────────────────

export interface TransactionRef {
  id: number
  public_id: string | null
  amount: number
  type: TransactionType
  date: string
  description: string | null
  bank_ref: string | null
}

export interface AuditLog {
  id: number
  table_name: string
  record_id: number
  column_name: string
  old_value: string | null
  new_value: string | null
  changed_at: string
  transaction: TransactionRef | null
}

// ── Reports ──────────────────────────────────────────────────────────────────

export interface AccountSummary {
  id: number
  nickname: string
  bank_short_name: string
  account_type: string
  balance: number
}

export interface TermAccountSummary {
  id: number
  account_number: string | null
  type: string
  bank_short_name: string
  balance: number
  maturity_date: string
  maturity_amount: number | null
  days_remaining: number
}

export interface RecentTransaction {
  id: number
  date: string
  type: string
  amount: number
  description: string | null
  tags: string[]
}

export interface DashboardReport {
  net_worth: number
  accounts_balance: number
  term_accounts_balance: number
  portfolio_value: number
  total_invested: number
  unrealized_gain: number
  total_inbound: number
  total_outbound: number
  net_balance: number
  this_month_inbound: number
  this_month_outbound: number
  this_month_net: number
  prev_month_inbound: number
  prev_month_outbound: number
  accounts: AccountSummary[]
  upcoming_maturities: TermAccountSummary[]
  investment_holdings: InvestmentTypeBreakdown[]
  recent_transactions: RecentTransaction[]
}

export interface MonthlyTrend {
  month: string
  inbound: number
  outbound: number
  net: number
}

export interface SpendingTrendsReport {
  months: MonthlyTrend[]
}

export interface InvestmentTypeBreakdown {
  type: InvestmentType
  total_invested: number
  current_value: number
  unrealized_gain: number
  count: number
}

export interface DashboardCacheStatus {
  redis_connected: boolean
  cache_warm: boolean
  cache_ttl_seconds: number | null
}

export interface InvestmentSummaryReport {
  holdings: InvestmentTypeBreakdown[]
  total_invested: number
  total_current_value: number
  total_unrealized_gain: number
}
