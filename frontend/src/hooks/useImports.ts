import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { createImport, getImport, listImports, resolveImport } from '@/api/imports'
import type { ImportType } from '@/types'

export function useImports(page = 1) {
  return useQuery({
    queryKey: ['imports', page],
    queryFn:  () => listImports(page),
  })
}

// Infinite-scroll variant — used by ImportsPage. Backend paginates by
// `?page=N&page_size=20`; each page yields up to 20 batches and we keep
// requesting the next page until `items.length < page_size`.
export function useInfiniteImports(pageSize = 20) {
  return useInfiniteQuery({
    queryKey:    ['imports', 'infinite', pageSize],
    initialPageParam: 1,
    queryFn:     ({ pageParam }) => listImports(pageParam as number, pageSize),
    getNextPageParam: (lastPage, allPages) =>
      lastPage.items.length < pageSize ? undefined : allPages.length + 1,
  })
}

export function useImport(id: number | null) {
  return useQuery({
    queryKey: ['imports', id],
    queryFn:  () => getImport(id!),
    enabled:  id != null,
    refetchInterval: (query) => {
      const status = query.state.data?.status
      return status === 'processing' || status === 'pending' ? 1500 : false
    },
  })
}

export function useCreateImport() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ importType, file, linkedAccount, onBalanceMismatch }: {
      importType: ImportType
      file:       File
      linkedAccount?: string
      onBalanceMismatch?: 'ask' | 'adjust' | 'fail'
    }) =>
      createImport(importType, file, { linkedAccount, onBalanceMismatch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['imports'] })
    },
    onError: () => toast.error('Failed to start import'),
  })
}

export function useResolveImport() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ importId, action }: { importId: number; action: 'adjust' | 'abort' }) =>
      resolveImport(importId, action),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['imports'] })
      qc.invalidateQueries({ queryKey: ['accounts'] })
      qc.invalidateQueries({ queryKey: ['transactions'] })
    },
    onError: () => toast.error('Failed to resolve import'),
  })
}
