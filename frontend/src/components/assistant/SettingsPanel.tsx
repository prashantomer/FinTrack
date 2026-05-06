import { useMemo, useState } from 'react'
import { AlertCircle, Check, ChevronDown, ChevronUp, KeyRound, Loader2, RefreshCw, Sparkles } from 'lucide-react'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useAssistantSettings } from '@/hooks/useAssistantSettings'
import type { AssistantProvider, AssistantSetting, AssistantSettingUpdate, AssistantTestResult } from '@/api/assistant'
import { getErrorMessage } from '@/lib/errors'

const PROVIDER_OPTIONS: Array<{ value: AssistantProvider; label: string; hint: string }> = [
  { value: 'anthropic', label: 'Anthropic Claude', hint: 'Claude Sonnet / Haiku · best tool-use' },
  { value: 'openai',    label: 'OpenAI',           hint: 'GPT-4o / GPT-4o-mini' },
  { value: 'ollama',    label: 'Ollama (local)',   hint: 'No API key · runs at localhost' },
]

const DEFAULT_MODEL: Record<AssistantProvider, string> = {
  anthropic: 'claude-sonnet-4-6',
  openai:    'gpt-4o-mini',
  ollama:    'gemma4:e4b',
}

const DEFAULT_BASE_URL: Record<AssistantProvider, string> = {
  anthropic: 'https://api.anthropic.com',
  openai:    'https://api.openai.com/v1',
  ollama:    'http://localhost:11434',
}

interface FormState {
  provider: AssistantProvider
  model: string
  base_url: string
  api_key: string             // only set when user is replacing
  replacing_key: boolean
  daily_limit: number
}

function initialForm(setting: AssistantSetting): FormState {
  const provider = (setting.provider ?? setting.effective_provider) as AssistantProvider
  return {
    provider,
    model:    setting.model ?? DEFAULT_MODEL[provider],
    base_url: setting.base_url ?? DEFAULT_BASE_URL[provider],
    api_key:  '',
    replacing_key: !setting.has_api_key,
    daily_limit: setting.daily_limit,
  }
}

export function SettingsPanel() {
  const { setting, isLoading, update, isUpdating, test, isTesting } = useAssistantSettings()

  if (isLoading || !setting) {
    return (
      <Card size="sm" className="shrink-0">
        <CardContent className="flex items-center gap-2 text-sm text-muted-foreground py-3 px-4">
          <Loader2 size={14} className="animate-spin" /> Loading provider settings…
        </CardContent>
      </Card>
    )
  }

  return <SettingsPanelInner setting={setting} update={update} isUpdating={isUpdating} test={test} isTesting={isTesting} />
}

interface InnerProps {
  setting: AssistantSetting
  update: (payload: AssistantSettingUpdate) => Promise<AssistantSetting>
  isUpdating: boolean
  test: (payload?: AssistantSettingUpdate) => Promise<AssistantTestResult>
  isTesting: boolean
}

