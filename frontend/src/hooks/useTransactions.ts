import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { createTransaction, listTransactions, updateTransaction, type TransactionEditableFields } from '@/api/transactions'
import type { RecordSource, TransactionCreate, TransactionType } from '@/types'

interface UseTransactionsParams {
  page?: number
  page_size?: number
  type?: TransactionType
  date_from?: string
  date_to?: string
  search?: string
  source?: RecordSource
  linked_account_type?: 'Account' | 'TermAccount'
  linked_account_id?: number
  sort_by?: 'date' | 'account'
  sort_dir?: 'asc' | 'desc'
}

export function useTransactions(params: UseTransactionsParams = {}) {
  return useQuery({
    queryKey: ['transactions', params],
    queryFn: () => listTransactions(params),
  })
}

export function useCreateTransaction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: TransactionCreate) => createTransaction(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['transactions'] })
      qc.invalidateQueries({ queryKey: ['accounts'] })
      qc.invalidateQueries({ queryKey: ['term-accounts'] })
      toast.success('Transaction added')
    },
  })
}

export function useUpdateTransaction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: TransactionEditableFields }) =>
      updateTransaction(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['transactions'] })
      toast.success('Transaction updated')
    },
  })
}
