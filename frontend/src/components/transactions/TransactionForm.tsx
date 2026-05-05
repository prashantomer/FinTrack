import { useForm } from 'react-hook-form'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useAccounts } from '@/hooks/useBanks'
import { ACCOUNT_TYPE_LABELS, TRANSACTION_TYPE_LABELS } from '@/lib/labels'
import { useCurrency } from '@/hooks/useCurrency'
import type { LinkedAccountType, TransactionType } from '@/types'

interface FormValues {
  amount: number
  type: TransactionType
  linked_account_type: LinkedAccountType | ''
  linked_account_id: number | null
  tags_input: string
  bank_ref: string
  description: string
  date: string
  instrument_id: number | null
}

interface Props {
  onSubmit: (values: FormValues) => Promise<void>
  onCancel: () => void
}

export function TransactionForm({ onSubmit, onCancel }: Props) {
  const { symbol: CURRENCY_SYMBOL } = useCurrency()
  const { data: accounts = [] } = useAccounts()

  const { register, handleSubmit, setValue, watch, formState: { isSubmitting } } = useForm<FormValues>({
    defaultValues: {
      amount: 0,
      type: 'debit',
      linked_account_type: '',
      linked_account_id: null,
      tags_input: '',
      bank_ref: '',
      description: '',
      date: new Date().toISOString().split('T')[0],
      instrument_id: null,
    },
  })

  const type = watch('type')
  const linkedAccountType = watch('linked_account_type')
  const linkedAccountId = watch('linked_account_id')

  function buildLinkedAccountKey(lat: LinkedAccountType | '', laid: number | null) {
    if (!lat || !laid) return '__none__'
    return `${lat}:${laid}`
  }

  function parseLinkedAccountKey(key: string): { type: LinkedAccountType | ''; id: number | null } {
    if (key === '__none__') return { type: '', id: null }
    const [t, id] = key.split(':')
    return { type: t as LinkedAccountType, id: Number(id) }
  }

  async function handleFormSubmit(values: FormValues) {
    await onSubmit(values)
  }

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label>Amount ({CURRENCY_SYMBOL})</Label>
          <Input type="number" step="0.01" min="0.01" {...register('amount', { valueAsNumber: true })} required />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Date</Label>
          <Input type="date" {...register('date')} required />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Type</Label>
        <Select value={type} onValueChange={(v) => setValue('type', v as TransactionType)}>
          <SelectTrigger>
            <span className="flex flex-1 text-left text-sm">{TRANSACTION_TYPE_LABELS[type]}</span>
          </SelectTrigger>
          <SelectContent>
            {(Object.keys(TRANSACTION_TYPE_LABELS) as TransactionType[]).map((t) => (
              <SelectItem key={t} value={t}>{TRANSACTION_TYPE_LABELS[t]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Linked Account <span className="text-muted-foreground text-xs">(optional)</span></Label>
        <Select
          value={buildLinkedAccountKey(linkedAccountType, linkedAccountId)}
          onValueChange={(v) => {
            const { type: lat, id } = parseLinkedAccountKey(v)
            setValue('linked_account_type', lat)
            setValue('linked_account_id', id)
          }}
        >
          <SelectTrigger><SelectValue placeholder="Select account…" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="__none__">None</SelectItem>
            {accounts.map(a => (
              <SelectItem key={`account:${a.id}`} value={`account:${a.id}`}>
                {a.nickname} — {a.bank.short_name} ({ACCOUNT_TYPE_LABELS[a.account_type]})
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Tags <span className="text-muted-foreground text-xs">(comma-separated, optional)</span></Label>
        <Input {...register('tags_input')} placeholder="e.g. groceries, reimbursement" />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Description <span className="text-muted-foreground text-xs">(optional)</span></Label>
        <Input {...register('description')} placeholder="Optional" />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Bank Ref / UTR <span className="text-muted-foreground text-xs">(optional)</span></Label>
        <Input {...register('bank_ref')} placeholder="UTR / IMPS / NEFT reference" />
      </div>

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onCancel}>Cancel</Button>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Saving…' : 'Create'}
        </Button>
      </div>
    </form>
  )
}
