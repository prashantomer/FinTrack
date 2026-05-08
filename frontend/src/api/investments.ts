import type { ApiResponse, Investment, InvestmentListResponse, InvestmentType, TradeType } from '@/types'
import client from './client'

export interface InvestmentListFilters {
  type?: InvestmentType[]
  trade_type?: TradeType
  search?: string
  date_from?: string
  date_to?: string
  page?: number
  page_size?: number
}

export async function listInvestments(filters: InvestmentListFilters = {}): Promise<InvestmentListResponse> {
  const { type, trade_type, search, date_from, date_to, page = 1, page_size = 20 } = filters
  const params: Record<string, unknown> = { page, page_size }
  if (type?.length)        params.investment_type = type
  if (trade_type)          params.trade_type = trade_type
  if (search)              params.search = search
  if (date_from)           params.date_from = date_from
  if (date_to)             params.date_to = date_to
  const res = await client.get<ApiResponse<Investment[]>>('/investments', { params })
  return {
    items: res.data.data,
    total: (res.data.meta_data.total as number) ?? 0,
    page: (res.data.meta_data.page as number) ?? page,
    page_size: (res.data.meta_data.page_size as number) ?? page_size,
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

export interface FolioUpdateResult {
  user_instrument_id: number
  folio_number: string | null
  updated: number
}

/**
 * Bulk-update folio_number on every investment lot belonging to a single
 * user_instrument. Used to correct auto-generated folios from Holdings.
 */
export async function updateInstrumentFolio(user_instrument_id: number, folio_number: string | null) {
  const res = await client.patch<ApiResponse<FolioUpdateResult>>('/investments/folio', {
    user_instrument_id,
    folio_number,
  })
  return res.data.data
}
