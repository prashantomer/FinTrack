import type {
  DashboardCacheStatus,
  DashboardReport,
  InvestmentSummaryReport,
  SpendingTrendsReport,
} from '@/types'
import client from './client'

export async function getDashboard() {
  const res = await client.get<DashboardReport>('/reports/dashboard')
  return res.data
}

export async function getSpendingTrends(months = 6) {
  const res = await client.get<SpendingTrendsReport>('/reports/spending-trends', {
    params: { months },
  })
  return res.data
}

export async function getInvestmentSummary() {
  const res = await client.get<InvestmentSummaryReport>('/reports/investment-summary')
  return res.data
}

export async function refreshDashboard() {
  await client.post('/reports/dashboard/refresh')
}

export async function getDashboardCacheStatus() {
  const res = await client.get<DashboardCacheStatus>('/reports/dashboard/cache-status')
  return res.data
}
