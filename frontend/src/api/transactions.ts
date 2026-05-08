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

export interface TransactionEditableFields {
  description?: string | null
  tags?: string[]
}

// The server only accepts description + tags on manual rows; imported rows are
// rejected with 403. The signature mirrors that contract on purpose so callers
// can't accidentally send fields the server will silently drop.
export async function updateTransaction(id: number, data: TransactionEditableFields) {
  const res = await client.put<ApiResponse<Transaction>>(`/transactions/${id}`, data)
  return res.data.data
}
