import { useEffect, useRef } from 'react'
import { MessageBubble, ToolGroupBubble } from './MessageBubble'
import type { AssistantMessage } from '@/api/assistant'

type Tile =
  | { kind: 'message'; message: AssistantMessage }
  | { kind: 'tools'; messages: AssistantMessage[] }

function buildTiles(items: AssistantMessage[]): Tile[] {
  const tiles: Tile[] = []
  for (const m of items) {
    if (m.role === 'tool') {
      const last = tiles[tiles.length - 1]
      if (last && last.kind === 'tools') last.messages.push(m)
      else tiles.push({ kind: 'tools', messages: [m] })
    } else {
      tiles.push({ kind: 'message', message: m })
    }
  }
  return tiles
}

interface Props {
  messages: AssistantMessage[]
  isThinking?: boolean
  onPin?: (id: number) => void
  onUnpin?: (id: number) => void
  onReference?: (id: number) => void
  referencedIds?: Set<number>
}

export function MessageList({ messages, isThinking, onPin, onUnpin, onReference, referencedIds }: Props) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    ref.current?.scrollTo({ top: ref.current.scrollHeight, behavior: 'smooth' })
  }, [messages.length, isThinking])

  if (messages.length === 0 && !isThinking) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="text-center text-muted-foreground max-w-md text-sm space-y-2">
          <p className="font-medium">Ask anything about your finances.</p>
          <p>Try: <em>"How much did I spend on groceries last week?"</em>, <em>"List all my fixed deposits"</em>, or attach a broker CSV and ask <em>"convert this to investments import"</em>.</p>
        </div>
      </div>
    )
  }

  // Group messages by session_id with a divider between sessions
  const groups: { session_id: string; items: AssistantMessage[] }[] = []
  for (const m of messages) {
    const last = groups[groups.length - 1]
    if (last && last.session_id === m.session_id) last.items.push(m)
    else groups.push({ session_id: m.session_id, items: [m] })
  }

  return (
    <div ref={ref} className="flex-1 overflow-y-auto px-2 py-3 flex flex-col gap-3">
      {groups.map((g, i) => (
        <div key={g.session_id} className="flex flex-col gap-3">
          {i > 0 && (
            <div className="flex items-center gap-2 text-[10px] uppercase tracking-wide text-muted-foreground my-2">
              <div className="flex-1 border-t" />
              <span>new session</span>
              <div className="flex-1 border-t" />
            </div>
          )}
          {buildTiles(g.items).map(tile => {
            if (tile.kind === 'tools') {
              return <ToolGroupBubble key={`tools-${tile.messages[0].id}`} messages={tile.messages} />
            }
            const m = tile.message
            return (
              <MessageBubble
                key={m.id}
                message={m}
                onPin={onPin}
                onUnpin={onUnpin}
                onReference={onReference}
                isReferenced={referencedIds?.has(m.id)}
              />
            )
          })}
        </div>
      ))}
      {isThinking && (
        <div className="self-start text-xs text-muted-foreground italic px-2 py-1">Thinking…</div>
      )}
    </div>
  )
}
