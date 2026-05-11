import { useState } from 'react'
import { AlertTriangle, ArrowRight, CheckCircle2, Eraser } from 'lucide-react'
import { PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { useAccounts } from '@/hooks/useBanks'
import { useExecuteCleanup, usePreviewCleanup } from '@/hooks/useCleanup'
import type { CleanupConfig, CleanupPreviewResponse, CleanupSector } from '@/api/cleanup'

const ALL_SECTORS: { key: CleanupSector; label: string; hint: string }[] = [
  { key: 'transactions',       label: 'Transactions',       hint: 'Bank-account credits/debits' },
  { key: 'investments',        label: 'Investments',        hint: 'Stock & MF lots' },
  { key: 'holdings',           label: 'Holdings',           hint: 'Aggregated position cache' },
  { key: 'import_batches',     label: 'Import batches',     hint: 'CSV/XLS imports + records + attached files' },
  { key: 'account_audits',     label: 'Account audits',     hint: 'Balance-history audit rows' },
  { key: 'user_instruments',   label: 'User instruments',   hint: 'Tracked-instrument watchlist' },
  { key: 'platform_accounts',  label: 'Platform accounts',  hint: 'Zerodha / Coin / etc.' },
  { key: 'term_accounts',      label: 'Term accounts',      hint: 'FD + PPF' },
  { key: 'accounts',           label: 'Bank accounts',      hint: 'Savings / current / NRE / NRO' },
  { key: 'assistant_messages', label: 'Assistant messages', hint: 'Chat history (keeps API key + provider config)' },
]

type Step = 'config' | 'preview' | 'done'

export function CleanupPage() {
  const [step, setStep]         = useState<Step>('config')
  const [config, setConfig]     = useState<CleanupConfig>({ sectors: [] })
  const [confirmText, setConfirmText] = useState('')
  const [preview, setPreview]   = useState<CleanupPreviewResponse | null>(null)
  const [result, setResult]     = useState<{ total: number } | null>(null)

  const previewMutation = usePreviewCleanup()
  const executeMutation = useExecuteCleanup()
  const { data: accounts = [] } = useAccounts()

  const fmt = (n: number) => new Intl.NumberFormat('en-IN').format(n)
  const fmtMoney = (n: number) =>
    new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(n)

  function toggleSector(key: CleanupSector) {
    setConfig(c => ({
      ...c,
      sectors: c.sectors.includes(key) ? c.sectors.filter(s => s !== key) : [ ...c.sectors, key ],
    }))
  }

  async function loadPreview() {
    const data = await previewMutation.mutateAsync(config)
    setPreview(data)
    setStep('preview')
  }

  async function execute() {
    const data = await executeMutation.mutateAsync(config)
    setResult({ total: data.total })
    setStep('done')
  }

  function startOver() {
    setStep('config')
    setConfig({ sectors: [] })
    setConfirmText('')
    setPreview(null)
    setResult(null)
  }

  const canPreview = config.sectors.length > 0
  const canExecute = preview && preview.total > 0 && confirmText === 'DELETE'

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Cleanup"
        description="Selectively delete your data"
        onRefresh={() => {}}
      />

      <div className="flex-1 overflow-auto px-6 py-6 max-w-4xl w-full mx-auto space-y-6">
        {/* Step indicator */}
        <div className="flex items-center gap-3 text-xs">
          <StepDot active={step === 'config'}  done={step !== 'config'} label="1 · Configure" />
          <ArrowRight size={12} className="text-muted-foreground" />
          <StepDot active={step === 'preview'} done={step === 'done'}   label="2 · Preview" />
          <ArrowRight size={12} className="text-muted-foreground" />
          <StepDot active={step === 'done'}    done={false}             label="3 · Done" />
        </div>

        {step === 'config' && (
          <div className="space-y-6">
            <div>
              <p className="text-sm font-semibold mb-2">Sectors to clean</p>
              <p className="text-xs text-muted-foreground mb-3">
                Pick what you want to delete. <strong>Assistant settings</strong> (provider + API key) and
                the user account itself are never touched.
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {ALL_SECTORS.map(s => (
                  <label key={s.key} className="flex items-start gap-2 cursor-pointer rounded-md border px-3 py-2 hover:bg-muted/50">
                    <input
                      type="checkbox"
                      className="mt-0.5"
                      checked={config.sectors.includes(s.key)}
                      onChange={() => toggleSector(s.key)}
                    />
                    <div>
                      <p className="text-sm font-medium">{s.label}</p>
                      <p className="text-xs text-muted-foreground">{s.hint}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            <Separator />

            <div>
              <p className="text-sm font-semibold mb-2">Filters <span className="text-muted-foreground font-normal">(optional)</span></p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <Label className="text-xs">Date from</Label>
                  <Input type="date" value={config.date_from ?? ''} onChange={e => setConfig({ ...config, date_from: e.target.value || undefined })} />
                </div>
                <div>
                  <Label className="text-xs">Date to</Label>
                  <Input type="date" value={config.date_to ?? ''} onChange={e => setConfig({ ...config, date_to: e.target.value || undefined })} />
                </div>

                <div>
                  <Label className="text-xs">Source</Label>
                  <Select
                    value={config.source ?? 'all'}
                    onValueChange={v => setConfig({ ...config, source: v === 'all' ? undefined : v as 'manual' | 'imported' })}
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All sources</SelectItem>
                      <SelectItem value="manual">Manual entries only</SelectItem>
                      <SelectItem value="imported">Imported only</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label className="text-xs">Bank account (Transactions / Accounts)</Label>
                  <Select
                    value={config.account_ids?.[0]?.toString() ?? 'all'}
                    onValueChange={v => setConfig({ ...config, account_ids: v === 'all' ? undefined : [ Number(v) ] })}
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All accounts</SelectItem>
                      {accounts.map(a => (
                        <SelectItem key={a.id} value={String(a.id)}>{a.nickname}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label className="text-xs">Transactions: tags (any of these)</Label>
                  <Input
                    placeholder="adjustment, salary, …"
                    value={(config.tags_any ?? []).join(', ')}
                    onChange={e => setConfig({ ...config, tags_any: e.target.value.split(',').map(s => s.trim()).filter(Boolean) })}
                  />
                </div>

                <div className="flex items-center gap-2 pt-6">
                  <input
                    id="reset_balances"
                    type="checkbox"
                    checked={!!config.reset_balances}
                    onChange={e => setConfig({ ...config, reset_balances: e.target.checked })}
                  />
                  <Label htmlFor="reset_balances" className="text-xs cursor-pointer">
                    Reset all account &amp; PPF balances to ₹0 after cleanup
                  </Label>
                </div>
              </div>
            </div>

            <div className="flex justify-end">
              <Button disabled={!canPreview || previewMutation.isPending} onClick={loadPreview}>
                {previewMutation.isPending ? 'Loading…' : 'Preview impact →'}
              </Button>
            </div>
          </div>
        )}

        {step === 'preview' && preview && (
          <div className="space-y-6">
            <div className="rounded-md border border-amber-300 bg-amber-50 px-4 py-3 flex items-start gap-3">
              <AlertTriangle size={18} className="text-amber-600 shrink-0 mt-0.5" />
              <div className="text-sm text-amber-900">
                <p className="font-semibold">Review before / after carefully.</p>
                <p>The action is reversible only if you have a database backup.</p>
              </div>
            </div>

            <div>
              <p className="text-sm font-semibold mb-2">Records</p>
              <div className="rounded-md border overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-muted/60">
                    <tr>
                      <th className="text-left px-3 py-2 font-medium">Sector</th>
                      <th className="text-right px-3 py-2 font-medium">Before</th>
                      <th className="text-right px-3 py-2 font-medium">To delete</th>
                      <th className="text-right px-3 py-2 font-medium">After</th>
                    </tr>
                  </thead>
                  <tbody>
                    {preview.sectors.map(s => (
                      <tr key={s.sector} className="border-t">
                        <td className="px-3 py-2">{labelFor(s.sector)}</td>
                        <td className="px-3 py-2 text-right font-mono text-muted-foreground">{fmt(s.before)}</td>
                        <td className="px-3 py-2 text-right font-mono">
                          {s.to_delete > 0
                            ? <span className="text-red-600">−{fmt(s.to_delete)}</span>
                            : <span className="text-muted-foreground">0</span>}
                        </td>
                        <td className="px-3 py-2 text-right font-mono">{fmt(s.after)}</td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot className="bg-muted/30 border-t-2">
                    <tr>
                      <td className="px-3 py-2 font-semibold">Total to delete</td>
                      <td />
                      <td className="px-3 py-2 text-right font-mono font-semibold text-red-600">−{fmt(preview.total)}</td>
                      <td />
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>

            {preview.balance_reset.length > 0 && (
              <div>
                <p className="text-sm font-semibold mb-2">Balance reset</p>
                <div className="rounded-md border overflow-hidden">
                  <table className="w-full text-sm">
                    <thead className="bg-muted/60">
                      <tr>
                        <th className="text-left px-3 py-2 font-medium">Account</th>
                        <th className="text-right px-3 py-2 font-medium">Before</th>
                        <th className="text-right px-3 py-2 font-medium">After</th>
                      </tr>
                    </thead>
                    <tbody>
                      {preview.balance_reset.map(r => (
                        <tr key={r.id} className="border-t">
                          <td className="px-3 py-2">{r.nickname}</td>
                          <td className="px-3 py-2 text-right font-mono text-muted-foreground">{fmtMoney(r.before)}</td>
                          <td className="px-3 py-2 text-right font-mono">{fmtMoney(r.after)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            <div>
              <p className="text-sm font-semibold mb-2">Samples</p>
              <div className="rounded-md border divide-y text-xs max-h-64 overflow-y-auto">
                {preview.sectors.filter(s => s.to_delete > 0 && s.samples.length > 0).map(s => (
                  <div key={s.sector} className="px-3 py-2">
                    <p className="font-medium mb-1">{labelFor(s.sector)}</p>
                    {s.samples.map((line, i) => (
                      <p key={i} className="font-mono text-muted-foreground truncate">{line}</p>
                    ))}
                  </div>
                ))}
              </div>
            </div>

            <Separator />

            <div className="space-y-2">
              <Label className="text-xs">To confirm, type <code className="font-mono text-red-600">DELETE</code> below</Label>
              <Input
                value={confirmText}
                onChange={e => setConfirmText(e.target.value)}
                placeholder="DELETE"
                className="font-mono max-w-xs"
              />
            </div>

            <div className="flex justify-between">
              <Button variant="outline" onClick={() => setStep('config')}>← Back</Button>
              <Button
                variant="destructive"
                disabled={!canExecute || executeMutation.isPending}
                onClick={execute}
              >
                {executeMutation.isPending ? 'Cleaning up…' : 'Execute cleanup'}
              </Button>
            </div>
          </div>
        )}

        {step === 'done' && result && (
          <div className="space-y-4 text-center py-12">
            <div className="mx-auto w-12 h-12 rounded-full bg-green-100 text-green-700 flex items-center justify-center">
              <CheckCircle2 size={28} />
            </div>
            <p className="text-base font-semibold">Cleanup complete</p>
            <p className="text-sm text-muted-foreground">Deleted {fmt(result.total)} records.</p>
            <Button onClick={startOver}><Eraser size={14} className="mr-1.5" />Run another cleanup</Button>
          </div>
        )}
      </div>
    </div>
  )
}

function StepDot({ active, done, label }: { active: boolean; done: boolean; label: string }) {
  return (
    <Badge variant={active ? 'default' : done ? 'secondary' : 'outline'} className="font-mono">
      {label}
    </Badge>
  )
}

function labelFor(sector: CleanupSector): string {
  return ALL_SECTORS.find(s => s.key === sector)?.label ?? sector
}
