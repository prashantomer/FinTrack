import type { ApiResponse, Instrument, InstrumentCreate, InstrumentPage, InvestmentType, UserInstrument } from '@/types'
import client from './client'

export async function listInstruments(
  params: { type?: InvestmentType; search?: string; cursor?: number; limit?: number } = {}
): Promise<InstrumentPage> {
  const res = await client.get<ApiResponse<Instrument[]>>('/instruments', { params })
  return {
    items:       res.data.data,
    next_cursor: (res.data.meta_data.next_cursor as number | null) ?? null,
    has_more:    (res.data.meta_data.has_more as boolean) ?? false,
  }
}

export async function listInstrumentTypes() {
  const res = await client.get<ApiResponse<string[]>>('/instruments/types')
  return res.data.data as InvestmentType[]
}

export async function listTrackedInstruments() {
  const res = await client.get<ApiResponse<Instrument[]>>('/instruments/tracked')
  return res.data.data
}

export async function createInstrument(data: InstrumentCreate) {
  const res = await client.post<ApiResponse<Instrument>>('/instruments', data)
  return res.data.data
}

export async function trackInstrument(id: number) {
  await client.post(`/instruments/${id}/track`)
}

export async function untrackInstrument(id: number) {
  await client.delete(`/instruments/${id}/track`)
}

export async function listUserInstruments() {
  const res = await client.get<ApiResponse<UserInstrument[]>>('/instruments/user-instruments')
  return res.data.data
}
