const ENDPOINT = '/api/v1/errors'

// Dedup: same message is not re-sent within 5 seconds
const _recentKeys = new Set<string>()
let _active = false

function post(message: string, stack?: string | null, componentStack?: string | null) {
  const key = message.slice(0, 200)
  if (_recentKeys.has(key)) return
  _recentKeys.add(key)
  setTimeout(() => _recentKeys.delete(key), 5_000)

  fetch(ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message,
      stack:           stack          ?? null,
      component_stack: componentStack ?? null,
      url:             window.location.href,
    }),
    keepalive: true,
  }).catch(() => {})
}

/** Call once at app startup. Installs the three global hooks. */
export function setupErrorReporter() {
  if (_active) return
  _active = true

  window.addEventListener('error', (e) => {
    post(
      `[Runtime Error] ${e.message} (${e.filename}:${e.lineno}:${e.colno})`,
      e.error?.stack,
    )
  })

  window.addEventListener('unhandledrejection', (e) => {
    const reason = e.reason
    const msg   = reason instanceof Error ? reason.message : String(reason)
    const stack = reason instanceof Error ? reason.stack   : undefined
    post(`[Unhandled Rejection] ${msg}`, stack)
  })

  const _orig = console.error
  console.error = (...args: unknown[]) => {
    _orig.apply(console, args)
    post(
      `[Console Error] ${args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ')}`,
    )
  }
}

/** Report a single error manually — used by ErrorBoundary for component crashes. */
export function reportError(message: string, stack?: string, componentStack?: string) {
  post(`[Component Crash] ${message}`, stack, componentStack)
}
