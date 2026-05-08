import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { createHolding, deleteHolding, listHoldings, refreshHoldings, updateHolding, type HoldingsListFilters } from '@/api/holdings'
import type { HoldingCreate, HoldingUpdate } from '@/types'

export function useHoldings(filters: HoldingsListFilters = {}) {
  return useQuery({
    queryKey: ['holdings', filters],
    queryFn: () => listHoldings(filters),
  })
}

export function useCreateHolding() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: HoldingCreate) => createHolding(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings'] })
      toast.success('Holding created')
    },
  })
}

export function useUpdateHolding() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: HoldingUpdate }) => updateHolding(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings'] })
      toast.success('Holding updated')
    },
  })
}

export function useDeleteHolding() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteHolding(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings'] })
      toast.success('Holding deleted')
    },
  })
}

export function useRefreshHoldings() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => refreshHoldings(),
    onSuccess: ({ count }) => {
      qc.invalidateQueries({ queryKey: ['holdings'] })
      qc.invalidateQueries({ queryKey: ['reports', 'portfolio'] })
      toast.success(`Refreshed ${count} ${count === 1 ? 'holding' : 'holdings'}`)
    },
  })
}
