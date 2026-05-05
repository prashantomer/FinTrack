import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import {
  createPlatformAccount,
  deletePlatformAccount,
  listPlatformAccounts,
  listPlatforms,
  updatePlatformAccount,
} from '@/api/platforms'
import type { PlatformAccountCreate, PlatformAccountUpdate } from '@/types'

export function usePlatforms() {
  return useQuery({ queryKey: ['platforms'], queryFn: listPlatforms })
}

export function usePlatformAccounts() {
  return useQuery({ queryKey: ['platform-accounts'], queryFn: listPlatformAccounts })
}

export function useCreatePlatformAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: PlatformAccountCreate) => createPlatformAccount(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['platform-accounts'] })
      toast.success('Platform account added')
    },
  })
}

export function useUpdatePlatformAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: PlatformAccountUpdate }) =>
      updatePlatformAccount(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['platform-accounts'] })
      toast.success('Platform account updated')
    },
  })
}

export function useDeletePlatformAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deletePlatformAccount(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['platform-accounts'] })
      toast.success('Platform account deleted')
    },
  })
}
