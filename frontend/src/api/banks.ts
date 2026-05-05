import type { Account, AccountClose, AccountCreate, AccountUpdate, ApiResponse, BalanceAdjust, Bank } from '@/types'
import client from './client'

export async function listBanks() {
  const res = await client.get<ApiResponse<Bank[]>>('/banks')
  return res.data.data
}

export async function listAccounts() {
  const res = await client.get<ApiResponse<Account[]>>('/accounts')
  return res.data.data
}

export async function createAccount(data: AccountCreate) {
  const res = await client.post<ApiResponse<Account>>('/accounts', data)
  return res.data.data
}

export async function updateAccount(id: number, data: AccountUpdate) {
  const res = await client.put<ApiResponse<Account>>(`/accounts/${id}`, data)
  return res.data.data
}

export async function closeAccount(id: number, data: AccountClose) {
  const res = await client.post<ApiResponse<Account>>(`/accounts/${id}/close`, data)
  return res.data.data
}

export async function adjustAccountBalance(id: number, data: BalanceAdjust) {
  const res = await client.post<ApiResponse<Account>>(`/accounts/${id}/adjust`, data)
  return res.data.data
}

export async function deleteAccount(id: number) {
  await client.delete(`/accounts/${id}`)
}
