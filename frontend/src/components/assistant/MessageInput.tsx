import { useRef, useState } from 'react'
import { AtSign, Loader2, Paperclip, Send, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import type { AssistantAttachment } from '@/api/assistant'

interface Props {
  onSend: (content: string, attachmentId?: number, referenceIds?: number[]) => Promise<void> | void
  onUpload: (file: File) => Promise<AssistantAttachment>
  isSending: boolean
  isUploading: boolean
  disabled?: boolean
  referencedIds?: number[]
  onUnreference?: (id: number) => void
}

export function MessageInput({ onSend, onUpload, isSending, isUploading, disabled, referencedIds = [], onUnreference }: Props) {
  const [text, setText] = useState('')
  const [attachment, setAttachment] = useState<AssistantAttachment | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    const result = await onUpload(file)
    setAttachment(result)
    e.target.value = ''
  }

  async function handleSend() {
    const content = text.trim()
    if (!content && !attachment) return
    await onSend(content, attachment?.attachment_id, referencedIds)
    setText('')
    setAttachment(null)
  }

  const canSend = (text.trim().length > 0 || attachment !== null) && !isSending && !disabled

  return (
    <div className="flex flex-col gap-2">
      {attachment && (
        <div className="flex items-center gap-2 px-3 py-1.5 bg-muted rounded-md text-xs w-fit">
          <Paperclip size={12} />
          <span className="font-mono truncate max-w-[280px]">{attachment.filename}</span>
          <span className="text-muted-foreground">({Math.round(attachment.byte_size / 1024)} KB)</span>
          <Button size="icon-xs" variant="ghost" className="h-5 w-5" onClick={() => setAttachment(null)}>
            <X size={11} />
          </Button>
        </div>
      )}
      {referencedIds.length > 0 && (
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-xs text-muted-foreground">Referencing:</span>
          {referencedIds.map(id => (
            <span key={id} className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-primary/10 text-primary text-xs">
              <AtSign size={10} /> #{id}
              {onUnreference && (
                <button onClick={() => onUnreference(id)} className="hover:text-primary/70" title="Remove reference">
                  <X size={10} />
                </button>
              )}
            </span>
          ))}
        </div>
      )}
      <div className="flex gap-2 items-end">
        <input ref={fileInput} type="file" accept=".csv,text/csv,text/plain" className="hidden" onChange={handleFile} />
        <Button
          variant="outline"
          size="icon-sm"
          onClick={() => fileInput.current?.click()}
          disabled={isUploading || disabled}
          title="Attach CSV"
        >
          {isUploading ? <Loader2 size={14} className="animate-spin" /> : <Paperclip size={14} />}
        </Button>
        <Textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && (e.metaKey || e.ctrlKey) && canSend) handleSend()
          }}
          placeholder="Ask about your data, or attach a CSV to convert…  (⌘/Ctrl + Enter to send)"
          rows={2}
          className="flex-1 resize-none min-h-[44px] max-h-40"
          disabled={disabled}
        />
        <Button onClick={handleSend} disabled={!canSend} size="sm" className="gap-1.5">
          {isSending ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
          Send
        </Button>
      </div>
    </div>
  )
}
