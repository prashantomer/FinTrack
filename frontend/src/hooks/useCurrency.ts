import { useMemo } from 'react'
import { useAuth } from '@/context/AuthContext'
import {
  buildCurrencyFormatters,
  DEFAULT_CURRENCY_CODE,
  DEFAULT_CURRENCY_LOCALE,
} from '@/lib/currency'

/**
 * Returns currency formatters derived from the logged-in user's
 * currency_code and currency_locale preferences.
 * Falls back to INR / en-IN when no user is loaded.
 */
export function useCurrency() {
  const { user } = useAuth()
  return useMemo(
    () => buildCurrencyFormatters(
      user?.currency_code   ?? DEFAULT_CURRENCY_CODE,
      user?.currency_locale ?? DEFAULT_CURRENCY_LOCALE,
    ),
    [user?.currency_code, user?.currency_locale],
  )
}
