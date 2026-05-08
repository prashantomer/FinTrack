import type {
  ApiResponse,
  DashboardCacheStatus,
  DashboardReport,
  InvestmentSummaryReport,
  PerformanceReport,
  PortfolioReport,
  SpendingTrendsReport,
} from '@/types'
import client from './client'

export async function getDashboard() {
  const res = await client.get<ApiResponse<DashboardReport>>('/reports/dashboard')
  return res.data.data
}

export async function getSpendingTrends(months = 6) {
  const res = await client.get<ApiResponse<SpendingTrendsReport>>('/reports/spending-trends', {
    params: { months },
  })
  return res.data.data
}

export async function getInvestmentSummary() {
  const res = await client.get<ApiResponse<InvestmentSummaryReport>>('/reports/investment-summary')
  return res.data.data
}

export async function refreshDashboard() {
  await client.post('/reports/dashboard/refresh')
}

export async function getDashboardCacheStatus() {
  const res = await client.get<ApiResponse<DashboardCacheStatus>>('/reports/dashboard/cache-status')
  return res.data.data
}

export async function getPortfolio() {
  const res = await client.get<ApiResponse<PortfolioReport>>('/reports/portfolio')
  return res.data.data
}

export async function getPerformance(days = 90) {
  const res = await client.get<ApiResponse<PerformanceReport>>('/reports/performance', {
    params: { days },
  })
  return res.data.data
}
