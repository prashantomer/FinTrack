import axios from 'axios'
import { refreshTokens } from './auth'

const client = axios.create({ baseURL: '/api/v1' })

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Queue of callers waiting for a token refresh to complete
let isRefreshing = false
let queue: Array<{ resolve: (token: string) => void; reject: (err: unknown) => void }> = []

function flushQueue(err: unknown, token: string | null) {
  queue.forEach(p => err ? p.reject(err) : p.resolve(token!))
  queue = []
}

client.interceptors.response.use(
  (res) => res,
  async (err) => {
    const original = err.config

    // Only handle 401s; skip if this request is already a retry
    if (err.response?.status !== 401 || original._retry) {
      return Promise.reject(err)
    }

    const storedRefresh = localStorage.getItem('refresh_token')
    if (!storedRefresh) {
      localStorage.removeItem('token')
      window.location.href = '/login'
      return Promise.reject(err)
    }

    // If a refresh is already in flight, queue this request
    if (isRefreshing) {
      return new Promise<string>((resolve, reject) => {
        queue.push({ resolve, reject })
      }).then((newToken) => {
        original.headers.Authorization = `Bearer ${newToken}`
        return client(original)
      })
    }

    original._retry = true
    isRefreshing = true

    try {
      const tokens = await refreshTokens(storedRefresh)
      localStorage.setItem('token', tokens.access_token)
      localStorage.setItem('refresh_token', tokens.refresh_token)
      flushQueue(null, tokens.access_token)
      original.headers.Authorization = `Bearer ${tokens.access_token}`
      return client(original)
    } catch (refreshErr) {
      flushQueue(refreshErr, null)
      localStorage.removeItem('token')
      localStorage.removeItem('refresh_token')
      window.location.href = '/login'
      return Promise.reject(refreshErr)
    } finally {
      isRefreshing = false
    }
  }
)

export default client
