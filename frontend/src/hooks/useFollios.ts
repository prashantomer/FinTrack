import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFollio, deleteFollio, listFollios, updateFollio } from '@/api/follios'
import type { FollioCreate, FollioUpdate } from '@/types'

export function useFollios() {
  return useQuery({ queryKey: ['follios'], queryFn: listFollios })
}

export function useCreateFollio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: FollioCreate) => createFollio(data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['follios'] }),
  })
}

export function useUpdateFollio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: FollioUpdate }) => updateFollio(id, data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['follios'] }),
  })
}

export function useDeleteFollio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteFollio(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['follios'] }),
  })
}
