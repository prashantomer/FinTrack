import { PlusCircle, TrendingDown, TrendingUp } from 'lucide-react'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { type AuditTarget, useAuditLogs } from '@/hooks/useAuditLogs'
import { useCurrency } from '@/hooks/useCurrency'

interface Props {
  target: AuditTarget
  onClose: () => void
}

const fmtDate = new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
const fmtTime = new Intl.DateTimeFormat('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })

function splitDatetime(iso: string) {
  const d = new Date(iso)
  return { date: fmtDate.format(d), time: fmtTime.format(d) }
}

function fmtTxnDate(iso: string) {
  return fmtDate.format(new Date(iso))
}

export function AuditLogSidebar({ target, onClose }: Props) {
  const { formatCurrency } = useCurrency()
  const fmtCurrency = { format: formatCurrency }
  const { data: logs = [], isLoading } = useAuditLogs(target)

  return (
    <Sheet open={target !== null} onOpenChange={(open) => { if (!open) onClose() }}>
      <SheetContent side="right" className="w-[400px] sm:max-w-[400px] flex flex-col p-0 overflow-hidden">

        <SheetHeader className="border-b px-6 py-5 shrink-0">
          <SheetTitle className="text-base">Balance History</SheetTitle>
          {target && (
            <p className="text-sm text-muted-foreground">
              {target.label}
              <span className="mx-1.5 text-muted-foreground/40">·</span>
              {target.subtitle}
            </p>
          )}
        </SheetHeader>

        <div className="flex-1 overflow-y-auto">
          {isLoading && (
            <p className="text-sm text-muted-foreground py-12 text-center">Loading…</p>
          )}

          {!isLoading && logs.length === 0 && (
            <p className="text-sm text-muted-foreground py-12 text-center">No balance changes recorded yet.</p>
          )}

          {logs.map((log) => {
            const isInsert = log.old_value === null
            const oldVal = log.old_value !== null ? parseFloat(log.old_value) : null
            const newVal = log.new_value !== null ? parseFloat(log.new_value) : null
            const delta = oldVal !== null && newVal !== null ? newVal - oldVal : null
            const isCredit = delta !== null && delta >= 0
            const txn = log.transaction
            const { date, time } = splitDatetime(log.changed_at)
            const label = isInsert
              ? 'Account opened'
              : txn?.description || (txn ? (txn.type === 'credit' ? 'Credit' : 'Debit') : 'Balance update')

            return (
              <div key={log.id} className="flex items-start gap-4 px-6 py-4 border-b last:border-0">
                <div className={`mt-0.5 shrink-0 rounded-full p-1.5 ${
                  isInsert
                    ? 'bg-muted text-muted-foreground'
                    : isCredit ? 'bg-green-50 text-green-600' : 'bg-red-50 text-red-500'
                }`}>
                  {isInsert
                    ? <PlusCircle size={13} />
                    : isCredit ? <TrendingUp size={13} /> : <TrendingDown size={13} />
                  }
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-baseline justify-between gap-2">
                    <span className="text-sm font-medium truncate">{label}</span>
                    {delta !== null && (
                      <span className={`text-sm font-semibold font-mono shrink-0 ${isCredit ? 'text-green-600' : 'text-red-500'}`}>
                        {isCredit ? '+' : '−'}{fmtCurrency.format(Math.abs(delta))}
                      </span>
                    )}
                    {isInsert && newVal !== null && (
                      <span className="text-sm font-semibold font-mono shrink-0 text-muted-foreground">
                        {fmtCurrency.format(newVal)}
                      </span>
                    )}
                  </div>

                  <div className="flex items-center justify-between mt-0.5">
                    <span className="text-xs text-muted-foreground">{date} <span className="opacity-60">{time}</span></span>
                    {!isInsert && newVal !== null && (
                      <span className="text-xs text-muted-foreground font-mono">bal {fmtCurrency.format(newVal)}</span>
                    )}
                  </div>

                  {txn && (
                    <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted-foreground border-t pt-2">
                      <span>Txn: {fmtTxnDate(txn.date)}</span>
                      <span className="font-mono">{fmtCurrency.format(txn.amount)}</span>
                      {txn.bank_ref && <span className="font-mono bg-muted px-1.5 py-0.5 rounded">{txn.bank_ref}</span>}
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </SheetContent>
    </Sheet>
  )
}
