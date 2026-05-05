import type { Investment, InvestmentListResponse, InvestmentType } from '@/types'
import client from './client'

export async function listInvestments(type?: InvestmentType[]) {
  const params = type?.length ? { type } : {}
  const res = await client.get<InvestmentListResponse>('/investments/', { params })
  return res.data
}

export async function getInvestment(id: number) {
  const res = await client.get<Investment>(`/investments/${id}`)
  return res.data
}

export async function createInvestment(data: Partial<Investment> & { type: InvestmentType; name: string; amount_invested: number; purchase_date: string }) {
  const res = await client.post<Investment>('/investments/', data)
  return res.data
}

export async function updateInvestment(id: number, data: Partial<Investment>) {
  const res = await client.put<Investment>(`/investments/${id}`, data)
  return res.data
}

export async function deleteInvestment(id: number) {
  await client.delete(`/investments/${id}`)
}
