import { useEffect } from 'react'
import { MutationCache, QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Toaster, toast } from 'sonner'
import { ProtectedRoute } from '@/components/auth/ProtectedRoute'
import { AppShell } from '@/components/layout/AppShell'
import { ErrorBoundary } from '@/components/ErrorBoundary'
import { setupErrorReporter } from '@/lib/errorReporter'
import { AuthProvider } from '@/context/AuthContext'
import { getErrorMessage } from '@/lib/errors'
import { AccountsPage } from '@/pages/AccountsPage'
import { DashboardPage } from '@/pages/DashboardPage'
import { FolliosPage } from '@/pages/FolliosPage'
import { InstrumentsPage } from '@/pages/InstrumentsPage'
import { InvestmentsPage } from '@/pages/InvestmentsPage'
import { LoginPage } from '@/pages/LoginPage'
import { PlatformAccountsPage } from '@/pages/PlatformAccountsPage'
import { PortfolioPage } from '@/pages/PortfolioPage'
import { ReportsPage } from '@/pages/ReportsPage'
import { TransactionsPage } from '@/pages/TransactionsPage'
import { ImportsPage } from '@/pages/ImportsPage'

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30_000, retry: 1 } },
  mutationCache: new MutationCache({
    onError: (err) => toast.error(getErrorMessage(err)),
  }),
})

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <AppShell>
              <Routes>
                <Route path="/" element={<DashboardPage />} />
                <Route path="/accounts" element={<AccountsPage />} />
                <Route path="/transactions" element={<TransactionsPage />} />
                <Route path="/platform-accounts" element={<PlatformAccountsPage />} />
                <Route path="/instruments" element={<InstrumentsPage />} />
                <Route path="/follios" element={<FolliosPage />} />
                <Route path="/investments" element={<InvestmentsPage />} />
                <Route path="/portfolio" element={<PortfolioPage />} />
                <Route path="/reports" element={<ReportsPage />} />
                <Route path="/imports" element={<ImportsPage />} />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </AppShell>
          </ProtectedRoute>
        }
      />
    </Routes>
  )
}

export default function App() {
  useEffect(() => { setupErrorReporter() }, [])

  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <BrowserRouter>
            <AppRoutes />
            <Toaster position="bottom-right" richColors closeButton />
          </BrowserRouter>
        </AuthProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  )
}
