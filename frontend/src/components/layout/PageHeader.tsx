import { RefreshCw } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface PageHeaderProps {
  title: string
  description?: string
  onRefresh: () => void
  isRefreshing?: boolean
  children?: React.ReactNode
}

export function PageHeader({ title, description, onRefresh, isRefreshing = false, children }: PageHeaderProps) {
  return (
    <div className="shrink-0 min-h-14 border-b bg-background px-6 py-3 flex items-center justify-between">
      <div className="min-w-0">
        <h1 className="text-lg font-semibold leading-none">{title}</h1>
        {description && <p className="text-xs text-muted-foreground mt-1 truncate">{description}</p>}
      </div>
      <div className="flex items-center gap-2 shrink-0">
        <Button
          size="icon"
          variant="ghost"
          onClick={onRefresh}
          disabled={isRefreshing}
          title="Refresh"
        >
          <RefreshCw size={15} className={isRefreshing ? 'animate-spin' : ''} />
        </Button>
        {children}
      </div>
    </div>
  )
}
