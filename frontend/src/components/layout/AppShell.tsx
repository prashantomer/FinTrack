import { Link, useLocation, useNavigate } from 'react-router-dom'
import { BarChart3, Briefcase, Building2, CreditCard, FolderOpen, LayoutDashboard, LogOut, TrendingUp } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Separator } from '@/components/ui/separator'
import { useAuth } from '@/context/AuthContext'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/accounts', label: 'Bank Accounts', icon: Building2 },
  { to: '/transactions', label: 'Transactions', icon: CreditCard },
  { to: '/platform-accounts', label: 'Platforms', icon: Briefcase },
  { to: '/instruments', label: 'Instruments', icon: BarChart3 },
  { to: '/follios', label: 'Follios', icon: FolderOpen },
  { to: '/investments', label: 'Investments', icon: TrendingUp },
  { to: '/reports', label: 'Reports', icon: BarChart3 },
]

export function AppShell({ children }: { children: React.ReactNode }) {
  const { user, logout } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()

  function handleLogout() {
    logout()
    navigate('/login')
  }

  const displayName = user ? `${user.first_name} ${user.last_name}` : ''

  return (
    <div className="flex h-screen overflow-hidden">
      <aside className="flex w-56 flex-col border-r bg-sidebar">
        <div className="flex h-14 items-center px-4 font-semibold text-sidebar-foreground">
          FinTrack
        </div>
        <Separator />
        <nav className="flex flex-1 flex-col gap-1 p-2">
          {navItems.map(({ to, label, icon: Icon }) => {
            const active = location.pathname === to
            return (
              <Link
                key={to}
                to={to}
                className={`flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors ${
                  active
                    ? 'bg-sidebar-accent text-sidebar-accent-foreground font-medium'
                    : 'text-sidebar-foreground hover:bg-sidebar-accent/60'
                }`}
              >
                <Icon size={16} />
                {label}
              </Link>
            )
          })}
        </nav>
        <Separator />
        <div className="flex items-center gap-2 p-3">
          <div className="min-w-0 flex-1">
            <p className="truncate text-xs font-medium text-sidebar-foreground">{displayName}</p>
            <p className="truncate text-xs text-muted-foreground">{user?.email}</p>
          </div>
          <Button variant="ghost" size="icon" onClick={handleLogout} title="Logout">
            <LogOut size={16} />
          </Button>
        </div>
      </aside>
      <main className="flex flex-1 flex-col overflow-auto">
        <div className="p-6">{children}</div>
      </main>
    </div>
  )
}
