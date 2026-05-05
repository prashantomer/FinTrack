import type { Transaction, TransactionCreate, TransactionListResponse, TransactionType } from '@/types'
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

export async function listTransactions(params: ListParams = {}) {
  const res = await client.get<TransactionListResponse>('/transactions/', { params })
  return res.data
}

export async function createTransaction(data: TransactionCreate) {
  const res = await client.post<Transaction>('/transactions/', data)
  return res.data
}
