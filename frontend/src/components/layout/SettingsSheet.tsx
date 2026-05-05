import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { useAuth } from '@/context/AuthContext'
import { updateMe } from '@/api/auth'

const CURRENCY_OPTIONS = [
  { code: 'INR', locale: 'en-IN', label: 'Indian Rupee (₹)' },
  { code: 'USD', locale: 'en-US', label: 'US Dollar ($)' },
  { code: 'EUR', locale: 'de-DE', label: 'Euro (€)' },
  { code: 'GBP', locale: 'en-GB', label: 'British Pound (£)' },
  { code: 'JPY', locale: 'ja-JP', label: 'Japanese Yen (¥)' },
  { code: 'SGD', locale: 'en-SG', label: 'Singapore Dollar (S$)' },
  { code: 'AED', locale: 'ar-AE', label: 'UAE Dirham (AED)' },
  { code: 'AUD', locale: 'en-AU', label: 'Australian Dollar (A$)' },
  { code: 'CAD', locale: 'en-CA', label: 'Canadian Dollar (C$)' },
]

interface FormValues {
  full_name: string
  currency_code: string
}

interface Props {
  open: boolean
  onClose: () => void
}

export function SettingsSheet({ open, onClose }: Props) {
  const { user, updateUser } = useAuth()
  const [saving, setSaving] = useState(false)

  const { register, handleSubmit, setValue, watch, formState: { errors } } = useForm<FormValues>({
    values: {
      full_name: user ? `${user.first_name} ${user.last_name}` : '',
      currency_code: user?.currency_code ?? 'INR',
    },
  })

  const currencyCode = watch('currency_code')
  const selectedOption = CURRENCY_OPTIONS.find(o => o.code === currencyCode)

  async function onSubmit(data: FormValues) {
    const option = CURRENCY_OPTIONS.find(o => o.code === data.currency_code) ?? CURRENCY_OPTIONS[0]
    setSaving(true)
    try {
      const updated = await updateMe({
        full_name: data.full_name,
        currency_code: option.code,
        currency_locale: option.locale,
      })
      updateUser(updated)
      toast.success('Settings saved')
      onClose()
    } catch {
      toast.error('Failed to save settings')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Sheet open={open} onOpenChange={(o) => { if (!o) onClose() }}>
      <SheetContent side="right" className="w-[360px] sm:max-w-[360px] flex flex-col p-0 overflow-hidden">
        <SheetHeader className="border-b px-6 py-5 shrink-0">
          <SheetTitle className="text-base">Settings</SheetTitle>
          {user && (
            <p className="text-sm text-muted-foreground">{user.email}</p>
          )}
        </SheetHeader>

        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col flex-1 overflow-y-auto">
          <div className="px-6 py-5 space-y-5 flex-1">
            <div className="space-y-1.5">
              <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Profile</p>
              <Separator />
            </div>

            <div className="space-y-2">
              <Label htmlFor="full_name">Full Name</Label>
              <Input
                id="full_name"
                {...register('full_name', { required: 'Name is required', minLength: { value: 2, message: 'Name must be at least 2 characters' } })}
              />
              {errors.full_name && (
                <p className="text-xs text-destructive">{errors.full_name.message}</p>
              )}
            </div>

            <div className="space-y-1.5 pt-2">
              <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Currency</p>
              <Separator />
            </div>

            <div className="space-y-2">
              <Label>Display Currency</Label>
              <Select
                value={currencyCode}
                onValueChange={(val) => setValue('currency_code', val, { shouldDirty: true })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select currency" />
                </SelectTrigger>
                <SelectContent>
                  {CURRENCY_OPTIONS.map(opt => (
                    <SelectItem key={opt.code} value={opt.code}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {selectedOption && (
                <p className="text-xs text-muted-foreground">
                  Preview: {new Intl.NumberFormat(selectedOption.locale, {
                    style: 'currency',
                    currency: selectedOption.code,
                    maximumFractionDigits: 0,
                  }).format(125000)}
                </p>
              )}
            </div>
          </div>

          <div className="border-t px-6 py-4 shrink-0">
            <Button type="submit" className="w-full" disabled={saving}>
              {saving ? 'Saving…' : 'Save Changes'}
            </Button>
          </div>
        </form>
      </SheetContent>
    </Sheet>
  )
}
