import { useForm } from 'react-hook-form'
import { InstrumentCombobox } from '@/components/instruments/InstrumentCombobox'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { usePlatformAccounts } from '@/hooks/usePlatforms'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import { CURRENCY_SYMBOL } from '@/lib/currency'
import type { Investment, InvestmentType } from '@/types'

const INVESTMENT_TYPES = Object.keys(INVESTMENT_TYPE_LABELS) as InvestmentType[]

type FormValues = Partial<Investment> & {
  type: InvestmentType
  name: string
  amount_invested: number
  purchase_date: string
  platform_account_id: number | null
  instrument_id: number | null
}

interface Props {
  initial?: Investment
  onSubmit: (values: FormValues) => Promise<void>
  onCancel: () => void
}

export function InvestmentForm({ initial, onSubmit, onCancel }: Props) {
  const { data: platformAccounts = [] } = usePlatformAccounts()
  const { register, handleSubmit, setValue, watch, formState: { isSubmitting } } = useForm<FormValues>({
    defaultValues: {
      type: initial?.type ?? 'stock',
      name: initial?.name ?? '',
      amount_invested: initial?.amount_invested ?? 0,
      current_value: initial?.current_value ?? undefined,
      purchase_date: initial?.purchase_date ?? new Date().toISOString().split('T')[0],
      notes: initial?.notes ?? '',
      platform_account_id: initial?.platform_account_id ?? null,
      instrument_id: initial?.instrument_id ?? null,
      ticker_symbol: initial?.ticker_symbol ?? '',
      quantity: initial?.quantity ?? undefined,
      avg_buy_price: initial?.avg_buy_price ?? undefined,
      exchange: initial?.exchange ?? '',
      folio_number: initial?.folio_number ?? '',
      units: initial?.units ?? undefined,
      nav_at_purchase: initial?.nav_at_purchase ?? undefined,
      fund_house: initial?.fund_house ?? '',
      bank_name: initial?.bank_name ?? '',
      interest_rate: initial?.interest_rate ?? undefined,
      tenure_months: initial?.tenure_months ?? undefined,
      maturity_date: initial?.maturity_date ?? '',
      maturity_amount: initial?.maturity_amount ?? undefined,
      compounding: initial?.compounding ?? '',
      gold_form: initial?.gold_form ?? '',
      weight_grams: initial?.weight_grams ?? undefined,
      purity: initial?.purity ?? '',
    },
  })

  const type = watch('type')
  const platformAccountId = watch('platform_account_id')
  const instrumentId = watch('instrument_id')

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4 max-h-[70vh] overflow-y-auto pr-1">
      <div className="flex flex-col gap-1.5">
        <Label>Type</Label>
        <Select value={type} onValueChange={(v) => setValue('type', v as InvestmentType)}>
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            {INVESTMENT_TYPES.map(t => (
              <SelectItem key={t} value={t}>{INVESTMENT_TYPE_LABELS[t]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Instrument <span className="text-muted-foreground text-xs">(optional)</span></Label>
        <InstrumentCombobox
          value={instrumentId}
          onChange={(id) => setValue('instrument_id', id)}
          filterType={type}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Platform Account <span className="text-muted-foreground text-xs">(optional)</span></Label>
        <Select
          value={platformAccountId?.toString() ?? '__none__'}
          onValueChange={(v) => setValue('platform_account_id', v === '__none__' ? null : Number(v))}
        >
          <SelectTrigger><SelectValue placeholder="Select platform account…" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="__none__">None</SelectItem>
            {platformAccounts.map(pa => (
              <SelectItem key={pa.id} value={pa.id.toString()}>
                {pa.nickname} — {pa.platform.short_name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-1.5 col-span-2">
          <Label>Name</Label>
          <Input {...register('name')} required />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Amount Invested ({CURRENCY_SYMBOL})</Label>
          <Input type="number" step="0.01" min="0.01" {...register('amount_invested', { valueAsNumber: true })} required />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Current Value ({CURRENCY_SYMBOL})</Label>
          <Input type="number" step="0.01" min="0" {...register('current_value', { valueAsNumber: true })} />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Purchase Date</Label>
          <Input type="date" {...register('purchase_date')} required />
        </div>
      </div>

      {(type === 'stock' || type === 'crypto') && (
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Ticker Symbol</Label>
            <Input {...register('ticker_symbol')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Exchange</Label>
            <Input {...register('exchange')} placeholder="NSE / BSE" />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Quantity</Label>
            <Input type="number" step="0.0001" {...register('quantity', { valueAsNumber: true })} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Avg Buy Price ({CURRENCY_SYMBOL})</Label>
            <Input type="number" step="0.01" {...register('avg_buy_price', { valueAsNumber: true })} />
          </div>
        </div>
      )}

      {type === 'mutual_fund' && (
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Fund House</Label>
            <Input {...register('fund_house')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Folio Number</Label>
            <Input {...register('folio_number')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Units</Label>
            <Input type="number" step="0.0001" {...register('units', { valueAsNumber: true })} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>NAV at Purchase</Label>
            <Input type="number" step="0.0001" {...register('nav_at_purchase', { valueAsNumber: true })} />
          </div>
        </div>
      )}

      {type === 'fixed_deposit' && (
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Bank Name</Label>
            <Input {...register('bank_name')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>FD Number</Label>
            <Input {...register('fd_number')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Interest Rate (%)</Label>
            <Input type="number" step="0.01" {...register('interest_rate', { valueAsNumber: true })} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Tenure (months)</Label>
            <Input type="number" {...register('tenure_months', { valueAsNumber: true })} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Maturity Date</Label>
            <Input type="date" {...register('maturity_date')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Maturity Amount ({CURRENCY_SYMBOL})</Label>
            <Input type="number" step="0.01" {...register('maturity_amount', { valueAsNumber: true })} />
          </div>
          <div className="flex flex-col gap-1.5 col-span-2">
            <Label>Compounding</Label>
            <Input {...register('compounding')} placeholder="quarterly / monthly / annual" />
          </div>
        </div>
      )}

      {type === 'gold' && (
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Form</Label>
            <Input {...register('gold_form')} placeholder="coin / bar / ETF / SGB" />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Weight (grams)</Label>
            <Input type="number" step="0.001" {...register('weight_grams', { valueAsNumber: true })} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Purity</Label>
            <Input {...register('purity')} placeholder="24K / 22K" />
          </div>
        </div>
      )}

      <div className="flex flex-col gap-1.5">
        <Label>Notes</Label>
        <Textarea {...register('notes')} rows={2} />
      </div>

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onCancel}>Cancel</Button>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Saving…' : initial ? 'Update' : 'Create'}
        </Button>
      </div>
    </form>
  )
}
