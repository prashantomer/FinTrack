import { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { BarChart3, Briefcase, Building2, CreditCard, FolderOpen, Home, LayoutDashboard, LogOut, PieChart, Settings, Sparkles, TrendingUp, Upload } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/context/AuthContext'
import { SettingsSheet } from './SettingsSheet'

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/accounts', label: 'Bank Accounts', icon: Building2 },
  { to: '/transactions', label: 'Transactions', icon: CreditCard },
  { to: '/platform-accounts', label: 'Platforms', icon: Briefcase },
  { to: '/instruments', label: 'Instruments', icon: BarChart3 },
  { to: '/holdings', label: 'Holdings', icon: FolderOpen },
  { to: '/investments', label: 'Investments', icon: TrendingUp },
  { to: '/portfolio', label: 'Portfolio', icon: PieChart },
  { to: '/reports', label: 'Reports', icon: BarChart3 },
  { to: '/imports', label: 'Imports', icon: Upload },
  { to: '/assistant', label: 'Assistant', icon: Sparkles },
]

export function AppShell({ children }: { children: React.ReactNode }) {
  const { user, logout } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [settingsOpen, setSettingsOpen] = useState(false)

  function handleLogout() {
    logout()
    navigate('/login')
  }

  const displayName = user ? `${user.first_name} ${user.last_name}` : ''

  return (
    <div className="flex h-screen overflow-hidden">
      <aside className="sticky top-0 flex h-screen w-56 shrink-0 flex-col border-r bg-sidebar">
        <Link
          to="/"
          className="flex h-14 items-center px-4 font-semibold text-sidebar-foreground hover:bg-sidebar-accent/60"
          title="Public landing page"
        >
          FinTrack
        </Link>
        <nav className="flex flex-1 flex-col gap-1 p-2">
          {navItems.map(({ to, label, icon: Icon }) => {
            const active = location.pathname === to
            return (
              <Link
                key={to}
                to={to}
                className={`relative flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors ${
                  active
                    ? 'bg-sidebar-accent text-sidebar-accent-foreground font-medium shadow-[inset_2px_0_0_var(--ring)]'
                    : 'text-sidebar-foreground hover:bg-sidebar-accent/60 hover:text-sidebar-accent-foreground'
                }`}
              >
                <Icon size={16} />
                {label}
              </Link>
            )
          })}
        </nav>
        <div className="flex items-center gap-2 p-3">
          <div className="min-w-0 flex-1">
            <p className="truncate text-xs font-medium text-sidebar-foreground">{displayName}</p>
            <p className="truncate text-xs text-muted-foreground">{user?.email}</p>
          </div>
          <Button variant="ghost" size="icon" onClick={() => navigate('/')} title="Home">
            <Home size={16} />
          </Button>
          <Button variant="ghost" size="icon" onClick={() => setSettingsOpen(true)} title="Settings">
            <Settings size={16} />
          </Button>
          <Button variant="ghost" size="icon" onClick={handleLogout} title="Logout">
            <LogOut size={16} />
          </Button>
        </div>
      </aside>
      <SettingsSheet open={settingsOpen} onClose={() => setSettingsOpen(false)} />
      <main className="flex flex-1 min-w-0 flex-col overflow-y-auto">
        {children}
      </main>
    </div>
  )
}
