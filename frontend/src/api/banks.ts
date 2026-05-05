import type { Account, AccountClose, AccountCreate, AccountUpdate, BalanceAdjust, Bank } from '@/types'
import client from './client'

export async function listBanks() {
  const res = await client.get<Bank[]>('/banks')
  return res.data
}

export async function listAccounts() {
  const res = await client.get<Account[]>('/accounts')
  return res.data
}

export async function createAccount(data: AccountCreate) {
  const res = await client.post<Account>('/accounts', data)
  return res.data
}

export async function updateAccount(id: number, data: AccountUpdate) {
  const res = await client.put<Account>(`/accounts/${id}`, data)
  return res.data
}

export async function closeAccount(id: number, data: AccountClose) {
  const res = await client.post<Account>(`/accounts/${id}/close`, data)
  return res.data
}

export async function adjustAccountBalance(id: number, data: BalanceAdjust) {
  const res = await client.post<Account>(`/accounts/${id}/adjust`, data)
  return res.data
}

export async function deleteAccount(id: number) {
  await client.delete(`/accounts/${id}`)
}
