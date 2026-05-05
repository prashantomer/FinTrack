import client from './client'
import type { ApiResponse, Follio, FollioCreate, FollioListResponse, FollioUpdate } from '@/types'

export async function listFollios(page = 1, pageSize = 20): Promise<FollioListResponse> {
  const res = await client.get<ApiResponse<Follio[]>>('/follios', { params: { page, page_size: pageSize } })
  return {
    items: res.data.data,
    total: (res.data.meta_data.total as number) ?? 0,
    page: (res.data.meta_data.page as number) ?? page,
    page_size: (res.data.meta_data.page_size as number) ?? pageSize,
  }
}

export const createFollio = (data: FollioCreate) =>
  client.post<ApiResponse<Follio>>('/follios', data).then(r => r.data.data)

export const updateFollio = (id: number, data: FollioUpdate) =>
  client.put<ApiResponse<Follio>>(`/follios/${id}`, data).then(r => r.data.data)

export const deleteFollio = (id: number) =>
  client.delete(`/follios/${id}`)
