import { useForm } from 'react-hook-form'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { useUserInstruments } from '@/hooks/useInstruments'
import { usePlatformAccounts } from '@/hooks/usePlatforms'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import { useCurrency } from '@/hooks/useCurrency'
import type { Investment, InvestmentType } from '@/types'

const INVESTMENT_TYPES = Object.keys(INVESTMENT_TYPE_LABELS) as InvestmentType[]

type FormValues = {
  type: InvestmentType
  name: string
  amount_invested: number
  current_value?: number
  purchase_date: string
  notes?: string
  platform_account_id: number | null
  user_instrument_id: number | null
  quantity?: number
  buy_price?: number
  folio_number?: string
  units?: number
  nav_at_purchase?: number
}

interface Props {
  initial?: Investment
  onSubmit: (values: FormValues) => Promise<void>
  onCancel: () => void
}

export function InvestmentForm({ initial, onSubmit, onCancel }: Props) {
  const { symbol: CURRENCY_SYMBOL } = useCurrency()
  const { data: platformAccounts = [] } = usePlatformAccounts()
  const { data: userInstruments = [] } = useUserInstruments()
  const { register, handleSubmit, setValue, watch, formState: { isSubmitting } } = useForm<FormValues>({
    defaultValues: {
      type: initial?.type ?? 'stock',
      name: initial?.name ?? '',
      amount_invested: initial?.amount_invested ?? 0,
      current_value: initial?.current_value ?? undefined,
      purchase_date: initial?.purchase_date ?? new Date().toISOString().split('T')[0],
      notes: initial?.notes ?? '',
      platform_account_id: initial?.platform_account_id ?? null,
      user_instrument_id: initial?.user_instrument_id ?? null,
      quantity: initial?.quantity ?? undefined,
      buy_price: initial?.buy_price ?? undefined,
      folio_number: initial?.folio_number ?? '',
      units: initial?.units ?? undefined,
      nav_at_purchase: initial?.nav_at_purchase ?? undefined,
    },
  })

  const type = watch('type')
  const platformAccountId = watch('platform_account_id')
  const userInstrumentId = watch('user_instrument_id')

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <Label>Type</Label>
        <Select value={type} onValueChange={(v) => setValue('type', v as InvestmentType)}>
          <SelectTrigger>
            <span className="flex flex-1 text-left text-sm">{INVESTMENT_TYPE_LABELS[type]}</span>
          </SelectTrigger>
          <SelectContent>
            {INVESTMENT_TYPES.map(t => (
              <SelectItem key={t} value={t}>{INVESTMENT_TYPE_LABELS[t]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>
          Instrument
          {(type === 'stock' || type === 'mutual_fund') && (
            <span className="text-destructive ml-1">*</span>
          )}
          {type !== 'stock' && type !== 'mutual_fund' && (
            <span className="text-muted-foreground text-xs ml-1">(optional — tracked only)</span>
          )}
        </Label>
        <Select
          value={userInstrumentId?.toString() ?? '__none__'}
          onValueChange={(v) => setValue('user_instrument_id', v === '__none__' ? null : Number(v))}
        >
          <SelectTrigger><SelectValue placeholder="Select tracked instrument…" /></SelectTrigger>
          <SelectContent>
            {type !== 'stock' && type !== 'mutual_fund' && (
              <SelectItem value="__none__">None</SelectItem>
            )}
            {userInstruments
              .filter(ui => ui.instrument.type === type)
              .map(ui => (
                <SelectItem key={ui.id} value={ui.id.toString()}>
                  {ui.instrument.name}
                </SelectItem>
              ))}
          </SelectContent>
        </Select>
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

      {type === 'stock' && (
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Quantity</Label>
            <Input type="number" step="0.0001" {...register('quantity', { valueAsNumber: true })} required />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Buy Price ({CURRENCY_SYMBOL})</Label>
            <Input type="number" step="0.01" {...register('buy_price', { valueAsNumber: true })} required />
          </div>
        </div>
      )}

      {type === 'mutual_fund' && (
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Folio Number</Label>
            <Input {...register('folio_number')} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Units</Label>
            <Input type="number" step="0.0001" {...register('units', { valueAsNumber: true })} required />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>NAV at Purchase ({CURRENCY_SYMBOL})</Label>
            <Input type="number" step="0.0001" {...register('nav_at_purchase', { valueAsNumber: true })} required />
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
