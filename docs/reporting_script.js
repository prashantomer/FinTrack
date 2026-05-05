/**
 * DevTools error watcher — paste into Chrome DevTools console.
 *
 * Intercepts runtime errors, unhandled promise rejections, and console.error
 * calls, then forwards them to the FinTrack backend using the same endpoint
 * the app's ErrorBoundary uses (POST /api/v1/errors).
 *
 * Schema: { message, stack, component_stack, url }
 */
(function () {
  const REPORT_ENDPOINT = '/api/v1/errors';

  const report = (type, message, stack) => {
    const payload = JSON.stringify({
      message: `[${type}] ${message}`,
      stack: stack || null,
      component_stack: null,
      url: window.location.href,
    });

    fetch(REPORT_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: payload,
      keepalive: true,
    }).catch(() => {});
  };

  // 1. Global runtime errors
  window.addEventListener('error', (e) => {
    report(
      'Runtime Error',
      `${e.message} (${e.filename}:${e.lineno}:${e.colno})`,
      e.error?.stack
    );
  });

  // 2. Unhandled promise rejections
  window.addEventListener('unhandledrejection', (e) => {
    report(
      'Unhandled Rejection',
      e.reason?.message || String(e.reason),
      e.reason?.stack
    );
  });

  // 3. console.error intercept
  const _origError = console.error;
  console.error = (...args) => {
    _origError.apply(console, args);
    report(
      'Console Error',
      args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' '),
      null
    );
  };

  console.log('Error watcher active →', new URL(REPORT_ENDPOINT, window.location.origin).href);
})();
