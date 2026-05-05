import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { createImport, getImport, listImports } from '@/api/imports'
import type { ImportType } from '@/types'

export function useImports(page = 1) {
  return useQuery({
    queryKey: ['imports', page],
    queryFn:  () => listImports(page),
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
    mutationFn: ({ importType, file }: { importType: ImportType; file: File }) =>
      createImport(importType, file),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['imports'] })
    },
    onError: () => toast.error('Failed to start import'),
  })
}
