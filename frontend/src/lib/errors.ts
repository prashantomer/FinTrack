import type { AxiosError } from 'axios'

export function getErrorMessage(err: unknown, fallback = 'Something went wrong'): string {
  if (!err || typeof err !== 'object') return fallback
  const axiosErr = err as AxiosError<{ error?: string; errors?: Record<string, string[]> }>
  const data = axiosErr.response?.data
  if (typeof data?.error === 'string') return data.error
  if (data?.errors) {
    const messages = Object.entries(data.errors).flatMap(([field, msgs]) =>
      msgs.map((m) => `${field} ${m}`)
    )
    if (messages.length > 0) return messages.join('; ')
  }
  return fallback
}
