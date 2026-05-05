// ── Defaults (used when no user is loaded yet) ────────────────────────────────
export const DEFAULT_CURRENCY_CODE   = 'INR'
export const DEFAULT_CURRENCY_LOCALE = 'en-IN'

// ── Symbol extraction ─────────────────────────────────────────────────────────
// Derives the symbol from the locale/code pair — no hardcoded map needed.
export function extractCurrencySymbol(locale: string, code: string): string {
  const parts = new Intl.NumberFormat(locale, { style: 'currency', currency: code })
    .formatToParts(0)
  return parts.find(p => p.type === 'currency')?.value ?? code
}

// ── Formatter factory ─────────────────────────────────────────────────────────
export interface CurrencyFormatters {
  symbol: string
  formatCurrency: (value: number) => string
  formatCurrencyCompact: (value: number) => string
  /** For form labels — e.g. currencyLabel('Amount') → 'Amount ($)' */
  currencyLabel: (label: string) => string
}

export function buildCurrencyFormatters(code: string, locale: string): CurrencyFormatters {
  const symbol = extractCurrencySymbol(locale, code)
  const fmt = new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: code,
    maximumFractionDigits: 0,
  })

  function formatCurrency(value: number): string {
    return fmt.format(value)
  }

  function formatCurrencyCompact(value: number): string {
    const abs = Math.abs(value)
    if (abs >= 1_00_000) return `${symbol}${(value / 1_00_000).toFixed(1)}L`
    if (abs >= 1_000)    return `${symbol}${(value / 1_000).toFixed(0)}k`
    return formatCurrency(value)
  }

  function currencyLabel(label: string): string {
    return `${label} (${symbol})`
  }

  return { symbol, formatCurrency, formatCurrencyCompact, currencyLabel }
}

// ── Static fallback (server-side / non-component use) ─────────────────────────
export const {
  symbol:                  CURRENCY_SYMBOL,
  formatCurrency,
  formatCurrencyCompact,
  currencyLabel,
} = buildCurrencyFormatters(DEFAULT_CURRENCY_CODE, DEFAULT_CURRENCY_LOCALE)
