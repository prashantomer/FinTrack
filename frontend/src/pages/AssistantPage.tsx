import { useRef, useState } from 'react'
import { Eraser, FileUp, RefreshCw, Sparkles } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { PageHeader } from '@/components/layout/PageHeader'
import { MessageInput } from '@/components/assistant/MessageInput'
import { MessageList } from '@/components/assistant/MessageList'
import { SettingsPanel } from '@/components/assistant/SettingsPanel'
import { useAssistantChat } from '@/hooks/useAssistantChat'
import { getErrorMessage } from '@/lib/errors'
import type { AssistantAttachment } from '@/api/assistant'

const ACCEPTED_DROP_TYPES = ['text/csv', 'application/csv', 'text/plain']

export function AssistantPage() {
  const qc = useQueryClient()
  const { messages, isLoading, send, isSending, upload, isUploading, newSession, clear, pin, unpin } = useAssistantChat()
  const [sessionId, setSessionId] = useState<string | undefined>(undefined)
  const [referencedIds, setReferencedIds] = useState<number[]>([])
  const [pendingAttachment, setPendingAttachment] = useState<AssistantAttachment | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const dragCounter = useRef(0)

  function toggleReference(id: number) {
    setReferencedIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id])
  }
  function removeReference(id: number) {
    setReferencedIds(prev => prev.filter(x => x !== id))
  }

  async function handleSend(content: string, attachmentId?: number, refIds?: number[]) {
    try {
      const result = await send({
        content,
        attachment_id: attachmentId,
        session_id: sessionId,
        reference_ids: refIds && refIds.length > 0 ? refIds : undefined,
      })
      setSessionId(result.session_id)
      setReferencedIds([])
      setPendingAttachment(null)
    } catch (err) {
      toast.error(getErrorMessage(err))
    }
  }

  async function handleNewSession() {
    const id = await newSession()
    setSessionId(id)
    toast.success('Started a new session — older context is now archived.')
  }

  async function handleClear() {
    if (!confirm('Delete all assistant chat history? This cannot be undone.')) return
    await clear()
    setSessionId(undefined)
    setPendingAttachment(null)
  }

  function isFileDrag(e: React.DragEvent) {
    return Array.from(e.dataTransfer.types).includes('Files')
  }

  function onDragEnter(e: React.DragEvent) {
    if (!isFileDrag(e)) return
    e.preventDefault()
    dragCounter.current += 1
    setIsDragging(true)
  }
  function onDragOver(e: React.DragEvent) {
    if (!isFileDrag(e)) return
    e.preventDefault()
  }
  function onDragLeave(e: React.DragEvent) {
    if (!isFileDrag(e)) return
    e.preventDefault()
    dragCounter.current = Math.max(0, dragCounter.current - 1)
    if (dragCounter.current === 0) setIsDragging(false)
  }
  async function onDrop(e: React.DragEvent) {
    if (!isFileDrag(e)) return
    e.preventDefault()
    dragCounter.current = 0
    setIsDragging(false)

    const file = e.dataTransfer.files?.[0]
    if (!file) return
    if (file.type && !ACCEPTED_DROP_TYPES.includes(file.type) && !file.name.toLowerCase().endsWith('.csv')) {
      toast.error('Only CSV / text files are accepted.')
      return
    }
    try {
      const result = await upload(file)
      setPendingAttachment(result)
      toast.success(`Attached ${result.filename}`)
    } catch (err) {
      toast.error(getErrorMessage(err))
    }
  }

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Assistant"
        description="Ask about your finances or convert files for import"
        onRefresh={() => qc.invalidateQueries({ queryKey: ['assistant'] })}
      >
        <Button variant="outline" size="sm" onClick={handleNewSession} className="gap-1.5">
          <Sparkles size={14} /> New session
        </Button>
        <Button variant="outline" size="sm" onClick={handleClear} className="gap-1.5">
          <Eraser size={14} /> Clear history
        </Button>
      </PageHeader>

      <div className="flex-1 min-h-0 overflow-hidden flex flex-col gap-4 px-6 py-4">
        <SettingsPanel />

        <div
          className={`flex-1 min-h-0 flex flex-col rounded-lg border bg-background relative transition-colors ${
            isDragging ? 'border-primary border-2' : ''
          }`}
          onDragEnter={onDragEnter}
          onDragOver={onDragOver}
          onDragLeave={onDragLeave}
          onDrop={onDrop}
        >
          {isDragging && (
            <div className="absolute inset-0 z-10 rounded-lg bg-primary/10 backdrop-blur-[1px] border-2 border-dashed border-primary flex items-center justify-center pointer-events-none">
              <div className="flex flex-col items-center gap-2 text-primary">
                <FileUp size={32} />
                <span className="text-sm font-medium">Drop CSV to attach to next message</span>
              </div>
            </div>
          )}

          {isLoading ? (
            <div className="flex-1 flex items-center justify-center text-sm text-muted-foreground gap-2">
              <RefreshCw size={14} className="animate-spin" /> Loading conversation…
            </div>
          ) : (
            <MessageList
              messages={messages}
              isThinking={isSending}
              onPin={pin}
              onUnpin={unpin}
              onReference={toggleReference}
              referencedIds={new Set(referencedIds)}
            />
          )}
          <div className="border-t p-3 shrink-0">
            <MessageInput
              onSend={handleSend}
              onUpload={upload}
              isSending={isSending}
              isUploading={isUploading}
              referencedIds={referencedIds}
              onUnreference={removeReference}
              attachment={pendingAttachment}
              onAttachmentChange={setPendingAttachment}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
