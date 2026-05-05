// ── Currency configuration ────────────────────────────────────────────────────
// Change these three constants to switch the app's currency app-wide.
export const CURRENCY_CODE   = 'INR'
export const CURRENCY_LOCALE = 'en-IN'
export const CURRENCY_SYMBOL = '₹'

// ── Formatters ────────────────────────────────────────────────────────────────

const _fmt = new Intl.NumberFormat(CURRENCY_LOCALE, {
  style: 'currency',
  currency: CURRENCY_CODE,
  maximumFractionDigits: 0,
})

/** Full currency format — e.g. ₹1,23,456 */
export function formatCurrency(value: number): string {
  return _fmt.format(value)
}

/** Compact format for chart axes — e.g. ₹1.2L or ₹45k */
export function formatCurrencyCompact(value: number): string {
  const abs = Math.abs(value)
  if (abs >= 1_00_000) return `${CURRENCY_SYMBOL}${(value / 1_00_000).toFixed(1)}L`
  if (abs >= 1_000)    return `${CURRENCY_SYMBOL}${(value / 1_000).toFixed(0)}k`
  return formatCurrency(value)
}

/** For form labels — e.g. currencyLabel('Amount') → 'Amount (₹)' */
export function currencyLabel(label: string): string {
  return `${label} (${CURRENCY_SYMBOL})`
}
