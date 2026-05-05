import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createElement, type ReactNode } from 'react'
import { http, HttpResponse } from 'msw'
import { describe, it, expect } from 'vitest'
import { server } from '@/test/server'
import { useImports, useImport, useCreateImport } from './useImports'

function makeWrapper() {
  const qc = new QueryClient({
    defaultOptions: { queries: { staleTime: 0, retry: false }, mutations: { retry: false } },
  })
  return function Wrapper({ children }: { children: ReactNode }) {
    return createElement(QueryClientProvider, { client: qc }, children)
  }
}

describe('useImports', () => {
  it('returns items array on success', async () => {
    const { result } = renderHook(() => useImports(), { wrapper: makeWrapper() })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(Array.isArray(result.current.data?.items)).toBe(true)
  })
})

describe('useImport', () => {
  it('is not enabled when id is null — no request is fired', () => {
    const { result } = renderHook(() => useImport(null), { wrapper: makeWrapper() })
    // Query should remain idle / not fetching
    expect(result.current.fetchStatus).toBe('idle')
    expect(result.current.data).toBeUndefined()
  })

  it('fetches and returns the batch when given an id', async () => {
    server.use(
      http.get('/api/v1/imports/1', () =>
        HttpResponse.json({
          success: true,
          code: 200,
          request_id: 'test',
          data: {
            id: 1,
            import_type: 'investments',
            status: 'completed',
            file_name: 'test.csv',
            total_rows: 0,
            processed_rows: 0,
            failed_rows: 0,
            import_version: 1,
            progress_pct: 100,
            import_records: [],
            created_at: '2024-01-01T00:00:00Z',
          },
          meta_data: {},
        }),
      ),
    )

    const { result } = renderHook(() => useImport(1), { wrapper: makeWrapper() })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.id).toBe(1)
    expect(result.current.data?.status).toBe('completed')
  })
})

describe('useCreateImport', () => {
  it('fires POST and returns the created batch', async () => {
    const { result } = renderHook(() => useCreateImport(), { wrapper: makeWrapper() })

    const file = new File(['col1\nval1'], 'test.csv', { type: 'text/csv' })
    result.current.mutate({ importType: 'investments', file })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.id).toBe(1)
    expect(result.current.data?.import_type).toBe('investments')
  })
})
