import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useCurrency } from '@/hooks/useCurrency'
import type { LotRead } from '@/types'

export function InstrumentLotsTable({ lots }: { lots: LotRead[] }) {
  const { formatCurrency } = useCurrency()

  if (lots.length === 0) {
    return <p className="text-sm text-muted-foreground py-6 text-center">No lots yet.</p>
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-[110px]">Date</TableHead>
          <TableHead className="w-[70px]">Trade</TableHead>
          <TableHead className="text-right">Qty / Units</TableHead>
          <TableHead className="text-right w-[100px]">Price</TableHead>
          <TableHead className="text-right w-[120px]">Amount</TableHead>
          <TableHead className="text-right">P&amp;L</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {lots.map(lot => {
          const qty    = lot.quantity ?? lot.units ?? null
          const lotPnl = lot.pnl
          return (
            <TableRow key={lot.id}>
              <TableCell className="text-muted-foreground text-sm">{lot.purchase_date}</TableCell>
              <TableCell>
                <Badge variant={lot.trade_type === 'sell' ? 'destructive' : 'default'} className="text-[10px] uppercase">
                  {lot.trade_type}
                </Badge>
              </TableCell>
              <TableCell className="text-right font-mono text-sm">
                {qty != null ? qty.toLocaleString('en-IN', { maximumFractionDigits: 4 }) : '—'}
              </TableCell>
              <TableCell className="text-right font-mono text-sm text-muted-foreground">
                {lot.price != null ? formatCurrency(lot.price) : '—'}
              </TableCell>
              <TableCell className="text-right font-mono">{formatCurrency(lot.amount_invested)}</TableCell>
              <TableCell
                className={`text-right font-mono text-sm ${
                  lotPnl == null ? 'text-muted-foreground' : lotPnl.value >= 0 ? 'text-green-600' : 'text-red-500'
                }`}
                title={[ lotPnl?.label, lot.platform_account_nickname && `Platform: ${lot.platform_account_nickname}`, lot.notes ].filter(Boolean).join(' · ') || undefined}
              >
                {lotPnl == null ? '—' : (
                  <>
                    {lotPnl.value >= 0 ? '+' : ''}{formatCurrency(lotPnl.value)}
                    {lotPnl.pct != null && (
                      <span className="text-[10px] text-muted-foreground ml-1">({lotPnl.pct >= 0 ? '+' : ''}{lotPnl.pct.toFixed(1)}%)</span>
                    )}
                  </>
                )}
              </TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
