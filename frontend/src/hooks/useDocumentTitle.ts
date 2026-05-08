import { useEffect } from 'react'
import { useLocation } from 'react-router-dom'

const APP_NAME = 'FinTrack'

// Path → human-readable label. Match longest-prefix first so nested routes
// inherit the parent's label when not explicitly listed.
const TITLES: ReadonlyArray<readonly [path: string, label: string]> = [
  [ '/dashboard',         'Dashboard' ],
  [ '/holdings',          'Holdings' ],
  [ '/investments',       'Investments' ],
  [ '/transactions',      'Transactions' ],
  [ '/accounts',          'Accounts' ],
  [ '/platform-accounts', 'Platform Accounts' ],
  [ '/instruments',       'Instruments' ],
  [ '/portfolio',         'Portfolio' ],
  [ '/reports',           'Reports' ],
  [ '/imports',           'Imports' ],
  [ '/assistant',         'Assistant' ],
  [ '/login',             'Sign in' ],
] as const

function labelFor(pathname: string): string | null {
  // Longest-prefix match so /holdings/123 still picks "Holdings".
  const match = TITLES
    .filter(([ p ]) => pathname === p || pathname.startsWith(`${p}/`))
    .sort((a, b) => b[0].length - a[0].length)[0]
  return match ? match[1] : null
}

/**
 * Watches the current route and updates `document.title` so every history
 * entry pushed by React Router carries a meaningful label. Browser history
 * dropdowns (Cmd+Y, back-button long-press) and the tab title both read this
 * value, so the user can scan recent pages by name.
 *
 * Mount once at the App root.
 */
export function useRouteDocumentTitle(): void {
  const { pathname } = useLocation()
  useEffect(() => {
    const label = labelFor(pathname)
    document.title = label ? `${label} · ${APP_NAME}` : APP_NAME
  }, [pathname])
}

/**
 * For pages that want to override the route-derived title (e.g. include a
 * detail name like "HDFCBANK · Holdings · FinTrack").
 */
export function useDocumentTitle(pageTitle: string): void {
  useEffect(() => {
    const previous = document.title
    document.title = pageTitle ? `${pageTitle} · ${APP_NAME}` : APP_NAME
    return () => { document.title = previous }
  }, [pageTitle])
}
