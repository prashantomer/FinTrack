import { useNavigate } from 'react-router-dom'
import { ExternalLink } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import type { TermAccountSummary } from '@/types'

export function MaturitiesTable({
  maturities,
  formatCurrency,
}: {
  maturities: TermAccountSummary[]
  formatCurrency: (v: number) => string
}) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Account</TableHead>
          <TableHead>Bank</TableHead>
          <TableHead>Type</TableHead>
          <TableHead>Matures</TableHead>
          <TableHead className="text-right">Days</TableHead>
          <TableHead className="text-right">Balance</TableHead>
          <TableHead className="text-right">Payout</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {maturities.map((ta) => (
          <TableRow key={ta.id}>
            <TableCell className="font-mono text-sm">{ta.account_number || '—'}</TableCell>
            <TableCell className="text-sm">{ta.bank_short_name}</TableCell>
            <TableCell>
              <Badge variant={(ta.type ?? ta.account_type) === 'fd' ? 'default' : 'secondary'}>
                {(ta.type ?? ta.account_type ?? '').toUpperCase()}
              </Badge>
            </TableCell>
            <TableCell className="text-sm text-muted-foreground">{ta.maturity_date}</TableCell>
            <TableCell className={`text-right font-mono text-sm font-semibold ${ta.days_remaining <= 14 ? 'text-orange-500' : 'text-muted-foreground'}`}>
              {ta.days_remaining}d
            </TableCell>
            <TableCell className="text-right font-mono text-sm">{formatCurrency(ta.balance)}</TableCell>
            <TableCell className="text-right font-mono text-sm text-green-600">
              {ta.maturity_amount != null ? formatCurrency(ta.maturity_amount) : '—'}
            </TableCell>
          </TableRow>
        ))}
        {maturities.length === 0 && (
          <TableRow>
            <TableCell colSpan={7} className="text-center text-sm text-muted-foreground py-6">
              No maturities in the next 90 days
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  )
}

export function MaturitiesSheet({
  open,
  onClose,
  maturities,
  formatCurrency,
  showAccountsLink = true,
}: {
  open: boolean
  onClose: () => void
  maturities: TermAccountSummary[]
  formatCurrency: (v: number) => string
  showAccountsLink?: boolean
}) {
  const navigate = useNavigate()
  return (
    <Sheet open={open} onOpenChange={o => { if (!o) onClose() }}>
      <SheetContent side="right" className="data-[side=right]:w-1/2 data-[side=right]:sm:max-w-[50vw] flex flex-col p-0 overflow-hidden">
        <SheetHeader className="border-b px-6 py-5 shrink-0 flex-row items-center justify-between gap-3">
          <div className="flex flex-col gap-0.5">
            <SheetTitle className="text-base">Upcoming Maturities</SheetTitle>
            <p className="text-sm text-muted-foreground">Next 90 days · {maturities.length} accounts</p>
          </div>
          {showAccountsLink && (
            <Button variant="outline" size="sm" className="h-8 px-3 gap-1.5" onClick={() => { onClose(); navigate('/accounts') }}>
              Manage in Accounts
              <ExternalLink size={12} />
            </Button>
          )}
        </SheetHeader>
        <div className="flex-1 overflow-y-auto">
          <MaturitiesTable maturities={maturities} formatCurrency={formatCurrency} />
        </div>
      </SheetContent>
    </Sheet>
  )
}
