import type { BalanceAdjust, PPFDeposit, TermAccount, TermAccountClose, TermAccountCreate, TermAccountUpdate } from '@/types'
import client from './client'

export async function listTermAccounts() {
  const res = await client.get<TermAccount[]>('/term-accounts/')
  return res.data
}

export async function createTermAccount(data: TermAccountCreate) {
  const res = await client.post<TermAccount>('/term-accounts/', data)
  return res.data
}

export async function depositPPF(id: number, data: PPFDeposit) {
  const res = await client.post<TermAccount>(`/term-accounts/${id}/deposit`, data)
  return res.data
}

export async function updateTermAccount(id: number, data: TermAccountUpdate) {
  const res = await client.put<TermAccount>(`/term-accounts/${id}`, data)
  return res.data
}

export async function adjustTermAccountBalance(id: number, data: BalanceAdjust) {
  const res = await client.post<TermAccount>(`/term-accounts/${id}/adjust`, data)
  return res.data
}

export async function closeTermAccount(id: number, data: TermAccountClose) {
  const res = await client.post<TermAccount>(`/term-accounts/${id}/close`, data)
  return res.data
}
