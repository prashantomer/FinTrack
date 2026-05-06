import type { ApiResponse } from '@/types'
import client from './client'

export type AssistantProvider = 'anthropic' | 'openai' | 'ollama'

export interface AssistantSetting {
  provider: AssistantProvider | null
  model: string | null
  base_url: string | null
  daily_limit: number
  effective_provider: AssistantProvider
  effective_model: string
  effective_base_url: string
  has_api_key: boolean
  api_key_tail: string | null
  requires_api_key: boolean
  configured: boolean
  last_tested_at: string | null
  last_test_status: 'ok' | 'error' | null
  last_test_error: string | null
}

export interface AssistantSettingUpdate {
  provider?: AssistantProvider
  model?: string | null
  base_url?: string | null
  api_key?: string
  daily_limit?: number
}

export interface AssistantTestResult {
  ok: boolean
  latency_ms?: number
  code?: string
  provider?: string
  error_class?: string
  message?: string
}

export async function getAssistantSetting() {
  const res = await client.get<ApiResponse<AssistantSetting>>('/assistant/setting')
  return res.data.data
}

export async function updateAssistantSetting(payload: AssistantSettingUpdate) {
  const res = await client.patch<ApiResponse<AssistantSetting>>('/assistant/setting', payload)
  return res.data.data
}

export async function testAssistantSetting(payload: AssistantSettingUpdate = {}) {
  const res = await client.post<ApiResponse<AssistantTestResult>>('/assistant/setting/test', payload)
  return res.data.data
}

export type AssistantRole = 'user' | 'assistant' | 'tool'

export interface AssistantMessage {
  id: number
  session_id: string
  role: AssistantRole
  content: string | null
  tool_name: string | null
  tool_arguments: Record<string, unknown> | null
  tool_result: Record<string, unknown> | null
  pinned: boolean
  file_name: string | null
  file_url: string | null
  provider: string | null
  model: string | null
  tokens_in: number | null
  tokens_out: number | null
  latency_ms: number | null
  created_at: string
}

export interface AssistantAttachment {
  attachment_id: number
  filename: string
  byte_size: number
  content_type: string
}

export interface SendMessagePayload {
  content: string
  session_id?: string
  attachment_id?: number | null
  reference_ids?: number[]
}

export interface SendMessageResult {
  session_id: string
  user_message: AssistantMessage
  assistant_message: AssistantMessage
  tool_messages: AssistantMessage[]
}

export async function listAssistantMessages(params: { session_id?: string; limit?: number; before?: number } = {}) {
  const res = await client.get<ApiResponse<AssistantMessage[]>>('/assistant/messages', { params })
  return res.data.data
}

export async function sendAssistantMessage(payload: SendMessagePayload) {
  const res = await client.post<ApiResponse<SendMessageResult>>('/assistant/messages', payload)
  return res.data.data
}

export async function uploadAssistantAttachment(file: File) {
  const form = new FormData()
  form.append('file', file)
  const res = await client.post<ApiResponse<AssistantAttachment>>('/assistant/attachments', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data.data
}

export async function pinAssistantMessage(id: number) {
  const res = await client.post<ApiResponse<AssistantMessage>>(`/assistant/messages/${id}/pin`)
  return res.data.data
}

export async function unpinAssistantMessage(id: number) {
  const res = await client.delete<ApiResponse<AssistantMessage>>(`/assistant/messages/${id}/pin`)
  return res.data.data
}

export async function startAssistantSession() {
  const res = await client.post<ApiResponse<{ session_id: string }>>('/assistant/sessions')
  return res.data.data.session_id
}

export async function clearAssistantHistory() {
  await client.delete('/assistant/messages/all')
}
