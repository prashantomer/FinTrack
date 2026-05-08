import { cn } from '@/lib/utils'

/**
 * FinTrack brand mark — three ascending bars in a rounded square with an
 * apex dot. Theme-aware: the rounded square uses `currentColor`, bars + dot
 * use the contrasting `bg-background` token. Place inside any text-coloured
 * parent and it picks up the theme automatically.
 */
export function FinTrackMark({
  size = 24,
  className,
}: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      className={cn('shrink-0', className)}
    >
      {/* Rounded-square brand container */}
      <rect width="24" height="24" rx="6" fill="currentColor" />
      {/* Three ascending bars */}
      <rect x="5"  y="14" width="3.2" height="5"  rx="0.8" className="fill-background" />
      <rect x="10.4" y="10" width="3.2" height="9"  rx="0.8" className="fill-background" />
      <rect x="15.8" y="6"  width="3.2" height="13" rx="0.8" className="fill-background" />
      {/* Apex dot — implies "tracking the next move" */}
      <circle cx="17.4" cy="3.6" r="1.4" className="fill-background" />
    </svg>
  )
}

/**
 * Mark + wordmark, used in marketing surfaces (landing nav, login card).
 * The wordmark uses tight tracking and a contrasting weight for the
 * "Track" suffix to nudge the brand identity slightly.
 */
export function FinTrackLogo({
  size = 24,
  className,
}: { size?: number; className?: string }) {
  return (
    <span className={cn('inline-flex items-center gap-2 font-semibold tracking-tight', className)}>
      <FinTrackMark size={size} />
      <span>
        <span>Fin</span>
        <span className="text-muted-foreground">Track</span>
      </span>
    </span>
  )
}
