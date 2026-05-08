export interface ApiMeta {
  total?: number
  next_cursor?: string | number | null
  has_more?: boolean
  limit?: number
  [key: string]: unknown
}

export interface ApiResponse<T> {
  success: boolean
  code: number
  request_id: string
  data: T
  meta_data: ApiMeta
  error?: string
  errors?: Record<string, string[]>
}

export type TransactionType = 'credit' | 'debit'
export type LinkedAccountType = 'account' | 'term_account'
export type TermAccountType = 'fd' | 'ppf'

export type InvestmentType =
  | 'stock'
  | 'mutual_fund'

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
  currency_code: string
  currency_locale: string
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
  /** Latest market close (NSE bhavcopy) for stocks, AMFI NAV for MFs. */
  last_price: number | null
  last_price_at: string | null
  created_at: string
}

export interface InstrumentPage {
  items: Instrument[]
  next_cursor: number | null
  has_more: boolean
}

export interface InstrumentCreate {
  name: string
  type: InvestmentType
  ticker_symbol?: string
  isin?: string
  exchange?: string
  fund_house?: string
}

// ── User Instruments ─────────────────────────────────────────────────────────

export interface UserInstrument {
  id: number
  user_id: number
  instrument_id: number
  added_at: string
  instrument: Instrument
}

// ── Holdings (STI: Folio for MFs, EquityHolding for stocks) ─────────────────

export type HoldingType = 'Folio' | 'EquityHolding'

export interface Holding {
  id: number
  type: HoldingType
  /** MF folio number — null/empty for EquityHolding rows. */
  folio_number: string | null
  user_id: number
  user_instrument_id: number
  platform_account_id: number
  notes: string | null

  // Cached stats — refreshed on every Investment write by Holdings::RefreshService
  buy_lots: number | null
  sell_lots: number | null
  total_units: number | null
  avg_buy_price: number | null
  total_invested: number | null
  current_value: number | null
  unrealized_gain: number | null
  realized_gain: number | null
  is_closed: boolean
  last_calculated_at: string | null

  created_at: string
  user_instrument: UserInstrument
  platform_account: PlatformAccount
}

export interface HoldingCreate {
  type?: HoldingType
  folio_number?: string
  user_instrument_id: number
  platform_account_id: number
  notes?: string
}

export interface HoldingUpdate {
  folio_number?: string
  notes?: string
}

// Backwards-compat aliases (existing UI used Folio/* types) — both refer to
// the same union now. Folio specifically = MF holdings; the union covers both.
export type Folio = Holding
export type FolioCreate = HoldingCreate
export type FolioUpdate = HoldingUpdate

// ── Transactions ─────────────────────────────────────────────────────────────

/** Provenance — `manual` rows are user-typed and editable on `description`/`tags`;
 * `imported` rows came through the CSV importer and are read-only. */
export type RecordSource = 'manual' | 'imported'

