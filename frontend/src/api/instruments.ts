import type { Instrument, InstrumentCreate, InvestmentType } from '@/types'
import client from './client'

export async function listInstruments(params: { type?: InvestmentType; search?: string } = {}) {
  const res = await client.get<Instrument[]>('/instruments/', { params })
  return res.data
}

export async function listTrackedInstruments() {
  const res = await client.get<Instrument[]>('/instruments/tracked')
  return res.data
}

export async function createInstrument(data: InstrumentCreate) {
  const res = await client.post<Instrument>('/instruments/', data)
  return res.data
}

export async function trackInstrument(id: number) {
  await client.post(`/instruments/${id}/track`)
}

export async function untrackInstrument(id: number) {
  await client.delete(`/instruments/${id}/track`)
}
