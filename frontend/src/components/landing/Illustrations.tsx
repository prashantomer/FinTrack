import { cn } from '@/lib/utils'

/**
 * Monochrome SVG illustrations for the public landing page. All use
 * `currentColor` + theme tokens (`fill-card`, `fill-muted`, `text-primary`)
 * so they invert cleanly in dark mode and inherit the parent's text colour.
 *
 * The visual language echoes the FinTrack brand mark: rounded rectangles,
 * ascending bars, single accent dot. Keeps the marketing surface visually
 * consistent with the in-app chrome.
 */

// ── Hero ─────────────────────────────────────────────────────────────────────
// A floating "dashboard window" with a growth line, a couple of stats tiles
// and a small portfolio-allocation ring. Replaces the plain CSS mock.
export function HeroIllustration({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 600 380"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      className={cn('w-full h-auto', className)}
    >
      <defs>
        <linearGradient id="heroLineFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"   stopColor="currentColor" stopOpacity="0.18" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0" />
        </linearGradient>
        <pattern id="heroGrid" width="32" height="32" patternUnits="userSpaceOnUse">
          <path d="M32 0H0V32" fill="none" stroke="currentColor" strokeOpacity="0.06" />
        </pattern>
      </defs>

      {/* Soft grid background */}
      <rect x="0" y="0" width="600" height="380" fill="url(#heroGrid)" />

      {/* Main dashboard card */}
      <g transform="translate(40 40)">
        <rect width="420" height="280" rx="18" className="fill-card" stroke="currentColor" strokeOpacity="0.12" />
        {/* Window controls */}
        <circle cx="22" cy="22" r="4" fill="currentColor" fillOpacity="0.18" />
        <circle cx="36" cy="22" r="4" fill="currentColor" fillOpacity="0.18" />
        <circle cx="50" cy="22" r="4" fill="currentColor" fillOpacity="0.18" />
        <text x="78" y="26" fontSize="11" fill="currentColor" fillOpacity="0.55" fontFamily="system-ui">Dashboard</text>

        {/* Top stats row */}
        <g transform="translate(20 50)">
          {[
            { label: 'Net Worth',   value: '₹ 42.1L',  delta: '+₹ 12.3K',     x: 0   },
            { label: 'Investments', value: '₹ 28.4L',  delta: '8 platforms', x: 130 },
            { label: 'P&L (30d)',   value: '+₹ 1.8L',  delta: '+4.5%',       x: 260 },
          ].map((s) => (
            <g key={s.label} transform={`translate(${s.x} 0)`}>
              <rect width="110" height="56" rx="8" className="fill-muted" fillOpacity="0.6" />
              <text x="10" y="18" fontSize="9"  fill="currentColor" fillOpacity="0.55" fontFamily="system-ui">{s.label}</text>
              <text x="10" y="36" fontSize="14" fill="currentColor" fontFamily="system-ui" fontWeight="600">{s.value}</text>
              <text x="10" y="50" fontSize="9"  fill="currentColor" fillOpacity="0.55" fontFamily="system-ui">{s.delta}</text>
            </g>
          ))}
        </g>

        {/* Trend chart */}
        <g transform="translate(20 130)">
          <rect width="380" height="130" rx="8" className="fill-muted" fillOpacity="0.4" />
          {/* Filled area under line */}
          <path
            d="M 12 100 L 50 92 L 90 84 L 130 88 L 170 70 L 210 62 L 250 54 L 290 60 L 330 40 L 368 28 L 368 118 L 12 118 Z"
            fill="url(#heroLineFill)"
          />
          {/* The line itself */}
          <path
            d="M 12 100 L 50 92 L 90 84 L 130 88 L 170 70 L 210 62 L 250 54 L 290 60 L 330 40 L 368 28"
            fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round"
          />
          {/* Apex marker */}
          <circle cx="368" cy="28" r="4" fill="currentColor" />
          <circle cx="368" cy="28" r="9" fill="currentColor" fillOpacity="0.18" />
        </g>
      </g>

      {/* Floating allocation ring (right-aligned card overhang) */}
      <g transform="translate(440 130)">
        <rect width="140" height="140" rx="18" className="fill-card" stroke="currentColor" strokeOpacity="0.12" />
        <text x="14" y="26" fontSize="10" fill="currentColor" fillOpacity="0.55" fontFamily="system-ui">Allocation</text>
        {/* Ring chart: 3 segments */}
        <g transform="translate(70 82)">
          <circle r="36" fill="none" stroke="currentColor" strokeOpacity="0.15" strokeWidth="10" />
          {/* 60% segment (stocks) — strokeDasharray over circumference (~226) */}
          <circle r="36" fill="none" stroke="currentColor" strokeWidth="10" strokeDasharray="135 226" transform="rotate(-90)" strokeLinecap="butt" />
          {/* 30% segment (MFs) — offset */}
          <circle r="36" fill="none" stroke="currentColor" strokeOpacity="0.55" strokeWidth="10" strokeDasharray="68 226" strokeDashoffset="-135" transform="rotate(-90)" strokeLinecap="butt" />
          {/* Centre value */}
          <text x="0" y="-2" fontSize="14" fontWeight="600" fill="currentColor" textAnchor="middle" fontFamily="system-ui">₹28L</text>
          <text x="0" y="11" fontSize="8"  fill="currentColor" fillOpacity="0.55" textAnchor="middle" fontFamily="system-ui">invested</text>
        </g>
      </g>

      {/* Floating "+₹12,300 today" badge */}
      <g transform="translate(78 326)">
        <rect width="170" height="34" rx="17" className="fill-card" stroke="currentColor" strokeOpacity="0.12" />
        <circle cx="18" cy="17" r="6" fill="currentColor" fillOpacity="0.12" />
        <path d="M 14 17 L 18 13 L 22 17" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        <text x="32" y="21" fontSize="11" fontFamily="system-ui" fontWeight="500" fill="currentColor">+₹ 12,300 today</text>
      </g>
    </svg>
  )
}

