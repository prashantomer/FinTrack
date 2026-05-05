import { History, Pencil, SlidersHorizontal, XCircle } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { ACCOUNT_TYPE_LABELS } from '@/lib/labels'
import type { Account } from '@/types'

interface Props {
  accounts: Account[]
  formatCurrency: (v: number) => string
  onEdit: (a: Account) => void
  onClose: (a: Account) => void
  onAdjust: (a: Account) => void
  onAudit: (a: Account) => void
}

export function AccountsTable({ accounts, formatCurrency, onEdit, onClose, onAdjust, onAudit }: Props) {
  return (
    <div className="rounded-lg border overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Nickname</TableHead>
            <TableHead>Bank</TableHead>
            <TableHead>Type</TableHead>
            <TableHead>Account No.</TableHead>
            <TableHead>Opened</TableHead>
            <TableHead className="text-right">Balance</TableHead>
            <TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>
          {accounts.map(a => (
            <TableRow key={a.id} className={a.closed_date ? 'opacity-50' : ''}>
              <TableCell className="font-medium">{a.nickname}</TableCell>
              <TableCell>
                {a.bank.name}{' '}
                <span className="text-muted-foreground text-xs">({a.bank.short_name})</span>
              </TableCell>
              <TableCell>
                <Badge variant="outline">{ACCOUNT_TYPE_LABELS[a.account_type]}</Badge>
              </TableCell>
              <TableCell className="text-muted-foreground font-mono text-sm">{a.account_number || '—'}</TableCell>
              <TableCell className="text-muted-foreground text-sm">{a.open_date || '—'}</TableCell>
              <TableCell className={`text-right font-mono font-medium ${(a.balance ?? 0) >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                {formatCurrency(a.balance ?? 0)}
              </TableCell>
              <TableCell className="flex gap-1 justify-end">
                <Button size="icon" variant="ghost" title="Balance history" onClick={() => onAudit(a)}><History size={14} /></Button>
                {!a.closed_date && (
                  <>
                    <Button size="icon" variant="ghost" title="Adjust balance" onClick={() => onAdjust(a)}><SlidersHorizontal size={14} /></Button>
                    <Button size="icon" variant="ghost" onClick={() => onEdit(a)}><Pencil size={14} /></Button>
                    <Button size="icon" variant="ghost" title="Close account" onClick={() => onClose(a)}><XCircle size={14} /></Button>
                  </>
                )}
              </TableCell>
            </TableRow>
          ))}
          {accounts.length === 0 && (
            <TableRow>
              <TableCell colSpan={7} className="text-center text-muted-foreground py-8">No accounts yet</TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  )
}