export interface Transaction {
  id: number
  user_id: number
  source: RecordSource
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

export type TradeType = 'buy' | 'sell'

export interface Investment {
  id: number
  user_id: number
  source: RecordSource
  type: InvestmentType
  trade_type: TradeType
  name: string
  amount_invested: number
  current_value: number | null
  purchase_date: string
  notes: string | null
  platform_account_id: number | null
  user_instrument_id: number | null
  instrument_id: number | null
  created_at: string
  quantity: number | null
  units: number | null
  /**
   * Per-share price for stocks, per-unit NAV for mutual funds. Same column
   * regardless of trade_type (buy/sell).
   */
  price: number | null
  /** Broker / platform order ID — one order can fill in multiple trades. */
  order_id: string | null
  /** Broker trade / execution ID — one fill within an order. */
  trade_id: string | null
  folio_number: string | null
  transaction_public_id: string | null
  /** Live market price from instruments.last_price (NSE close / AMFI NAV). */
  instrument_last_price: number | null
  instrument_last_price_at: string | null
  /** Server-computed: qty × last_price, only for buy rows when both are present. */
  live_current_value: number | null
  live_gain: number | null
  live_gain_pct: number | null
}

export interface InvestmentListResponse {
  items: Investment[]
  total: number
  page: number
  page_size: number
}

export interface HoldingListResponse {
  items: Holding[]
  total: number
  page: number
  page_size: number
}

export type FolioListResponse = HoldingListResponse

// ── Imports ───────────────────────────────────────────────────────────────────

export type ImportType   = 'investments' | 'transactions' | 'term_accounts'
export type ImportStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface ImportRowResult {
  row_index: number
  status:    'ok' | 'error' | 'skipped'
  notes:     string | null
}

export interface ImportBatch {
  id:             number
  import_type:    ImportType
  status:         ImportStatus
  file_name:      string
  total_rows:     number
  processed_rows: number
  failed_rows:    number
  duplicate_rows: number
  import_version: number
  progress_pct:   number
  import_records: ImportRowResult[]
  created_at:     string
}

export interface ImportListResponse {
  items:     ImportBatch[]
  total:     number
  page:      number
  page_size: number
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
  account_type?: string
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
  transaction_type?: string
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
  investment_type?: InvestmentType
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

// ── Portfolio ─────────────────────────────────────────────────────────────────

export interface LotPnl {
  /** Signed P&L for this lot. BUY → unrealized on still-held qty; SELL → realized (FIFO). */
  value: number
  /** Percentage gain/loss vs cost basis; null when cost basis is 0. */
  pct: number | null
  /** Human-readable label (e.g. "Realized (FIFO)", "Unrealized (held 5 units)"). */
  label: string
}

export interface LotConsumedFromEntry {
  buy_id: number
  buy_date: string
  qty: number
  price: number
}

export interface LotRead {
  id: number
  trade_type: TradeType
  purchase_date: string
  amount_invested: number
  current_value: number | null
  quantity: number | null
  units: number | null
  price: number | null
  folio_number: string | null
  platform_account_nickname: string | null
  notes: string | null
  /** Per-lot P&L, FIFO-based, computed by `Reports::PortfolioService`. May be null
   * for buy lots that have been fully consumed by FIFO sells. */
  pnl: LotPnl | null
  // ── FIFO buy/sell register fields ───────────────────────────────────────
  /** BUY lots only: original signed quantity at purchase. */
  original_qty: number | null
  /** BUY lots only: qty already consumed by later sells (FIFO). */
  consumed_qty: number | null
  /** BUY lots only: qty still held (= original − consumed). */
  remaining_qty: number | null
  /** SELL lots only: the FIFO match trail showing which buy lots this sell consumed. */
  consumed_from: LotConsumedFromEntry[] | null
}

export interface PortfolioPosition {
  user_instrument_id: number
  instrument_id: number
  instrument_name: string
  instrument_ticker: string | null
  instrument_exchange: string | null
  type: InvestmentType
  platform_accounts: string[]
  total_lots: number
  buy_lots: number
  sell_lots: number
  /** Net residual quantity (= buy qty − sell qty). 0 for fully exited positions. */
  total_units: number | null
  /** Cost basis of CURRENTLY HELD shares (= net_qty × avg_buy_price). */
  total_invested: number
  /** Cash-flow accounting: gross buys − gross sale proceeds. */
  net_cash_deployed: number
  avg_buy_price: number | null
  /** Current price per unit (derived from buy lots' current_value). */
  current_price: number | null
  /** Market value of held shares (= net_qty × current_price). */
  current_value: number
  unrealized_gain: number
  unrealized_gain_pct: number
  realized_gain: number
  /** MF only: latest buy-lot folio_number for this position (null when unset). */
  folio_number: string | null
  /** Held units with purchase age >= 365 days (FIFO-based). 0 when closed. */
  long_term_units: number
  /** Held units with purchase age < 365 days (FIFO-based). 0 when closed. */
  short_term_units: number
  /** True when net quantity is zero (all buy lots fully sold off). */
  is_closed: boolean
  lots: LotRead[]
}

export interface PortfolioPlatformBreakdown {
  platform_name: string
  total_invested: number
  current_value: number
}

export interface PortfolioReport {
  total_invested: number
  current_value: number
  unrealized_gain: number
  unrealized_gain_pct: number
  by_type: InvestmentTypeBreakdown[]
  by_platform: PortfolioPlatformBreakdown[]
  positions: PortfolioPosition[]
}

// ── Instrument Profile ──────────────────────────────────────────────────────

/**
 * Position payload for the per-instrument profile page. Same shape as
 * PortfolioPosition (returned by Reports::PortfolioService.build_position),
 * but a position may be empty when the user holds no lots in this instrument.
 */
export type InstrumentPositionSummary = PortfolioPosition

export interface InstrumentPricePoint {
  date: string
  price: number
  source: string | null
}

// ── Performance / Trends ────────────────────────────────────────────────────

export interface PerformanceTotals {
  current_value: number
  unrealized_gain: number
  realized_30d: number
}

export interface PerformanceNetWorthPoint {
  date: string   // ISO date
  value: number
}

/**
 * One row per snapshot date with platform-account names as keys.
 * `date` is always present; the rest of the keys are platform nicknames
 * (e.g., "Coin by Zerodha") whose values are that day's `current_value`
 * for the platform.
 */
export interface PerformancePerPlatformPoint {
  date: string
  [platformName: string]: string | number
}

export interface PerformanceReport {
  totals: PerformanceTotals
  net_worth_series: PerformanceNetWorthPoint[]
  per_platform_series: PerformancePerPlatformPoint[]
  days: number
}
