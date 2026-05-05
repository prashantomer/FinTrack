import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import {
  createInvestment,
  deleteInvestment,
  listInvestments,
  updateInvestment,
} from '@/api/investments'
import type { Investment, InvestmentType } from '@/types'

export function useInvestments(types?: InvestmentType[], page = 1, pageSize = 20) {
  return useQuery({
    queryKey: ['investments', types, page, pageSize],
    queryFn: () => listInvestments(types, page, pageSize),
  })
}

export function useCreateInvestment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: Partial<Investment> & { type: InvestmentType; name: string; amount_invested: number; purchase_date: string }) =>
      createInvestment(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['investments'] })
      toast.success('Investment added')
    },
  })
}

export function useUpdateInvestment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<Investment> }) =>
      updateInvestment(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['investments'] })
      toast.success('Investment updated')
    },
  })
}

export function useDeleteInvestment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteInvestment(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['investments'] })
      toast.success('Investment deleted')
    },
  })
}
