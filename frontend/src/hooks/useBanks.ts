import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { adjustAccountBalance, closeAccount, createAccount, deleteAccount, listAccounts, listBanks, updateAccount } from '@/api/banks'
import type { AccountClose, AccountCreate, AccountUpdate, BalanceAdjust } from '@/types'

export function useBanks() {
  return useQuery({ queryKey: ['banks'], queryFn: listBanks })
}

export function useAccounts() {
  return useQuery({ queryKey: ['accounts'], queryFn: listAccounts })
}

export function useCreateAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: AccountCreate) => createAccount(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['accounts'] })
      toast.success('Account created')
    },
  })
}

export function useUpdateAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: AccountUpdate }) => updateAccount(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['accounts'] })
      toast.success('Account updated')
    },
  })
}

export function useCloseAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: AccountClose }) => closeAccount(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['accounts'] })
      toast.success('Account closed')
    },
  })
}

export function useAdjustAccountBalance() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: BalanceAdjust }) => adjustAccountBalance(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['accounts'] })
      qc.invalidateQueries({ queryKey: ['audit-logs'] })
      toast.success('Balance adjusted')
    },
  })
}

export function useDeleteAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteAccount(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['accounts'] })
      toast.success('Account deleted')
    },
  })
}
