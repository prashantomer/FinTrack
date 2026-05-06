import { AtSign, Bot, Pin, PinOff, User as UserIcon, Wrench } from 'lucide-react'
import ReactMarkdown, { type Components } from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import type { AssistantMessage } from '@/api/assistant'

const MARKDOWN_COMPONENTS: Components = {
  table: (props) => (
    <div className="my-2 overflow-x-auto rounded-md border bg-background">
      <table className="w-full text-xs border-collapse" {...props} />
    </div>
  ),
  thead: (props) => <thead className="bg-muted/60" {...props} />,
  th: (props) => <th className="text-left px-2.5 py-1.5 font-medium border-b" {...props} />,
  td: (props) => <td className="px-2.5 py-1.5 border-b last:border-0 align-top font-mono" {...props} />,
  tr: (props) => <tr className="hover:bg-muted/30" {...props} />,
  code: ({ className, children, ...rest }) => {
    const isBlock = /language-/.test(className ?? '')
    if (isBlock) {
      return (
        <pre className="my-2 p-3 rounded-md bg-background border text-xs overflow-x-auto">
          <code className={className} {...rest}>{children}</code>
        </pre>
      )
    }
    return <code className="px-1 py-0.5 rounded bg-background/60 text-[0.85em] font-mono" {...rest}>{children}</code>
  },
  pre: (props) => <pre className="my-2 p-3 rounded-md bg-background border text-xs overflow-x-auto" {...props} />,
  ul:  (props) => <ul className="list-disc pl-5 my-1 space-y-0.5" {...props} />,
  ol:  (props) => <ol className="list-decimal pl-5 my-1 space-y-0.5" {...props} />,
  li:  (props) => <li className="leading-snug" {...props} />,
  p:   (props) => <p className="my-1.5 leading-relaxed" {...props} />,
  h1:  (props) => <h1 className="text-base font-semibold mt-3 mb-1" {...props} />,
  h2:  (props) => <h2 className="text-sm font-semibold mt-3 mb-1" {...props} />,
  h3:  (props) => <h3 className="text-sm font-medium mt-2 mb-1" {...props} />,
  a:   (props) => <a className="text-primary underline" target="_blank" rel="noreferrer" {...props} />,
  strong: (props) => <strong className="font-semibold" {...props} />,
  hr:  () => <hr className="my-3 border-border" />,
  blockquote: (props) => <blockquote className="my-2 pl-3 border-l-2 border-border text-muted-foreground" {...props} />,
}

interface Props {
  message: AssistantMessage
  onPin?: (id: number) => void
  onUnpin?: (id: number) => void
  onReference?: (id: number) => void
  isReferenced?: boolean
}

export function MessageBubble({ message, onPin, onUnpin, onReference, isReferenced }: Props) {
  if (message.role === 'tool') {
    return <ToolBubble message={message} />
  }

  const isUser = message.role === 'user'
  const Icon = isUser ? UserIcon : Bot
  const align = isUser ? 'items-end' : 'items-start'
  const bubbleClass = isUser
    ? 'bg-primary text-primary-foreground'
    : 'bg-muted'

  return (
    <div className={`flex flex-col gap-1 ${align}`}>
      <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
        <Icon size={12} />
        <span>{isUser ? 'You' : message.provider ?? 'Assistant'}</span>
        {message.model && !isUser && <span className="opacity-70">· {message.model}</span>}
        {message.pinned && <Badge variant="outline" className="gap-1 text-[10px] py-0"><Pin size={9} /> pinned</Badge>}
      </div>
      <div className={`max-w-[75%] rounded-lg px-4 py-2 text-sm ${bubbleClass}`}>
        {message.file_name && (
          <a
            href={message.file_url ?? '#'}
            target="_blank"
            rel="noreferrer"
            className="block mb-2 px-2 py-1 rounded bg-background/40 text-xs font-mono truncate"
          >
            📎 {message.file_name}
          </a>
        )}
        {message.content && (
          isUser ? (
            <p className="whitespace-pre-wrap">{message.content}</p>
          ) : (
            <div className="text-sm leading-relaxed">
              <ReactMarkdown remarkPlugins={[remarkGfm]} components={MARKDOWN_COMPONENTS}>
                {message.content}
              </ReactMarkdown>
            </div>
          )
        )}
      </div>
      <div className="flex items-center gap-2 text-[10px] text-muted-foreground">
        <span>{new Date(message.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
        {!isUser && message.tokens_out != null && <span>· {message.tokens_in}→{message.tokens_out} tok</span>}
        {!isUser && message.latency_ms != null && <span>· {message.latency_ms}ms</span>}
        {(onPin || onUnpin) && (
          <Button
            size="icon-xs"
            variant="ghost"
            className="h-5 w-5 -my-1"
            onClick={() => (message.pinned ? onUnpin?.(message.id) : onPin?.(message.id))}
            title={message.pinned ? 'Unpin' : 'Pin to context (always included)'}
          >
            {message.pinned ? <PinOff size={11} /> : <Pin size={11} />}
          </Button>
        )}
        {onReference && (
          <Button
            size="icon-xs"
            variant="ghost"
            className={`h-5 w-5 -my-1 ${isReferenced ? 'text-primary' : ''}`}
            onClick={() => onReference(message.id)}
            title={isReferenced ? 'Remove from next message context' : 'Reference in next message'}
          >
            <AtSign size={11} />
          </Button>
        )}
      </div>
    </div>
  )
}

function ToolBubble({ message }: { message: AssistantMessage }) {
  return (
    <details className="rounded-md border border-dashed bg-muted/30 px-3 py-2 text-xs self-start">
      <summary className="cursor-pointer flex items-center gap-1.5 text-muted-foreground">
        <Wrench size={11} /> tool · <code className="font-mono">{message.tool_name}</code>
        {message.file_name && <span className="ml-1">· generated <code>{message.file_name}</code></span>}
      </summary>
      {message.tool_arguments && (
        <pre className="mt-2 max-h-40 overflow-auto bg-background rounded p-2 text-[11px]">
          {JSON.stringify(message.tool_arguments, null, 2)}
        </pre>
      )}
      {message.tool_result && (
        <pre className="mt-2 max-h-60 overflow-auto bg-background rounded p-2 text-[11px]">
          {JSON.stringify(message.tool_result, null, 2)}
        </pre>
      )}
      {message.file_url && (
        <a className="mt-2 inline-block text-primary underline" href={message.file_url} target="_blank" rel="noreferrer">
          Download {message.file_name}
        </a>
      )}
    </details>
  )
}
