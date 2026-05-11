import { useInfiniteQuery } from '@tanstack/react-query'
import { listAccountAuditLogs, listTermAccountAuditLogs } from '@/api/audit'

export type AuditTarget = {
  id: number
  type: 'account' | 'term_account'
  label: string
  subtitle: string
} | null

export function useAuditLogs(target: AuditTarget) {
  return useInfiniteQuery({
    queryKey: ['audit-logs', target?.type, target?.id],
    initialPageParam: null as number | null,
    queryFn: ({ pageParam }) =>
      target!.type === 'account'
        ? listAccountAuditLogs(target!.id, { cursor: pageParam })
        : listTermAccountAuditLogs(target!.id, { cursor: pageParam }),
    getNextPageParam: (lastPage) => lastPage.next_cursor,
    enabled: target !== null,
  })
}
