import { ArrowDownToLine, History, Pencil, SlidersHorizontal, XCircle } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { TERM_ACCOUNT_TYPE_LABELS } from '@/lib/labels'
import type { TermAccount } from '@/types'

interface Props {
  activeTerms: TermAccount[]
  closedTerms: TermAccount[]
  formatCurrency: (v: number) => string
  onEdit: (ta: TermAccount) => void
  onClose: (ta: TermAccount) => void
  onAdjust: (ta: TermAccount) => void
  onDeposit: (ta: TermAccount) => void
  onAudit: (ta: TermAccount) => void
}

export function TermAccountsTable({ activeTerms, closedTerms, formatCurrency, onEdit, onClose, onAdjust, onDeposit, onAudit }: Props) {
  const activeColumns = (
    <TableHeader>
      <TableRow>
        <TableHead>Type</TableHead><TableHead>Bank</TableHead><TableHead>Account No.</TableHead>
        <TableHead className="text-right">Amount</TableHead><TableHead className="text-right">Rate</TableHead>
        <TableHead>Open Date</TableHead><TableHead>Maturity Date</TableHead>
        <TableHead className="text-right">Maturity Amt</TableHead><TableHead className="text-right">Balance</TableHead>
        <TableHead />
      </TableRow>
    </TableHeader>
  )

  return (
    <>
      <div className="rounded-lg border overflow-hidden">
        <Table>
          {activeColumns}
          <TableBody>
            {activeTerms.map(ta => (
              <TableRow key={ta.id}>
                <TableCell><Badge variant={ta.type === 'fd' ? 'default' : 'secondary'}>{TERM_ACCOUNT_TYPE_LABELS[ta.type]}</Badge></TableCell>
                <TableCell>{ta.bank.name} <span className="text-muted-foreground text-xs">({ta.bank.short_name})</span></TableCell>
                <TableCell className="text-muted-foreground font-mono text-sm">{ta.account_number || '—'}</TableCell>
                <TableCell className="text-right font-mono">{formatCurrency(ta.amount)}</TableCell>
                <TableCell className="text-right font-mono">{ta.interest_rate}%</TableCell>
                <TableCell className="text-muted-foreground text-sm">{ta.open_date}</TableCell>
                <TableCell className="text-muted-foreground text-sm">{ta.maturity_date}</TableCell>
                <TableCell className="text-right font-mono text-green-600">{ta.maturity_amount ? formatCurrency(ta.maturity_amount) : '—'}</TableCell>
                <TableCell className="text-right font-mono">{formatCurrency(ta.balance)}</TableCell>
                <TableCell className="flex gap-1 justify-end">
                  <Button size="icon" variant="ghost" title="Balance history" onClick={() => onAudit(ta)}><History size={14} /></Button>
                  {ta.type === 'ppf' && <Button size="icon" variant="ghost" title="Deposit" onClick={() => onDeposit(ta)}><ArrowDownToLine size={14} /></Button>}
                  <Button size="icon" variant="ghost" title="Edit" onClick={() => onEdit(ta)}><Pencil size={14} /></Button>
                  <Button size="icon" variant="ghost" title="Adjust balance" onClick={() => onAdjust(ta)}><SlidersHorizontal size={14} /></Button>
                  <Button size="icon" variant="ghost" title="Close / mature" onClick={() => onClose(ta)}><XCircle size={14} /></Button>
                </TableCell>
              </TableRow>
            ))}
            {activeTerms.length === 0 && (
              <TableRow><TableCell colSpan={10} className="text-center text-muted-foreground py-8">No active FD / PPF accounts</TableCell></TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {closedTerms.length > 0 && (
        <div className="flex flex-col gap-3">
          <h3 className="text-base font-medium text-muted-foreground">Closed Term Accounts</h3>
          <div className="rounded-lg border overflow-hidden opacity-60">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Type</TableHead><TableHead>Bank</TableHead><TableHead>Account No.</TableHead>
                  <TableHead className="text-right">Amount</TableHead><TableHead className="text-right">Rate</TableHead>
                  <TableHead>Open Date</TableHead><TableHead>Closed Date</TableHead>
                  <TableHead className="text-right">Closing Balance</TableHead><TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {closedTerms.map(ta => (
                  <TableRow key={ta.id}>
                    <TableCell><Badge variant="outline">{TERM_ACCOUNT_TYPE_LABELS[ta.type]}</Badge></TableCell>
                    <TableCell>{ta.bank.name} <span className="text-muted-foreground text-xs">({ta.bank.short_name})</span></TableCell>
                    <TableCell className="text-muted-foreground font-mono text-sm">{ta.account_number || '—'}</TableCell>
                    <TableCell className="text-right font-mono">{formatCurrency(ta.amount)}</TableCell>
                    <TableCell className="text-right font-mono">{ta.interest_rate}%</TableCell>
                    <TableCell className="text-muted-foreground text-sm">{ta.open_date}</TableCell>
                    <TableCell className="text-muted-foreground text-sm">{ta.closed_date ?? '—'}</TableCell>
                    <TableCell className="text-right font-mono">{ta.closed_amount != null ? formatCurrency(ta.closed_amount) : '—'}</TableCell>
                    <TableCell className="flex gap-1 justify-end">
                      <Button size="icon" variant="ghost" title="Balance history" onClick={() => onAudit(ta)}><History size={14} /></Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </div>
      )}
    </>
  )
}
