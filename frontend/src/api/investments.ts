import type { ApiResponse, Investment, InvestmentListResponse, InvestmentType } from '@/types'
import client from './client'

export async function listInvestments(type?: InvestmentType[], page = 1, pageSize = 20): Promise<InvestmentListResponse> {
  const params: Record<string, unknown> = { page, page_size: pageSize }
  if (type?.length) params.investment_type = type
  const res = await client.get<ApiResponse<Investment[]>>('/investments', { params })
  return {
    items: res.data.data,
    total: (res.data.meta_data.total as number) ?? 0,
    page: (res.data.meta_data.page as number) ?? page,
    page_size: (res.data.meta_data.page_size as number) ?? pageSize,
  }
}

export async function getInvestment(id: number) {
  const res = await client.get<ApiResponse<Investment>>(`/investments/${id}`)
  return res.data.data
}

export async function createInvestment(data: Partial<Investment> & { type: InvestmentType; name: string; amount_invested: number; purchase_date: string }) {
  const res = await client.post<ApiResponse<Investment>>('/investments', data)
  return res.data.data
}

export async function updateInvestment(id: number, data: Partial<Investment>) {
  const res = await client.put<ApiResponse<Investment>>(`/investments/${id}`, data)
  return res.data.data
}

export async function deleteInvestment(id: number) {
  await client.delete(`/investments/${id}`)
}
