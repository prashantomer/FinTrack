import { useState } from 'react'
import { ChevronLeft, ChevronRight, Pencil, Plus, Trash2 } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { PageHeader } from '@/components/layout/PageHeader'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useCreateFollio, useDeleteFollio, useFollios, useUpdateFollio } from '@/hooks/useFollios'
import { useUserInstruments } from '@/hooks/useInstruments'
import { usePlatformAccounts } from '@/hooks/usePlatforms'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Follio } from '@/types'

interface FormState {
  follio_id: string
  user_instrument_id: string
  platform_account_id: string
}

const DEFAULT_FORM: FormState = { follio_id: '', user_instrument_id: '', platform_account_id: '' }
const PAGE_SIZE = 20

export function FolliosPage() {
  const qc = useQueryClient()
  const [page, setPage] = useState(1)
  const { data, isLoading, isFetching } = useFollios(page, PAGE_SIZE)
  const follios = data?.items ?? []
  const total = data?.total ?? 0
  const { data: userInstruments = [] } = useUserInstruments()
  const { data: platformAccounts = [] } = usePlatformAccounts()

  const createMutation = useCreateFollio()
  const updateMutation = useUpdateFollio()
  const deleteMutation = useDeleteFollio()

  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Follio | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)

  function openCreate() {
    setEditing(null)
    setForm(DEFAULT_FORM)
    setOpen(true)
  }

  function openEdit(f: Follio) {
    setEditing(f)
    setForm({
      follio_id: f.follio_id,
      user_instrument_id: f.user_instrument_id.toString(),
      platform_account_id: f.platform_account_id.toString(),
    })
    setOpen(true)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (editing) {
      await updateMutation.mutateAsync({ id: editing.id, data: { follio_id: form.follio_id } })
    } else {
      await createMutation.mutateAsync({
        follio_id: form.follio_id,
        user_instrument_id: Number(form.user_instrument_id),
        platform_account_id: Number(form.platform_account_id),
      })
      setPage(1)
    }
    setOpen(false)
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Follios"
        description="Position accounts linking your tracked instruments to platform accounts"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['follios'] })}
        isRefreshing={isFetching}
      >
        <Button onClick={openCreate}><Plus size={16} className="mr-1" />Add Follio</Button>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-y-auto px-6 py-6 flex flex-col gap-6">
        {isLoading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : (
          <div className="rounded-lg border overflow-hidden">
            <Table>
            <TableHeader>
            <TableRow>
              <TableHead>Follio ID</TableHead>
              <TableHead>Instrument</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Platform Account</TableHead>
              <TableHead>Since</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {follios.map(f => (
              <TableRow key={f.id}>
                <TableCell className="font-mono text-sm font-medium">{f.follio_id}</TableCell>
                <TableCell>{f.user_instrument.instrument.name}</TableCell>
                <TableCell>
                  <Badge variant="outline">{INVESTMENT_TYPE_LABELS[f.user_instrument.instrument.type]}</Badge>
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {f.platform_account.nickname}
                  <span className="ml-1 text-xs">({f.platform_account.platform.short_name})</span>
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">{f.created_at.slice(0, 10)}</TableCell>
                <TableCell className="flex gap-1 justify-end">
                  <Button size="icon" variant="ghost" onClick={() => openEdit(f)}><Pencil size={14} /></Button>
                  <Button size="icon" variant="ghost" onClick={() => deleteMutation.mutate(f.id)}><Trash2 size={14} /></Button>
                </TableCell>
              </TableRow>
            ))}
            {follios.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                  No follios yet. Track an instrument first, then add a follio to link it to a platform account.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
          </Table>
        </div>
        )}

        {total > PAGE_SIZE && (
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">{total} total</span>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={() => setPage(p => p - 1)} disabled={page === 1}>
                <ChevronLeft size={14} />Prev
              </Button>
              <span className="text-muted-foreground px-1">Page {page}</span>
              <Button variant="outline" size="sm" onClick={() => setPage(p => p + 1)} disabled={follios.length < PAGE_SIZE}>
                Next<ChevronRight size={14} />
              </Button>
            </div>
          </div>
        )}
        {total > 0 && total <= PAGE_SIZE && (
          <p className="text-center text-xs text-muted-foreground py-1">{total} follios</p>
        )}
      </div>

      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="right" className="w-[400px] sm:max-w-[420px] flex flex-col p-0 overflow-hidden">
          <SheetHeader className="border-b px-6 py-5 shrink-0">
            <SheetTitle className="text-base">{editing ? 'Edit Follio' : 'New Follio'}</SheetTitle>
          </SheetHeader>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">
              {!editing && (
                <>
                  <div className="flex flex-col gap-1.5">
                    <Label>Instrument <span className="text-muted-foreground text-xs">(tracked only)</span></Label>
                    <Select
                      value={form.user_instrument_id}
                      onValueChange={v => v && setForm(f => ({ ...f, user_instrument_id: v }))}
                    >
                      <SelectTrigger><SelectValue placeholder="Select instrument…" /></SelectTrigger>
                      <SelectContent>
                        {userInstruments.map(ui => (
                          <SelectItem key={ui.id} value={ui.id.toString()}>
                            {ui.instrument.name}
                            <span className="ml-1 text-muted-foreground text-xs">
                              ({INVESTMENT_TYPE_LABELS[ui.instrument.type]})
                            </span>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col gap-1.5">
                    <Label>Platform Account</Label>
                    <Select
                      value={form.platform_account_id}
                      onValueChange={v => v && setForm(f => ({ ...f, platform_account_id: v }))}
                    >
                      <SelectTrigger><SelectValue placeholder="Select platform account…" /></SelectTrigger>
                      <SelectContent>
                        {platformAccounts.map(pa => (
                          <SelectItem key={pa.id} value={pa.id.toString()}>
                            {pa.nickname}
                            <span className="ml-1 text-muted-foreground text-xs">({pa.platform.short_name})</span>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </>
              )}
              <div className="flex flex-col gap-1.5">
                <Label>Follio / Reference ID</Label>
                <Input
                  value={form.follio_id}
                  onChange={e => setForm(f => ({ ...f, follio_id: e.target.value }))}
                  placeholder="e.g. 12345678 or ZER-RELIANCE-01"
                  required
                />
                <p className="text-xs text-muted-foreground">MF folio number, demat holding ref, or any unique identifier</p>
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
