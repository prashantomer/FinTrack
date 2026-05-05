import type { ApiResponse, Platform, PlatformAccount, PlatformAccountCreate, PlatformAccountUpdate } from '@/types'
import client from './client'

export async function listPlatforms() {
  const res = await client.get<ApiResponse<Platform[]>>('/platforms')
  return res.data.data
}

export async function listPlatformAccounts() {
  const res = await client.get<ApiResponse<PlatformAccount[]>>('/platform-accounts')
  return res.data.data
}

export async function createPlatformAccount(data: PlatformAccountCreate) {
  const res = await client.post<ApiResponse<PlatformAccount>>('/platform-accounts', data)
  return res.data.data
}

export async function updatePlatformAccount(id: number, data: PlatformAccountUpdate) {
  const res = await client.put<ApiResponse<PlatformAccount>>(`/platform-accounts/${id}`, data)
  return res.data.data
}

export async function deletePlatformAccount(id: number) {
  await client.delete(`/platform-accounts/${id}`)
}