// ── AI Assistant ─────────────────────────────────────────────────────────────
// A chat thread where the assistant's reply contains a small bar chart,
// implying "ask in plain English, get a real data answer back".
export function AssistantIllustration({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 480 360"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      className={cn('w-full h-auto', className)}
    >
      {/* User bubble (right) */}
      <g transform="translate(140 40)">
        <rect width="290" height="56" rx="18" fill="currentColor" />
        <text x="22" y="34" fontSize="13" fill="white" fontFamily="system-ui">How did my portfolio do this month?</text>
      </g>

      {/* Tool-call chip */}
      <g transform="translate(40 116)">
        <rect width="190" height="28" rx="6" className="fill-muted" stroke="currentColor" strokeOpacity="0.18" />
        <circle cx="14" cy="14" r="3" fill="currentColor" fillOpacity="0.6">
          <animate attributeName="fill-opacity" values="0.6;0.15;0.6" dur="1.6s" repeatCount="indefinite" />
        </circle>
        <text x="26" y="18" fontSize="10" fill="currentColor" fillOpacity="0.7" fontFamily="ui-monospace,monospace">
          query_performance(days: 30)
        </text>
      </g>

      {/* Assistant reply bubble (left, with chart inside) */}
      <g transform="translate(40 162)">
        <rect width="380" height="170" rx="18" className="fill-card" stroke="currentColor" strokeOpacity="0.18" />
        <text x="22" y="32" fontSize="12" fill="currentColor" fontFamily="system-ui">
          <tspan>Up</tspan>
          <tspan fontWeight="600"> +₹ 1.84L</tspan>
          <tspan> over 30 days </tspan>
          <tspan fontWeight="600">(+4.5%)</tspan>
          <tspan>.</tspan>
        </text>
        <text x="22" y="50" fontSize="11" fill="currentColor" fillOpacity="0.6" fontFamily="system-ui">
          Most growth from Coin holdings, slight drag from Kite.
        </text>

        {/* Inline mini-chart */}
        <g transform="translate(22 70)">
          {[
            { x: 0,   h: 30 },
            { x: 28,  h: 38 },
            { x: 56,  h: 32 },
            { x: 84,  h: 50 },
            { x: 112, h: 44 },
            { x: 140, h: 58 },
            { x: 168, h: 52 },
            { x: 196, h: 70 },
            { x: 224, h: 64 },
            { x: 252, h: 80 },
            { x: 280, h: 76 },
            { x: 308, h: 88 },
          ].map((b) => (
            <rect key={b.x} x={b.x} y={88 - b.h} width="20" height={b.h} rx="3" fill="currentColor" fillOpacity={0.4 + (b.h / 200)} />
          ))}
        </g>
      </g>
    </svg>
  )
}

