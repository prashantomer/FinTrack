import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import {
  createInvestment,
  deleteInvestment,
  listInvestments,
  updateInstrumentFolio,
  updateInvestment,
  type InvestmentListFilters,
} from '@/api/investments'
import type { Investment, InvestmentType } from '@/types'

export function useInvestments(types?: InvestmentType[], page = 1, pageSize = 20) {
  return useQuery({
    queryKey: ['investments', types, page, pageSize],
    queryFn: () => listInvestments({ type: types, page, page_size: pageSize }),
  })
}

export function useFilteredInvestments(filters: InvestmentListFilters) {
  return useQuery({
    queryKey: ['investments', filters],
    queryFn: () => listInvestments(filters),
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

export function useUpdateInstrumentFolio() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ user_instrument_id, folio_number }: { user_instrument_id: number; folio_number: string | null }) =>
      updateInstrumentFolio(user_instrument_id, folio_number),
    onSuccess: ({ updated }) => {
      qc.invalidateQueries({ queryKey: ['investments'] })
      qc.invalidateQueries({ queryKey: ['reports', 'portfolio'] })
      toast.success(`Folio updated on ${updated} ${updated === 1 ? 'lot' : 'lots'}`)
    },
  })
}
