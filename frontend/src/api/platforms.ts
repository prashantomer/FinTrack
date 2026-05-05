import type { Platform, PlatformAccount, PlatformAccountCreate, PlatformAccountUpdate } from '@/types'
import client from './client'

export async function listPlatforms() {
  const res = await client.get<Platform[]>('/platforms')
  return res.data
}

export async function listPlatformAccounts() {
  const res = await client.get<PlatformAccount[]>('/platform-accounts')
  return res.data
}

export async function createPlatformAccount(data: PlatformAccountCreate) {
  const res = await client.post<PlatformAccount>('/platform-accounts', data)
  return res.data
}

export async function updatePlatformAccount(id: number, data: PlatformAccountUpdate) {
  const res = await client.put<PlatformAccount>(`/platform-accounts/${id}`, data)
  return res.data
}

export async function deletePlatformAccount(id: number) {
  await client.delete(`/platform-accounts/${id}`)
}
