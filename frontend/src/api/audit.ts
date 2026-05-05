import apiClient from './client'
import type { ApiResponse, AuditLog } from '@/types'

export async function listAccountAuditLogs(accountId: number): Promise<AuditLog[]> {
  const res = await apiClient.get<ApiResponse<AuditLog[]>>(`/accounts/${accountId}/audit-logs`)
  return res.data.data
}

export async function listTermAccountAuditLogs(termAccountId: number): Promise<AuditLog[]> {
  const res = await apiClient.get<ApiResponse<AuditLog[]>>(`/term-accounts/${termAccountId}/audit-logs`)
  return res.data.data
}
