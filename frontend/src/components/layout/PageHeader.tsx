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
    <div className="shrink-0 border-b bg-background px-6 py-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{title}</h1>
          {description && <p className="text-sm text-muted-foreground mt-0.5">{description}</p>}
        </div>
        <div className="flex items-center gap-2">
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
    </div>
  )
}
