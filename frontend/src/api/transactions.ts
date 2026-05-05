import type { ApiResponse, Transaction, TransactionCreate, TransactionListResponse, TransactionType } from '@/types'
import client from './client'

interface ListParams {
  page?: number
  page_size?: number
  type?: TransactionType
  date_from?: string
  date_to?: string
  search?: string
  cursor?: string
}

export async function listTransactions(params: ListParams = {}): Promise<TransactionListResponse> {
  const res = await client.get<ApiResponse<Transaction[]>>('/transactions', { params })
  return {
    items:      res.data.data,
    total:      (res.data.meta_data.total as number) ?? 0,
    page:       1,
    page_size:  params.page_size ?? 50,
    next_cursor: (res.data.meta_data.next_cursor as string | null) ?? null,
  }
}

export async function createTransaction(data: TransactionCreate) {
  const res = await client.post<ApiResponse<Transaction>>('/transactions', data)
  return res.data.data
}
