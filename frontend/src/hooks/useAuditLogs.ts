import { useQuery } from '@tanstack/react-query'
import { listAccountAuditLogs, listTermAccountAuditLogs } from '@/api/audit'

export type AuditTarget = {
  id: number
  type: 'account' | 'term_account'
  label: string
  subtitle: string
} | null

export function useAuditLogs(target: AuditTarget) {
  return useQuery({
    queryKey: ['audit-logs', target?.type, target?.id],
    queryFn: () =>
      target!.type === 'account'
        ? listAccountAuditLogs(target!.id)
        : listTermAccountAuditLogs(target!.id),
    enabled: target !== null,
  })
}
