import { useEffect, useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { CheckCircle2, ChevronRight, CreditCard, Download, FileText, TrendingUp, Upload, XCircle } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { downloadTemplate } from '@/api/imports'
import { useCreateImport, useImport } from '@/hooks/useImports'
import { useAccounts } from '@/hooks/useBanks'
import { usePlatformAccounts } from '@/hooks/usePlatforms'
import type { Account, ImportType } from '@/types'

// ── Column reference per import type ────────────────────────────────────────
const COLUMN_REFS: Record<ImportType, { col: string; req: boolean; fmt: string; ex: string }[]> = {
  investments: [
    { col: 'investment_type', req: true,  fmt: 'stock | mutual_fund',       ex: 'stock' },
    { col: 'name',            req: true,  fmt: 'text',                      ex: 'Reliance Industries' },
    { col: 'isin',            req: false, fmt: '12-char string',            ex: 'INE002A01018' },
    { col: 'ticker_symbol',   req: false, fmt: 'text',                      ex: 'RELIANCE' },
    { col: 'exchange',        req: false, fmt: 'text',                      ex: 'NSE' },
    { col: 'fund_house',      req: false, fmt: 'text',                      ex: 'HDFC AMC' },
    { col: 'amount_invested', req: true,  fmt: 'decimal',                   ex: '15000.00' },
    { col: 'current_value',   req: false, fmt: 'decimal',                   ex: '18500.00' },
    { col: 'purchase_date',   req: true,  fmt: 'YYYY-MM-DD or DD/MM/YYYY', ex: '2024-01-15' },
    { col: 'quantity',        req: false, fmt: 'decimal (stocks)',          ex: '10' },
    { col: 'buy_price',       req: false, fmt: 'decimal (stocks)',          ex: '1500.00' },
    { col: 'units',           req: false, fmt: 'decimal (MF)',              ex: '100.000' },
    { col: 'nav_at_purchase', req: false, fmt: 'decimal (MF)',              ex: '500.00' },
    { col: 'folio_number',    req: false, fmt: 'text (MF)',                 ex: '12345678' },
    { col: 'platform_name',   req: false, fmt: 'text',                      ex: 'Zerodha' },
    { col: 'notes',           req: false, fmt: 'text',                      ex: 'Long-term hold' },
  ],
  transactions: [
    { col: 'date',                     req: true,  fmt: 'YYYY-MM-DD or DD/MM/YYYY', ex: '2024-01-15' },
    { col: 'amount',                   req: true,  fmt: 'decimal > 0',              ex: '5000.00' },
    { col: 'type',                     req: true,  fmt: 'credit | debit',           ex: 'credit' },
    { col: 'linked_account_nickname',  req: false, fmt: 'text (exact nickname)',     ex: 'HDFC Savings' },
    { col: 'description',              req: false, fmt: 'text',                      ex: 'Salary credit' },
    { col: 'tags',                     req: false, fmt: 'comma-separated',          ex: 'salary,income' },
    { col: 'bank_ref',                 req: false, fmt: 'text',                      ex: 'NEFT123456' },
  ],
  term_accounts: [
    { col: 'account_type',             req: true,  fmt: 'fd | ppf',                 ex: 'fd' },
    { col: 'parent_account_nickname',  req: true,  fmt: 'text (exact nickname)',     ex: 'HDFC Savings' },
    { col: 'account_number',           req: false, fmt: 'text (auto-generated)',     ex: 'FD20240115' },
    { col: 'amount',                   req: true,  fmt: 'decimal > 0',              ex: '100000.00' },
    { col: 'open_date',                req: true,  fmt: 'YYYY-MM-DD or DD/MM/YYYY', ex: '2024-01-15' },
    { col: 'interest_rate',            req: true,  fmt: 'decimal (annual %)',        ex: '7.5' },
    { col: 'tenure_days',              req: false, fmt: 'integer (required for FD)', ex: '365' },
    { col: 'maturity_date',            req: false, fmt: 'date (auto-calculated)',    ex: '2025-01-15' },
    { col: 'maturity_amount',          req: false, fmt: 'decimal (auto-calc for FD)',ex: '107500.00' },
    { col: 'balance',                  req: false, fmt: 'decimal (defaults to amount)', ex: '100000.00' },
  ],
}

// ── Step indicator ────────────────────────────────────────────────────────────
function StepIndicator({ current }: { current: number }) {
  const labels = ['Select Type', 'Context', 'Template', 'Upload', 'Processing']
  return (
    <div className="flex items-center gap-0 py-4 px-6 border-b">
      {labels.map((label, i) => {
        const n    = i + 1
        const done = n < current
        const active = n === current
        return (
          <div key={n} className="flex items-center flex-1 last:flex-none">
            <div className="flex flex-col items-center">
              <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold
                ${done   ? 'bg-green-600 text-white' :
                  active ? 'bg-primary text-primary-foreground' :
                           'bg-muted text-muted-foreground border'}`}>
                {done ? '✓' : n}
              </div>
              <span className={`text-[10px] mt-1 whitespace-nowrap ${active ? 'text-primary font-semibold' : 'text-muted-foreground'}`}>
                {label}
              </span>
            </div>
            {i < labels.length - 1 && (
              <div className={`flex-1 h-px mx-1 mb-4 ${done ? 'bg-green-600' : 'bg-border'}`} />
            )}
          </div>
        )
      })}
    </div>
  )
}

// ── Step 1: Select type ───────────────────────────────────────────────────────
const TYPE_OPTIONS: { type: ImportType; label: string; desc: string; icon: React.ElementType }[] = [
  { type: 'investments',  label: 'Investments',  desc: 'Stocks and mutual fund lots with full metadata', icon: TrendingUp },
  { type: 'transactions', label: 'Transactions', desc: 'Bank account credits and debits (historical)',   icon: CreditCard },
  { type: 'term_accounts',label: 'Term Accounts',desc: 'Fixed deposits and PPF accounts',               icon: FileText   },
]

function StepSelectType({ onNext }: { onNext: (t: ImportType) => void }) {
  return (
    <div className="flex flex-col gap-3 p-6 flex-1">
      <p className="text-sm text-muted-foreground">Choose what you want to import.</p>
      {TYPE_OPTIONS.map(({ type, label, desc, icon: Icon }) => (
        <button
          key={type}
          onClick={() => onNext(type)}
          className="flex items-center gap-4 rounded-lg border-2 border-primary bg-primary/5 p-4 text-left hover:bg-primary/10 transition-colors"
        >
          <Icon size={24} className="text-primary shrink-0" />
          <div className="flex-1">
            <p className="font-semibold text-sm">{label}</p>
            <p className="text-xs text-muted-foreground">{desc}</p>
          </div>
          <ChevronRight size={16} className="text-muted-foreground" />
        </button>
      ))}
    </div>
  )
}

// ── Step 2: Context options ───────────────────────────────────────────────────
interface ImportConfig {
  defaultPlatformAccountId: string
  autoCreatePlatforms:      boolean
  matchTransactions:        boolean
  defaultLinkedAccountId:   string
}

function StepContext({
  importType, config, setConfig, onBack, onNext,
}: {
  importType: ImportType
  config:     ImportConfig
  setConfig:  (c: ImportConfig) => void
  onBack:     () => void
  onNext:     () => void
}) {
  const { data: pas = [] } = usePlatformAccounts()
  const { data: accounts = [] } = useAccounts()

  const paList = Array.isArray(pas) ? pas : ((pas as { items?: typeof pas }).items ?? []) as { id: number; nickname: string; platform: { short_name: string } }[]
  const acctList = (Array.isArray(accounts) ? accounts : ((accounts as { items?: typeof accounts }).items ?? [])) as Account[]

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-5">
        <p className="text-sm text-muted-foreground">
          These settings help the importer associate records with your existing data.
        </p>

        {importType === 'investments' && (
          <>
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium">
                Default Platform Account <span className="text-muted-foreground font-normal">(optional)</span>
              </label>
              <Select
                value={config.defaultPlatformAccountId}
                onValueChange={v => setConfig({ ...config, defaultPlatformAccountId: v })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Use platform_name column in CSV" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">Use platform_name column in CSV</SelectItem>
                  {paList.map(pa => (
                    <SelectItem key={pa.id} value={String(pa.id)}>
                      {pa.nickname} <span className="text-muted-foreground">({pa.platform.short_name})</span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                If set, every row will use this platform account regardless of the CSV column.
              </p>
            </div>

            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox" className="mt-0.5"
                checked={config.autoCreatePlatforms}
                onChange={e => setConfig({ ...config, autoCreatePlatforms: e.target.checked })}
              />
              <div>
                <p className="text-sm font-medium">Auto-create missing platform accounts</p>
                <p className="text-xs text-muted-foreground">
                  Unmatched platform names will create a new Platform Account linked to the closest matching Platform (or "Direct" as fallback).
                </p>
              </div>
            </label>

            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox" className="mt-0.5"
                checked={config.matchTransactions}
                onChange={e => setConfig({ ...config, matchTransactions: e.target.checked })}
              />
              <div>
                <p className="text-sm font-medium">Match existing bank transactions</p>
                <p className="text-xs text-muted-foreground">
                  Links debit transactions to the imported instrument when amount and date (± 3 days) match.
                </p>
              </div>
            </label>
          </>
        )}

        {importType === 'transactions' && (
          <>
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium">
                Default Linked Account <span className="text-muted-foreground font-normal">(optional)</span>
              </label>
              <Select
                value={config.defaultLinkedAccountId}
                onValueChange={v => setConfig({ ...config, defaultLinkedAccountId: v })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Use linked_account_nickname column in CSV" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">Use linked_account_nickname column in CSV</SelectItem>
                  {acctList.filter(a => !a.closed_date).map(a => (
                    <SelectItem key={a.id} value={String(a.id)}>
                      {a.nickname} <span className="text-muted-foreground">({a.bank.short_name})</span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                If set, every transaction will be linked to this account and its balance will be updated automatically.
              </p>
            </div>
            <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-xs text-amber-800">
              Balance updates happen per-row via the same logic as manual entry — credits add, debits subtract.
              Ensure your data is accurate before importing.
            </div>
          </>
        )}

        {importType === 'term_accounts' && (
          <div className="rounded-lg border p-4 text-sm text-muted-foreground space-y-2">
            <p className="font-medium text-foreground">How term account import works</p>
            <ul className="list-disc list-inside space-y-1 text-xs">
              <li><strong>parent_account_nickname</strong> must match an existing account (exact, case-insensitive)</li>
              <li>FD maturity date and amount are auto-calculated if not provided</li>
              <li>PPF maturity date defaults to open_date + 15 years if not provided</li>
              <li>Account number is auto-generated if left blank</li>
            </ul>
          </div>
        )}
      </div>

      <div className="border-t px-6 py-4 flex justify-between shrink-0">
        <Button variant="outline" onClick={onBack}>← Back</Button>
        <Button onClick={onNext}>Next →</Button>
      </div>
    </div>
  )
}

// ── Step 3: Template download ─────────────────────────────────────────────────
function StepTemplate({ importType, onBack, onNext }: { importType: ImportType; onBack: () => void; onNext: () => void }) {
  const cols = COLUMN_REFS[importType]
  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-4">
        <Button variant="outline" className="self-start gap-2" onClick={() => downloadTemplate(importType)}>
          <Download size={14} /> Download sample CSV
        </Button>

        <div className="rounded-lg border overflow-hidden text-xs">
          <table className="w-full border-collapse">
            <thead>
              <tr className="bg-muted">
                <th className="text-left px-3 py-2 font-semibold">Column</th>
                <th className="text-left px-3 py-2 font-semibold">Required</th>
                <th className="text-left px-3 py-2 font-semibold hidden sm:table-cell">Format</th>
                <th className="text-left px-3 py-2 font-semibold hidden sm:table-cell">Example</th>
              </tr>
            </thead>
            <tbody>
              {cols.map(({ col, req, fmt, ex }) => (
                <tr key={col} className="border-t">
                  <td className="px-3 py-1.5 font-mono">{col}</td>
                  <td className="px-3 py-1.5">
                    {req
                      ? <span className="text-orange-600 font-semibold">Yes</span>
                      : <span className="text-muted-foreground">No</span>}
                  </td>
                  <td className="px-3 py-1.5 text-muted-foreground hidden sm:table-cell">{fmt}</td>
                  <td className="px-3 py-1.5 font-mono text-muted-foreground hidden sm:table-cell">{ex}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="border-t px-6 py-4 flex justify-between shrink-0">
        <Button variant="outline" onClick={onBack}>← Back</Button>
        <Button onClick={onNext}>Next →</Button>
      </div>
    </div>
  )
}

// ── Step 4: Upload ─────────────────────────────────────────────────────────────
function StepUpload({
  file, setFile, onBack, onNext,
}: {
  file:    File | null
  setFile: (f: File | null) => void
  onBack:  () => void
  onNext:  () => void
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [preview, setPreview] = useState<string[][]>([])
  const [headers, setHeaders] = useState<string[]>([])
  const [dragging, setDragging] = useState(false)

  function handleFile(f: File) {
    if (!f.name.endsWith('.csv') && !f.type.includes('csv')) return
    if (f.size > 5 * 1024 * 1024) return
    setFile(f)
    const reader = new FileReader()
    reader.onload = e => {
      const text  = e.target?.result as string
      const lines = text.split('\n').filter(Boolean)
      const hdrs  = lines[0]?.split(',').map(h => h.replace(/"/g, '').trim()) ?? []
      const rows  = lines.slice(1, 6).map(l => l.split(',').map(c => c.replace(/"/g, '').trim()))
      setHeaders(hdrs)
      setPreview(rows)
    }
    reader.readAsText(f)
  }

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-4">
        <div
          className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors
            ${dragging ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'}`}
          onClick={() => inputRef.current?.click()}
          onDragOver={e => { e.preventDefault(); setDragging(true) }}
          onDragLeave={() => setDragging(false)}
          onDrop={e => { e.preventDefault(); setDragging(false); const f = e.dataTransfer.files[0]; if (f) handleFile(f) }}
        >
          <Upload size={24} className="mx-auto mb-2 text-muted-foreground" />
          <p className="text-sm font-medium">Drag &amp; drop CSV here or click to browse</p>
          <p className="text-xs text-muted-foreground mt-1">CSV only · max 5 MB</p>
          <input
            ref={inputRef} type="file" accept=".csv,text/csv" className="hidden"
            onChange={e => { const f = e.target.files?.[0]; if (f) handleFile(f) }}
          />
        </div>

        {file && (
          <div className="flex items-center gap-2 text-sm text-green-700">
            <CheckCircle2 size={14} />
            <span className="font-medium">{file.name}</span>
            <span className="text-muted-foreground">({(file.size / 1024).toFixed(1)} KB)</span>
          </div>
        )}

        {headers.length > 0 && (
          <div>
            <p className="text-xs font-semibold text-muted-foreground mb-1.5">Preview (first 5 rows)</p>
            <div className="overflow-x-auto rounded border">
              <table className="text-xs w-full border-collapse">
                <thead>
                  <tr className="bg-muted">
                    {headers.slice(0, 6).map(h => (
                      <th key={h} className="px-2 py-1.5 text-left font-semibold border-r last:border-r-0 whitespace-nowrap">{h}</th>
                    ))}
                    {headers.length > 6 && <th className="px-2 py-1.5 text-muted-foreground">+{headers.length - 6} more</th>}
                  </tr>
                </thead>
                <tbody>
                  {preview.map((row, i) => (
                    <tr key={i} className="border-t">
                      {row.slice(0, 6).map((cell, j) => (
                        <td key={j} className="px-2 py-1.5 border-r last:border-r-0 max-w-[120px] truncate font-mono">{cell}</td>
                      ))}
                      {row.length > 6 && <td className="px-2 py-1.5 text-muted-foreground">…</td>}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>

      <div className="border-t px-6 py-4 flex justify-between shrink-0">
        <Button variant="outline" onClick={onBack}>← Back</Button>
        <Button onClick={onNext} disabled={!file}>Import Now →</Button>
      </div>
    </div>
  )
}

// ── Step 5: Processing ─────────────────────────────────────────────────────────
function StepProcessing({
  importType, file, onDone,
}: {
  importType: ImportType
  file:       File
  onDone:     () => void
}) {
  const createMutation = useCreateImport()
  const [batchId, setBatchId] = useState<number | null>(null)
  const [started, setStarted] = useState(false)
  const { data: batch } = useImport(batchId)

  useEffect(() => {
    if (started) return
    setStarted(true)
    createMutation.mutateAsync({ importType, file })
      .then(b => setBatchId(b.id))
      .catch(() => {})
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const status       = batch?.status ?? 'pending'
  const pct          = batch?.progress_pct ?? 0
  const isProcessing = status === 'pending' || status === 'processing'
  const isDone       = status === 'completed' || status === 'failed'
  const errors       = batch?.import_records.filter(r => r.status === 'error') ?? []

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-5">
        <div className="flex items-center gap-3">
          {isProcessing && <div className="w-4 h-4 rounded-full border-2 border-primary border-t-transparent animate-spin" />}
          {status === 'completed' && <CheckCircle2 size={18} className="text-green-600" />}
          {status === 'failed'    && <XCircle      size={18} className="text-red-500" />}
          <div>
            <p className="font-semibold text-sm capitalize">{status === 'pending' ? 'Starting…' : status}</p>
            {batch && <p className="text-xs text-muted-foreground">{batch.file_name} · v{batch.import_version}</p>}
          </div>
        </div>

        <div>
          <div className="flex justify-between text-xs text-muted-foreground mb-1">
            <span>
              {isProcessing
                ? `Processing row ${batch?.processed_rows ?? 0} of ${batch?.total_rows ?? '…'}`
                : `${batch?.processed_rows ?? 0} of ${batch?.total_rows ?? 0} rows processed`}
            </span>
            <span>{pct}%</span>
          </div>
          <div className="h-2 rounded-full bg-muted overflow-hidden">
            <div
              className={`h-full rounded-full transition-all duration-500 ${status === 'failed' ? 'bg-red-500' : 'bg-primary'}`}
              style={{ width: `${pct}%` }}
            />
          </div>
        </div>

        {isDone && batch && (
          <div className="rounded-lg border p-4 flex flex-col gap-1.5 text-sm">
            <div className="flex items-center gap-2 text-green-700">
              <CheckCircle2 size={14} />
              <span><strong>{batch.processed_rows - batch.failed_rows}</strong> rows imported successfully</span>
            </div>
            {batch.failed_rows > 0 && (
              <div className="flex items-center gap-2 text-red-600">
                <XCircle size={14} />
                <span><strong>{batch.failed_rows}</strong> rows failed</span>
              </div>
            )}
          </div>
        )}

        {errors.length > 0 && (
          <div className="flex flex-col gap-2">
            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Errors</p>
            <div className="rounded-lg border divide-y text-xs max-h-48 overflow-y-auto">
              {errors.map(r => (
                <div key={r.row_index} className="px-3 py-2 flex gap-3">
                  <span className="text-muted-foreground shrink-0">Row {r.row_index + 2}</span>
                  <span className="text-red-600">{r.notes}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="border-t px-6 py-4 flex justify-end shrink-0">
        <Button onClick={onDone} disabled={isProcessing}>Done ✓</Button>
      </div>
    </div>
  )
}

// ── Main wizard ───────────────────────────────────────────────────────────────
interface Props {
  open:    boolean
  onClose: () => void
}

const DEFAULT_CONFIG: ImportConfig = {
  defaultPlatformAccountId: '',
  autoCreatePlatforms:      true,
  matchTransactions:        true,
  defaultLinkedAccountId:   '',
}

export function ImportWizard({ open, onClose }: Props) {
  const [step, setStep]             = useState(1)
  const [importType, setImportType] = useState<ImportType>('investments')
  const [config, setConfig]         = useState<ImportConfig>(DEFAULT_CONFIG)
  const [file, setFile]             = useState<File | null>(null)
  const qc                          = useQueryClient()

  function reset() {
    setStep(1)
    setImportType('investments')
    setConfig(DEFAULT_CONFIG)
    setFile(null)
  }

  function handleClose() { reset(); onClose() }
  function handleDone()  { qc.invalidateQueries({ queryKey: ['imports'] }); handleClose() }

  return (
    <Sheet open={open} onOpenChange={v => !v && handleClose()}>
      <SheetContent side="right" className="flex flex-col p-0 overflow-hidden" style={{ width: '50vw', maxWidth: 'none' }}>
        <SheetHeader className="border-b px-6 py-4 shrink-0">
          <SheetTitle className="text-base">New Import</SheetTitle>
        </SheetHeader>

        <StepIndicator current={step} />

        {step === 1 && (
          <StepSelectType onNext={t => { setImportType(t); setStep(2) }} />
        )}
        {step === 2 && (
          <StepContext
            importType={importType}
            config={config} setConfig={setConfig}
            onBack={() => setStep(1)} onNext={() => setStep(3)}
          />
        )}
        {step === 3 && (
          <StepTemplate
            importType={importType}
            onBack={() => setStep(2)} onNext={() => setStep(4)}
          />
        )}
        {step === 4 && (
          <StepUpload
            file={file} setFile={setFile}
            onBack={() => setStep(3)} onNext={() => setStep(5)}
          />
        )}
        {step === 5 && file && (
          <StepProcessing importType={importType} file={file} onDone={handleDone} />
        )}
      </SheetContent>
    </Sheet>
  )
}