function SettingsPanelInner({ setting, update, isUpdating, test, isTesting }: InnerProps) {
  const [expanded, setExpanded] = useState(!setting.configured)
  const [form, setForm] = useState<FormState>(() => initialForm(setting))
  const [testResult, setTestResult] = useState<AssistantTestResult | null>(null)

  const dirty = useMemo(() => (
    form.provider !== (setting.provider ?? setting.effective_provider) ||
    form.model !== (setting.model ?? DEFAULT_MODEL[form.provider]) ||
    form.base_url !== (setting.base_url ?? DEFAULT_BASE_URL[form.provider]) ||
    form.daily_limit !== setting.daily_limit ||
    (form.replacing_key && form.api_key.length > 0)
  ), [setting, form])

  function expand() {
    setForm(initialForm(setting))
    setTestResult(null)
    setExpanded(true)
  }

  if (!expanded) {
    return <CollapsedBanner setting={setting} onExpand={expand} />
  }

  function changeProvider(provider: AssistantProvider) {
    setForm(f => ({
      ...f,
      provider,
      model: DEFAULT_MODEL[provider],
      base_url: DEFAULT_BASE_URL[provider],
      replacing_key: provider === 'ollama' ? false : !setting.has_api_key || f.replacing_key,
      api_key: provider === 'ollama' ? '' : f.api_key,
    }))
    setTestResult(null)
  }

  function buildPayload(): AssistantSettingUpdate {
    const payload: AssistantSettingUpdate = {
      provider:    form.provider,
      model:       form.model.trim() || DEFAULT_MODEL[form.provider],
      base_url:    form.base_url.trim() || DEFAULT_BASE_URL[form.provider],
      daily_limit: form.daily_limit,
    }
    if (form.replacing_key && form.api_key) payload.api_key = form.api_key
    return payload
  }

  async function handleTest() {
    setTestResult(null)
    try {
      const result = await test(buildPayload())
      setTestResult(result)
    } catch (err) {
      toast.error(getErrorMessage(err))
    }
  }

  async function handleSave() {
    try {
      await update(buildPayload())
      toast.success('Provider settings saved')
      setExpanded(false)
      setForm(prev => ({ ...prev, api_key: '', replacing_key: false }))
      setTestResult(null)
    } catch (err) {
      toast.error(getErrorMessage(err))
    }
  }

  const requiresKey = form.provider !== 'ollama'

  return (
    <Card size="sm" className="shrink-0">
      <CardHeader className="flex flex-row items-center justify-between pb-1">
        <CardTitle className="text-sm flex items-center gap-2">
          <Sparkles size={14} className="text-muted-foreground" />
          AI Provider Settings
        </CardTitle>
        <Button variant="ghost" size="sm" onClick={() => setExpanded(false)} className="h-7 px-2">
          <ChevronUp size={14} /> Collapse
        </Button>
      </CardHeader>

      <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
        {!setting.configured && (
          <div className="md:col-span-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">
            <strong>No provider configured.</strong> The assistant will use a local Ollama server (<code>http://localhost:11434</code>) if one is running. Configure a hosted provider for better tool-use quality.
          </div>
        )}

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs">Provider</Label>
          <Select value={form.provider} onValueChange={(v) => changeProvider(v as AssistantProvider)}>
            <SelectTrigger className="h-9"><SelectValue /></SelectTrigger>
            <SelectContent>
              {PROVIDER_OPTIONS.map(opt => (
                <SelectItem key={opt.value} value={opt.value}>
                  <div className="flex flex-col">
                    <span className="font-medium">{opt.label}</span>
                    <span className="text-xs text-muted-foreground">{opt.hint}</span>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs">Model</Label>
          <Input
            value={form.model}
            onChange={(e) => setForm(f => ({ ...f, model: e.target.value }))}
            placeholder={DEFAULT_MODEL[form.provider]}
          />
        </div>

        {requiresKey && (
          <div className="flex flex-col gap-1.5 md:col-span-2">
            <Label className="text-xs flex items-center gap-1.5">
              <KeyRound size={11} /> API Key
            </Label>
            {form.replacing_key ? (
              <div className="flex gap-2">
                <Input
                  type="password"
                  value={form.api_key}
                  onChange={(e) => setForm(f => ({ ...f, api_key: e.target.value }))}
                  placeholder="Paste your API key"
                  autoComplete="off"
                />
                {setting.has_api_key && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setForm(f => ({ ...f, replacing_key: false, api_key: '' }))}
                  >
                    Cancel
                  </Button>
                )}
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <code className="flex-1 px-3 py-2 bg-muted rounded-md text-sm font-mono">
                  {setting.api_key_tail ?? '(not set)'}
                </code>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setForm(f => ({ ...f, replacing_key: true }))}
                >
                  Replace
                </Button>
              </div>
            )}
          </div>
        )}

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs">Base URL</Label>
          <Input
            value={form.base_url}
            onChange={(e) => setForm(f => ({ ...f, base_url: e.target.value }))}
            placeholder={DEFAULT_BASE_URL[form.provider]}
          />
        </div>

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs">Daily message limit</Label>
          <Input
            type="number"
            min={1}
            value={form.daily_limit}
            onChange={(e) => setForm(f => ({ ...f, daily_limit: Number(e.target.value) || 1 }))}
          />
        </div>

        {testResult && (
          <div className={`md:col-span-2 rounded-md border px-3 py-2 text-xs flex items-start gap-2 ${
            testResult.ok
              ? 'border-green-200 bg-green-50 text-green-900'
              : 'border-red-200 bg-red-50 text-red-900'
          }`}>
            {testResult.ok ? <Check size={14} className="mt-0.5 shrink-0" /> : <AlertCircle size={14} className="mt-0.5 shrink-0" />}
            <div className="flex-1">
              {testResult.ok ? (
                <span>Connected · latency {testResult.latency_ms}ms</span>
              ) : (
                <span>{testResult.error_class}: {testResult.message}</span>
              )}
            </div>
          </div>
        )}

        <div className="md:col-span-2 flex items-center justify-between gap-2 pt-1">
          <StatusBadge setting={setting} />
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={handleTest} disabled={isTesting || (requiresKey && !form.api_key && !setting.has_api_key)}>
              {isTesting ? <Loader2 size={12} className="animate-spin" /> : <RefreshCw size={12} />}
              Test connection
            </Button>
            <Button size="sm" onClick={handleSave} disabled={isUpdating || !dirty}>
              {isUpdating ? <Loader2 size={12} className="animate-spin" /> : null}
              Save
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function CollapsedBanner({ setting, onExpand }: { setting: AssistantSetting; onExpand: () => void }) {
  const status = setting.last_test_status
  const dotColor = status === 'ok' ? 'bg-green-500' : status === 'error' ? 'bg-red-500' : 'bg-zinc-300'
  const statusLabel = status === 'ok' ? 'ready' : status === 'error' ? 'error' : 'untested'

  return (
    <Card size="sm" className="shrink-0">
      <CardContent className="flex items-center justify-between gap-3 py-2.5 px-4">
        <div className="flex items-center gap-2 min-w-0 text-sm">
          <Sparkles size={14} className="text-muted-foreground shrink-0" />
          <span className="font-medium">AI Provider</span>
          <span className="text-muted-foreground">·</span>
          <span className="text-muted-foreground">{setting.effective_provider}</span>
          <span className="text-muted-foreground">·</span>
          <span className="font-mono text-xs text-muted-foreground truncate">{setting.effective_model}</span>
          <Badge variant="outline" className="ml-1 gap-1.5">
            <span className={`w-1.5 h-1.5 rounded-full ${dotColor}`} />
            {statusLabel}
          </Badge>
        </div>
        <Button variant="ghost" size="sm" onClick={onExpand} className="h-7 px-2">
          Edit <ChevronDown size={14} />
        </Button>
      </CardContent>
    </Card>
  )
}

function StatusBadge({ setting }: { setting: AssistantSetting }) {
  if (!setting.last_tested_at) {
    return <span className="text-xs text-muted-foreground">Not yet tested</span>
  }
  const ok = setting.last_test_status === 'ok'
  return (
    <span className={`text-xs flex items-center gap-1.5 ${ok ? 'text-green-700' : 'text-red-700'}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${ok ? 'bg-green-500' : 'bg-red-500'}`} />
      {ok ? 'Connected' : 'Last test failed'} · {timeAgo(setting.last_tested_at)}
    </span>
  )
}

function timeAgo(iso: string): string {
  const secs = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (secs < 60) return `${secs}s ago`
  const mins = Math.floor(secs / 60)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}
