import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { PageHeader } from '@/components/layout/PageHeader'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import {
  useCreatePlatformAccount,
  useDeletePlatformAccount,
  usePlatformAccounts,
  usePlatforms,
  useUpdatePlatformAccount,
} from '@/hooks/usePlatforms'
import { PLATFORM_TYPE_LABELS } from '@/lib/labels'
import type { PlatformAccount } from '@/types'

interface FormState {
  platform_id: string
  nickname: string
  account_id: string
}

const DEFAULT_FORM: FormState = { platform_id: '', nickname: '', account_id: '' }

export function PlatformAccountsPage() {
  const qc = useQueryClient()
  const { data: accounts = [], isLoading, isFetching } = usePlatformAccounts()
  const { data: platforms = [] } = usePlatforms()
  const createMutation = useCreatePlatformAccount()
  const updateMutation = useUpdatePlatformAccount()
  const deleteMutation = useDeletePlatformAccount()

  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<PlatformAccount | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)

  function openCreate() {
    setEditing(null)
    setForm(DEFAULT_FORM)
    setOpen(true)
  }

  function openEdit(a: PlatformAccount) {
    setEditing(a)
    setForm({
      platform_id: a.platform_id.toString(),
      nickname: a.nickname,
      account_id: a.account_id ?? '',
    })
    setOpen(true)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const payload = {
      platform_id: Number(form.platform_id),
      nickname: form.nickname,
      account_id: form.account_id || undefined,
    }
    if (editing) {
      await updateMutation.mutateAsync({ id: editing.id, data: payload })
    } else {
      await createMutation.mutateAsync(payload)
    }
    setOpen(false)
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Platform Accounts"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['platform-accounts'] })}
        isRefreshing={isFetching}
      >
        <Button onClick={openCreate}><Plus size={16} className="mr-1" />Add Account</Button>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-6">
        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="rounded-lg border overflow-hidden">
            <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nickname</TableHead>
                <TableHead>Platform</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Account ID</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {accounts.map(a => (
                <TableRow key={a.id}>
                  <TableCell className="font-medium">{a.nickname}</TableCell>
                  <TableCell>{a.platform.name} <span className="text-muted-foreground text-xs">({a.platform.short_name})</span></TableCell>
                  <TableCell><Badge variant="outline">{PLATFORM_TYPE_LABELS[a.platform.type]}</Badge></TableCell>
                  <TableCell className="text-muted-foreground font-mono text-sm">{a.account_id || '—'}</TableCell>
                  <TableCell className="flex gap-1 justify-end">
                    <Button size="icon" variant="ghost" onClick={() => openEdit(a)}><Pencil size={14} /></Button>
                    <Button size="icon" variant="ghost" onClick={() => deleteMutation.mutate(a.id)}><Trash2 size={14} /></Button>
                  </TableCell>
                </TableRow>
              ))}
              {accounts.length === 0 && (
                <TableRow><TableCell colSpan={5} className="text-center text-muted-foreground py-8">No platform accounts yet</TableCell></TableRow>
              )}
            </TableBody>
            </Table>
          </div>
        )}
      </div>

      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="right" className="w-[400px] sm:max-w-[420px] flex flex-col p-0 overflow-hidden">
          <SheetHeader className="border-b px-6 py-5 shrink-0">
            <SheetTitle className="text-base">{editing ? 'Edit Platform Account' : 'New Platform Account'}</SheetTitle>
          </SheetHeader>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">
              <div className="flex flex-col gap-1.5">
                <Label>Platform</Label>
                <Select value={form.platform_id} onValueChange={(v) => v && setForm(f => ({ ...f, platform_id: v }))}>
                  <SelectTrigger><SelectValue placeholder="Select platform…" /></SelectTrigger>
                  <SelectContent>
                    {platforms.map(p => (
                      <SelectItem key={p.id} value={p.id.toString()}>
                        {p.name} <span className="text-muted-foreground">({PLATFORM_TYPE_LABELS[p.type]})</span>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="flex flex-col gap-1.5">
                <Label>Nickname</Label>
                <Input value={form.nickname} onChange={e => setForm(f => ({ ...f, nickname: e.target.value }))} required />
              </div>
              <div className="flex flex-col gap-1.5">
                <Label>Account ID / Client ID <span className="text-muted-foreground text-xs">(optional)</span></Label>
                <Input value={form.account_id} onChange={e => setForm(f => ({ ...f, account_id: e.target.value }))} />
              </div>
            </div>
            <div className="border-t px-6 py-4 flex justify-end gap-2 shrink-0">
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
              <Button type="submit">{editing ? 'Update' : 'Create'}</Button>
            </div>
          </form>
        </SheetContent>
      </Sheet>
    </div>
  )
}
