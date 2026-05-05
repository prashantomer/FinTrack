import type { User } from '@/types'
import axios from 'axios'
import client from './client'

export interface TokenPair {
  access_token: string
  refresh_token: string
  token_type: string
}

export async function login(email: string, password: string): Promise<TokenPair> {
  const form = new URLSearchParams({ username: email, password })
  const res = await client.post<TokenPair>(
    '/auth/login',
    form.toString(),
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
  )
  return res.data
}

export async function refreshTokens(refreshToken: string): Promise<TokenPair> {
  // Use plain axios to bypass the client interceptor — this request has no Bearer token
  const res = await axios.post<TokenPair>('/api/v1/auth/refresh', { refresh_token: refreshToken })
  return res.data
}

export async function getMe() {
  const res = await client.get<User>('/auth/me')
  return res.data
}

export async function updateMe(data: { full_name?: string; password?: string }) {
  const res = await client.put<User>('/auth/me', data)
  return res.data
}
