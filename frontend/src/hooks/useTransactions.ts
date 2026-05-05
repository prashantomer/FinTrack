import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { createTransaction, listTransactions } from '@/api/transactions'
import type { TransactionCreate, TransactionType } from '@/types'

interface UseTransactionsParams {
  page?: number
  page_size?: number
  type?: TransactionType
  date_from?: string
  date_to?: string
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
