import { type ReactNode } from 'react'
import { render } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { staleTime: 0, retry: false },
      mutations: { retry: false },
    },
  })
}

interface RenderOptions {
  initialEntries?: string[]
}

export function renderWithProviders(
  ui: ReactNode,
  { initialEntries = ['/'] }: RenderOptions = {},
) {
  const queryClient = makeQueryClient()

  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={initialEntries}>
          {children}
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  return render(ui, { wrapper: Wrapper })
}
