import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { ProtectedRoute } from '@/components/auth/ProtectedRoute'
import { AppShell } from '@/components/layout/AppShell'
import { AuthProvider } from '@/context/AuthContext'
import { AccountsPage } from '@/pages/AccountsPage'
import { DashboardPage } from '@/pages/DashboardPage'
import { FolliosPage } from '@/pages/FolliosPage'
import { InstrumentsPage } from '@/pages/InstrumentsPage'
import { InvestmentsPage } from '@/pages/InvestmentsPage'
import { LoginPage } from '@/pages/LoginPage'
import { PlatformAccountsPage } from '@/pages/PlatformAccountsPage'
import { ReportsPage } from '@/pages/ReportsPage'
import { TransactionsPage } from '@/pages/TransactionsPage'

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30_000, retry: 1 } },
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
                <Route path="/reports" element={<ReportsPage />} />
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
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <AppRoutes />
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  )
}
