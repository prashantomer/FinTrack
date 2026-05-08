import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import {
  createInstrument,
  getInstrumentLots,
  getInstrumentPosition,
  getInstrumentPriceHistory,
  getInstrumentTransactions,
  listInstrumentTypes,
  listInstruments,
  listTrackedInstruments,
  listUserInstruments,
  trackInstrument,
  untrackInstrument,
} from '@/api/instruments'
import type { InstrumentCreate, InvestmentType } from '@/types'

// Flat list — used by InstrumentCombobox (server-side search, first page only)
export function useInstruments(params: { type?: InvestmentType; search?: string; limit?: number } = {}) {
  return useQuery({
    queryKey: ['instruments', 'list', params],
    queryFn: async () => {
      const page = await listInstruments({ ...params, limit: params.limit ?? 50 })
      return page.items
    },
  })
}

// Infinite scroll — used by InstrumentsPage
export function useInfiniteInstruments(params: { type?: InvestmentType; search?: string } = {}) {
  return useInfiniteQuery({
    queryKey: ['instruments', 'infinite', params],
    queryFn: ({ pageParam }) =>
      listInstruments({ ...params, cursor: pageParam as number | undefined }),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (lastPage) => lastPage.next_cursor ?? undefined,
  })
}

export function useTrackedInstruments() {
  return useQuery({ queryKey: ['instruments', 'tracked'], queryFn: listTrackedInstruments })
}

export function useInstrumentTypes() {
  return useQuery({ queryKey: ['instruments', 'types'], queryFn: listInstrumentTypes, staleTime: Infinity })
}

export function useCreateInstrument() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: InstrumentCreate) => createInstrument(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['instruments'] })
      toast.success('Instrument created')
    },
  })
}

export function useTrackInstrument() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => trackInstrument(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['instruments'] })
      toast.success('Instrument tracked')
    },
  })
}

export function useUntrackInstrument() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => untrackInstrument(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['instruments'] })
      toast.success('Instrument untracked')
    },
  })
}

export function useUserInstruments() {
  return useQuery({
    queryKey: ['instruments', 'user-instruments'],
    queryFn: listUserInstruments,
  })
}

// ── Profile hooks ─────────────────────────────────────────────────────────

export function useInstrumentPosition(id: number | null | undefined) {
  return useQuery({
    queryKey: ['instruments', 'profile', 'position', id],
    queryFn: () => getInstrumentPosition(id as number),
    enabled: id != null,
  })
}

export function useInstrumentLots(id: number | null | undefined) {
  return useQuery({
    queryKey: ['instruments', 'profile', 'lots', id],
    queryFn: () => getInstrumentLots(id as number),
    enabled: id != null,
  })
}

export function useInstrumentTransactions(id: number | null | undefined, limit = 50) {
  return useQuery({
    queryKey: ['instruments', 'profile', 'transactions', id, limit],
    queryFn: () => getInstrumentTransactions(id as number, limit),
    enabled: id != null,
  })
}

export function useInstrumentPriceHistory(id: number | null | undefined, days = 90) {
  return useQuery({
    queryKey: ['instruments', 'profile', 'price-history', id, days],
    queryFn: () => getInstrumentPriceHistory(id as number, days),
    enabled: id != null,
  })
}
