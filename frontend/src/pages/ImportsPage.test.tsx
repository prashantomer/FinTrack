import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, it, expect } from 'vitest'
import { server } from '@/test/server'
import { renderWithProviders } from '@/test/utils'
import { ImportsPage } from './ImportsPage'

describe('ImportsPage', () => {
  it('renders "Imports" heading', async () => {
    renderWithProviders(<ImportsPage />)
    expect(screen.getByRole('heading', { name: /imports/i })).toBeInTheDocument()
  })

  it('shows empty state when API returns no batches', async () => {
    renderWithProviders(<ImportsPage />)
    await waitFor(() =>
      expect(screen.getByText(/no imports yet/i)).toBeInTheDocument(),
    )
  })

  it('shows a batch row when API returns one batch', async () => {
    server.use(
      http.get('/api/v1/imports', () =>
        HttpResponse.json({
          success: true,
          code: 200,
          request_id: 'test',
          data: [
            {
              id: 42,
              import_type: 'investments',
              status: 'completed',
              file_name: 'portfolio.csv',
              total_rows: 10,
              processed_rows: 10,
              failed_rows: 0,
              import_version: 1,
              progress_pct: 100,
              import_records: [],
              created_at: '2024-06-01T00:00:00Z',
            },
          ],
          meta_data: { total: 1, page: 1, page_size: 20 },
        }),
      ),
    )

    renderWithProviders(<ImportsPage />)
    await waitFor(() => expect(screen.getByText('portfolio.csv')).toBeInTheDocument())
    expect(screen.getByText(/investments/i)).toBeInTheDocument()
  })

  it('clicking "New Import" opens the wizard sheet with "New Import" heading', async () => {
    const user = userEvent.setup()
    renderWithProviders(<ImportsPage />)

    const button = screen.getByRole('button', { name: /new import/i })
    await user.click(button)

    await waitFor(() =>
      // The SheetTitle renders "New Import" — check it appears in document
      expect(screen.getAllByText(/new import/i).length).toBeGreaterThan(1),
    )
  })

  it('expandable row: clicking a completed batch shows error details section', async () => {
    server.use(
      http.get('/api/v1/imports', () =>
        HttpResponse.json({
          success: true,
          code: 200,
          request_id: 'test',
          data: [
            {
              id: 7,
              import_type: 'transactions',
              status: 'completed',
              file_name: 'txns.csv',
              total_rows: 5,
              processed_rows: 4,
              failed_rows: 1,
              import_version: 1,
              progress_pct: 100,
              import_records: [
                { row_index: 2, status: 'error', notes: 'Invalid amount' },
              ],
              created_at: '2024-07-01T00:00:00Z',
            },
          ],
          meta_data: { total: 1, page: 1, page_size: 20 },
        }),
      ),
    )

    const user = userEvent.setup()
    renderWithProviders(<ImportsPage />)

    await waitFor(() => expect(screen.getByText('txns.csv')).toBeInTheDocument())

    // Click the batch row to expand
    await user.click(screen.getByText('txns.csv'))

    await waitFor(() =>
      expect(screen.getByText('Invalid amount')).toBeInTheDocument(),
    )
  })
})