// ── Imports ──────────────────────────────────────────────────────────────────
// A CSV file glyph flowing into structured rows via a curved connector.
export function ImportsIllustration({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 480 320"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      className={cn('w-full h-auto', className)}
    >
      {/* Source: CSV file glyph */}
      <g transform="translate(30 80)">
        <rect width="140" height="160" rx="10" className="fill-card" stroke="currentColor" strokeOpacity="0.2" />
        <path d="M 140 0 L 100 0 L 100 28 L 140 28" fill="none" stroke="currentColor" strokeOpacity="0.2" />
        <text x="22" y="60" fontSize="11" fill="currentColor" fillOpacity="0.5" fontFamily="ui-monospace,monospace">date,side</text>
        <text x="22" y="78" fontSize="11" fill="currentColor" fillOpacity="0.5" fontFamily="ui-monospace,monospace">qty,price</text>
        {/* Skeleton rows */}
        {[ 96, 110, 124, 138 ].map((y) => (
          <g key={y}>
            <rect x="22" y={y} width="56" height="6" rx="2" fill="currentColor" fillOpacity="0.18" />
            <rect x="84" y={y} width="34" height="6" rx="2" fill="currentColor" fillOpacity="0.12" />
          </g>
        ))}
        <text x="70" y="180" fontSize="10" fill="currentColor" fillOpacity="0.6" textAnchor="middle" fontFamily="ui-monospace,monospace">trades.csv</text>
      </g>

      {/* Curved arrow */}
      <g transform="translate(180 100)">
        <path
          d="M 0 60 C 40 60, 60 20, 120 20"
          fill="none" stroke="currentColor" strokeOpacity="0.5" strokeWidth="2" strokeDasharray="4 4"
        />
        <path d="M 116 14 L 124 20 L 116 26" fill="none" stroke="currentColor" strokeOpacity="0.6" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </g>

      {/* Destination: structured row preview */}
      <g transform="translate(310 50)">
        <rect width="160" height="220" rx="10" className="fill-card" stroke="currentColor" strokeOpacity="0.2" />
        <text x="14" y="22" fontSize="10" fill="currentColor" fillOpacity="0.55" fontFamily="system-ui">Imported · 411 rows</text>
        {/* Each pill represents a parsed investment row */}
        {[ 36, 64, 92, 120, 148, 176 ].map((y, i) => (
          <g key={y}>
            <rect x="14" y={y} width="132" height="22" rx="6" className="fill-muted" />
            <circle cx="26" cy={y + 11} r="4" fill="currentColor" fillOpacity={i === 4 ? 0.15 : 0.45} />
            <rect x="38" y={y + 7}  width="48" height="4" rx="2" fill="currentColor" fillOpacity="0.45" />
            <rect x="38" y={y + 14} width="32" height="4" rx="2" fill="currentColor" fillOpacity="0.18" />
            {/* status tick on most rows; warning on one to hint at duplicate detection */}
            {i === 4 ? (
              <text x="132" y={y + 15} fontSize="9" fill="currentColor" fillOpacity="0.45" fontFamily="system-ui">dup</text>
            ) : (
              <path d={`M 124 ${y + 11} l 4 4 l 8 -8`} fill="none" stroke="currentColor" strokeOpacity="0.55" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            )}
          </g>
        ))}
      </g>
    </svg>
  )
}
