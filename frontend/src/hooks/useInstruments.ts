import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createInstrument,
  listInstruments,
  listTrackedInstruments,
  trackInstrument,
  untrackInstrument,
} from '@/api/instruments'
import type { InstrumentCreate, InvestmentType } from '@/types'

export function useInstruments(params: { type?: InvestmentType; search?: string } = {}) {
  return useQuery({
    queryKey: ['instruments', params],
    queryFn: () => listInstruments(params),
  })
}

export function useTrackedInstruments() {
  return useQuery({ queryKey: ['instruments', 'tracked'], queryFn: listTrackedInstruments })
}

export function useCreateInstrument() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: InstrumentCreate) => createInstrument(data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['instruments'] }),
  })
}

export function useTrackInstrument() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => trackInstrument(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['instruments'] }),
  })
}

export function useUntrackInstrument() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => untrackInstrument(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['instruments'] }),
  })
}
