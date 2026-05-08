import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  clearAssistantHistory,
  listAssistantMessages,
  pinAssistantMessage,
  sendAssistantMessage,
  startAssistantSession,
  unpinAssistantMessage,
  uploadAssistantAttachment,
  type AssistantMessage,
  type SendMessagePayload,
} from '@/api/assistant'

const KEY = ['assistant', 'messages'] as const

export function useAssistantChat() {
  const qc = useQueryClient()
  const list = useQuery({ queryKey: KEY, queryFn: () => listAssistantMessages({ limit: 200 }) })

  const sendMutation = useMutation({
    mutationFn: (payload: SendMessagePayload) => sendAssistantMessage(payload),
    onSuccess: (result) => {
      qc.setQueryData<AssistantMessage[]>(KEY, (prev) => {
        const existing = prev ?? []
        return [...existing, result.user_message, ...result.tool_messages, result.assistant_message]
      })
    },
  })

  const uploadMutation = useMutation({ mutationFn: (file: File) => uploadAssistantAttachment(file) })
  const newSessionMutation = useMutation({ mutationFn: startAssistantSession })
  const clearMutation = useMutation({
    mutationFn: clearAssistantHistory,
    onSuccess: () => qc.setQueryData(KEY, []),
  })
  const pinMutation = useMutation({
    mutationFn: (id: number) => pinAssistantMessage(id),
    onSuccess: (msg) => qc.setQueryData<AssistantMessage[]>(KEY, (prev) => prev?.map(m => m.id === msg.id ? msg : m)),
  })
  const unpinMutation = useMutation({
    mutationFn: (id: number) => unpinAssistantMessage(id),
    onSuccess: (msg) => qc.setQueryData<AssistantMessage[]>(KEY, (prev) => prev?.map(m => m.id === msg.id ? msg : m)),
  })

  return {
    messages: list.data ?? [],
    isLoading: list.isLoading,
    send: sendMutation.mutateAsync,
    isSending: sendMutation.isPending,
    upload: uploadMutation.mutateAsync,
    isUploading: uploadMutation.isPending,
    newSession: newSessionMutation.mutateAsync,
    clear: clearMutation.mutateAsync,
    pin: pinMutation.mutateAsync,
    unpin: unpinMutation.mutateAsync,
  }
}
