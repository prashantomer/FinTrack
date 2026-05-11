import type { ApiResponse, User } from '@/types'
import client from './client'

export interface TokenPair {
  access_token: string
  refresh_token?: string
  token_type: string
  user?: User
}

export async function login(email: string, password: string): Promise<TokenPair> {
  const res = await client.post<ApiResponse<TokenPair>>('/auth/login', { email, password })
  return res.data.data
}

export async function getMe() {
  const res = await client.get<ApiResponse<User>>('/auth/me')
  return res.data.data
}

export async function updateMe(data: {
  full_name?: string
  password?: string
  currency_code?: string
  currency_locale?: string
  is_dummy?: boolean
}) {
  const res = await client.put<ApiResponse<User>>('/auth/me', data)
  return res.data.data
}
