import apiClient from './client'
import type { AuditLog } from '@/types'

export async function listAccountAuditLogs(accountId: number): Promise<AuditLog[]> {
  const { data } = await apiClient.get<AuditLog[]>(`/accounts/${accountId}/audit-logs`)
  return data
}

export async function listTermAccountAuditLogs(termAccountId: number): Promise<AuditLog[]> {
  const { data } = await apiClient.get<AuditLog[]>(`/term-accounts/${termAccountId}/audit-logs`)
  return data
}
