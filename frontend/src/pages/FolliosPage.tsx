import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useCreateFollio, useDeleteFollio, useFollios, useUpdateFollio } from '@/hooks/useFollios'
import { useTrackedInstruments } from '@/hooks/useInstruments'
import { usePlatformAccounts } from '@/hooks/usePlatforms'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { Follio } from '@/types'

interface FormState {
  follio_id: string
  platform_id: string
  instrument_id: string
}

const DEFAULT_FORM: FormState = { follio_id: '', platform_id: '', instrument_id: '' }

export function FolliosPage() {
  const { data: follios = [], isLoading } = useFollios()
  const { data: platformAccounts = [] } = usePlatformAccounts()
  const { data: instruments = [] } = useTrackedInstruments()

  const createMutation = useCreateFollio()
  const updateMutation = useUpdateFollio()
  const deleteMutation = useDeleteFollio()

  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Follio | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)

  // Deduplicate platforms from platform accounts
  const platformMap = new Map(platformAccounts.map(pa => [pa.platform_id, pa.platform]))
  const platforms = [...platformMap.values()]

  function openCreate() {
    setEditing(null)
    setForm(DEFAULT_FORM)
    setOpen(true)
  }

  function openEdit(f: Follio) {
    setEditing(f)
    setForm({ follio_id: f.follio_id, platform_id: f.platform_id.toString(), instrument_id: f.instrument_id.toString() })
    setOpen(true)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (editing) {
      await updateMutation.mutateAsync({ id: editing.id, data: { follio_id: form.follio_id } })
    } else {
      await createMutation.mutateAsync({
        follio_id: form.follio_id,
        platform_id: Number(form.platform_id),
        instrument_id: Number(form.instrument_id),
      })
    }
    setOpen(false)
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Follios</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Position accounts linking your instruments to platforms</p>
        </div>
        <Button onClick={openCreate}><Plus size={16} className="mr-1" />Add Follio</Button>
      </div>

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
              <TableHead>Platform</TableHead>
              <TableHead>Since</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {follios.map(f => (
              <TableRow key={f.id}>
                <TableCell className="font-mono text-sm font-medium">{f.follio_id}</TableCell>
                <TableCell>{f.instrument.name}</TableCell>
                <TableCell>
                  <Badge variant="outline">{INVESTMENT_TYPE_LABELS[f.instrument.type]}</Badge>
                </TableCell>
                <TableCell className="text-muted-foreground">{f.platform.name}</TableCell>
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
                  No follios yet. Track an instrument first, then add a follio to link it to a platform.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
          </Table>
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{editing ? 'Edit Follio' : 'New Follio'}</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {!editing && (
              <>
                <div className="flex flex-col gap-1.5">
                  <Label>Platform</Label>
                  <Select value={form.platform_id} onValueChange={v => v && setForm(f => ({ ...f, platform_id: v }))}>
                    <SelectTrigger><SelectValue placeholder="Select platform…" /></SelectTrigger>
                    <SelectContent>
                      {platforms.map(p => (
                        <SelectItem key={p.id} value={p.id.toString()}>{p.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label>Instrument <span className="text-muted-foreground text-xs">(tracked only)</span></Label>
                  <Select value={form.instrument_id} onValueChange={v => v && setForm(f => ({ ...f, instrument_id: v }))}>
                    <SelectTrigger><SelectValue placeholder="Select instrument…" /></SelectTrigger>
                    <SelectContent>
                      {instruments.map(i => (
                        <SelectItem key={i.id} value={i.id.toString()}>
                          {i.name} <span className="text-muted-foreground">({INVESTMENT_TYPE_LABELS[i.type]})</span>
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
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
              <Button type="submit">{editing ? 'Update' : 'Create'}</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}
