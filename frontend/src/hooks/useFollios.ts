import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { createFollio, deleteFollio, listFollios, updateFollio } from '@/api/follios'
import type { FollioCreate, FollioUpdate } from '@/types'

export function useFollios(page = 1, pageSize = 20) {
  return useQuery({
    queryKey: ['follios', page, pageSize],
    queryFn: () => listFollios(page, pageSize),
  })
}

export function useCreateFollio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: FollioCreate) => createFollio(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['follios'] })
      toast.success('Follio created')
    },
  })
}

export function useUpdateFollio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: FollioUpdate }) => updateFollio(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['follios'] })
      toast.success('Follio updated')
    },
  })
}

export function useDeleteFollio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteFollio(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['follios'] })
      toast.success('Follio deleted')
    },
  })
}
