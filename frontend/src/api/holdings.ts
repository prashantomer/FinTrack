import client from './client'
import type { ApiResponse, Holding, HoldingCreate, HoldingListResponse, HoldingUpdate } from '@/types'

export interface HoldingsListFilters {
  type?: 'Folio' | 'EquityHolding'
  status?: 'open' | 'closed'
  page?: number
  page_size?: number
}

export async function listHoldings(filters: HoldingsListFilters = {}): Promise<HoldingListResponse> {
  const { type, status, page = 1, page_size = 50 } = filters
  const params: Record<string, unknown> = { page, page_size }
  if (type)   params.type = type
  if (status) params.status = status
  const res = await client.get<ApiResponse<Holding[]>>('/holdings', { params })
  return {
    items: res.data.data,
    total: (res.data.meta_data.total as number) ?? 0,
    page: (res.data.meta_data.page as number) ?? page,
    page_size: (res.data.meta_data.page_size as number) ?? page_size,
  }
}

export const createHolding = (data: HoldingCreate) =>
  client.post<ApiResponse<Holding>>('/holdings', data).then(r => r.data.data)

export const updateHolding = (id: number, data: HoldingUpdate) =>
  client.put<ApiResponse<Holding>>(`/holdings/${id}`, data).then(r => r.data.data)

export const deleteHolding = (id: number) =>
  client.delete(`/holdings/${id}`)

/** Force a recompute of every Holding's cached stats for the current user. */
export const refreshHoldings = () =>
  client.post<ApiResponse<{ count: number }>>('/holdings/refresh').then(r => r.data.data)
