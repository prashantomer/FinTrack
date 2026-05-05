import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'

interface Props {
  open: boolean
  onClose: () => void
  title: string
  subtitle?: string
  onSubmit: (e: React.FormEvent) => void
  submitLabel: string
  submitVariant?: 'default' | 'destructive'
  children: React.ReactNode
}

export function SidebarShell({ open, onClose, title, subtitle, onSubmit, submitLabel, submitVariant = 'default', children }: Props) {
  return (
    <Sheet open={open} onOpenChange={o => { if (!o) onClose() }}>
      <SheetContent side="right" className="w-[400px] sm:max-w-[420px] flex flex-col p-0 overflow-hidden">
        <SheetHeader className="border-b px-6 py-5 shrink-0">
          <SheetTitle className="text-base">{title}</SheetTitle>
          {subtitle && <p className="text-sm text-muted-foreground">{subtitle}</p>}
        </SheetHeader>
        <form onSubmit={onSubmit} className="flex flex-col flex-1 overflow-hidden">
          <div className="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">{children}</div>
          <div className="border-t px-6 py-4 flex justify-end gap-2 shrink-0">
            <Button type="button" variant="outline" onClick={onClose}>Cancel</Button>
            <Button type="submit" variant={submitVariant}>{submitLabel}</Button>
          </div>
        </form>
      </SheetContent>
    </Sheet>
  )
}
