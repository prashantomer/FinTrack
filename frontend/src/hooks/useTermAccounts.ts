import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { adjustTermAccountBalance, closeTermAccount, createTermAccount, depositPPF, listTermAccounts, updateTermAccount } from '@/api/term_accounts'
import type { BalanceAdjust, PPFDeposit, TermAccountClose, TermAccountCreate, TermAccountUpdate } from '@/types'

export function useTermAccounts() {
  return useQuery({ queryKey: ['term-accounts'], queryFn: listTermAccounts })
}

export function useCreateTermAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: TermAccountCreate) => createTermAccount(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      qc.invalidateQueries({ queryKey: ['accounts'] })
      toast.success('Term account created')
    },
  })
}

export function useDepositPPF() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: PPFDeposit }) => depositPPF(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      qc.invalidateQueries({ queryKey: ['accounts'] })
      qc.invalidateQueries({ queryKey: ['audit-logs'] })
      toast.success('Deposit recorded')
    },
  })
}

export function useUpdateTermAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: TermAccountUpdate }) => updateTermAccount(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      toast.success('Term account updated')
    },
  })
}

export function useAdjustTermAccountBalance() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: BalanceAdjust }) => adjustTermAccountBalance(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      qc.invalidateQueries({ queryKey: ['audit-logs'] })
      toast.success('Balance adjusted')
    },
  })
}

export function useCloseTermAccount() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: TermAccountClose }) => closeTermAccount(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      qc.invalidateQueries({ queryKey: ['accounts'] })
      toast.success('Term account closed')
    },
  })
}
