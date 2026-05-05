import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  getDashboard,
  getDashboardCacheStatus,
  getInvestmentSummary,
  getSpendingTrends,
  refreshDashboard,
} from '@/api/reports'

export function useDashboard() {
  return useQuery({
    queryKey: ['reports', 'dashboard'],
    queryFn: getDashboard,
    staleTime: Infinity,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
    refetchOnMount: false,
  })
}

export function useDashboardCacheStatus() {
  return useQuery({
    queryKey: ['reports', 'dashboard', 'cache-status'],
    queryFn: getDashboardCacheStatus,
    refetchInterval: 30_000,
    staleTime: 10_000,
  })
}

export function useRefreshDashboard() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: refreshDashboard,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['reports', 'dashboard'] }),
  })
}

export function useSpendingTrends(months = 6) {
  return useQuery({
    queryKey: ['reports', 'spending-trends', months],
    queryFn: () => getSpendingTrends(months),
  })
}

export function useInvestmentSummary() {
  return useQuery({
    queryKey: ['reports', 'investment-summary'],
    queryFn: getInvestmentSummary,
  })
}
