import apiClient from './client'
import type { ApiResponse, AuditLog } from '@/types'

export interface AuditLogPage {
  items:       AuditLog[]
  next_cursor: number | null
}

interface ListOpts {
  cursor?: number | null
  limit?:  number
}

async function fetchPage(url: string, opts: ListOpts = {}): Promise<AuditLogPage> {
  const res = await apiClient.get<ApiResponse<AuditLog[]>>(url, {
    params: {
      before: opts.cursor ?? undefined,
      limit:  opts.limit  ?? undefined,
    },
  })
  const next = res.data.meta_data?.next_cursor
  return {
    items:       res.data.data,
    next_cursor: typeof next === 'number' ? next : null,
  }
}

export function listAccountAuditLogs(accountId: number, opts: ListOpts = {}): Promise<AuditLogPage> {
  return fetchPage(`/accounts/${accountId}/audit-logs`, opts)
}

export function listTermAccountAuditLogs(termAccountId: number, opts: ListOpts = {}): Promise<AuditLogPage> {
  return fetchPage(`/term-accounts/${termAccountId}/audit-logs`, opts)
}
