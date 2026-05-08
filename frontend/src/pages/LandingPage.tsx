import { Link } from 'react-router-dom'
import {
  ArrowRight,
  BarChart3,
  Briefcase,
  Building2,
  CreditCard,
  FileSpreadsheet,
  FolderOpen,
  Layers,
  PieChart,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  TrendingUp,
  Upload,
  Wallet,
  Zap,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { FinTrackMark } from '@/components/Logo'
import { useAuth } from '@/context/AuthContext'

const trackables = [
  { icon: Building2, label: 'Bank Accounts', desc: 'Every savings, salary and joint account in one place — balances stay in sync with every credit and debit.' },
  { icon: CreditCard, label: 'Transactions', desc: 'Tag, search and reference every payment. Never lose track of a transfer or an SIP debit again.' },
  { icon: Briefcase, label: 'Platforms', desc: 'Zerodha, Coin, Groww, MFCentral and more — every broker and AMC under one roof.' },
  { icon: TrendingUp, label: 'Investments', desc: 'A complete record of every buy and sell across stocks and mutual funds, with full order history.' },
  { icon: FolderOpen, label: 'Holdings', desc: 'See your live position in every fund and stock — units, average cost and current value, all rolled up.' },
  { icon: Wallet, label: 'Fixed Deposits & PPF', desc: 'Never miss a maturity. Auto-calculated maturity dates with overdue alerts on the dashboard.' },
  { icon: BarChart3, label: 'Live Prices', desc: 'Stocks and mutual fund NAVs refreshed daily so every value you see is today’s value.' },
  { icon: PieChart, label: 'Portfolio', desc: 'True profit and loss — what you paid, what it’s worth today, what’s realised vs still in the market.' },
]

export function LandingPage() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Nav />
      <Hero />
      <Trust />
      <Features />
      <AIAssistantSection />
      <ImportSection />
      <BottomCTA />
      <Footer />
    </div>
  )
}

function Nav() {
  return (
    <header className="sticky top-0 z-30 border-b bg-background/80 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-2 font-semibold tracking-tight">
          <FinTrackMark size={24} />
          <span>
            <span>Fin</span>
            <span className="text-muted-foreground">Track</span>
          </span>
        </Link>
        <nav className="hidden items-center gap-6 text-sm text-muted-foreground md:flex">
          <a href="#features" className="hover:text-foreground">Features</a>
          <a href="#assistant" className="hover:text-foreground">Assistant</a>
          <a href="#imports" className="hover:text-foreground">Imports</a>
        </nav>
        <div className="flex items-center gap-2">
          <AccountButton size="sm" />
        </div>
      </div>
    </header>
  )
}

function AccountButton({
  size = 'sm',
  className,
}: {
  size?: 'sm' | 'lg'
  className?: string
}) {
  const { user, isLoading } = useAuth()
  if (isLoading) {
    return (
      <Button size={size} disabled className={className}>
        …
      </Button>
    )
  }
  const to = user ? '/dashboard' : '/login'
  const label = user ? 'My Account' : 'Sign in'
  return (
    <Link to={to}>
      <Button size={size} className={className}>
        {label}
        <ArrowRight className="ml-1.5 size-4" />
      </Button>
    </Link>
  )
}

function Hero() {
  return (
    <section className="relative overflow-hidden border-b">
      <GridBg />
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <div className="flex flex-col items-center text-center">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border bg-background/60 px-3 py-1 text-xs text-muted-foreground backdrop-blur">
            <Sparkles className="size-3" />
            Personal finance that actually adds up
          </div>
          <h1 className="max-w-3xl text-5xl font-semibold tracking-tight sm:text-6xl">
            One place for{' '}
            <span className="bg-gradient-to-br from-foreground to-muted-foreground bg-clip-text text-transparent">
              every rupee
            </span>{' '}
            you own.
          </h1>
          <p className="mt-6 max-w-2xl text-lg text-muted-foreground">
            Bank accounts, mutual funds, stocks, fixed deposits and PPF — all together, always
            in sync. Ask plain-English questions, drop in your broker statements, and finally see
            the picture you&apos;ve been stitching together by hand.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <AccountButton size="lg" className="h-10 px-4" />
            <a href="#features">
              <Button size="lg" variant="outline" className="h-10 px-4">
                See what it tracks
              </Button>
            </a>
          </div>
          <div className="mt-12 w-full max-w-4xl">
            <PreviewCard />
          </div>
        </div>
      </div>
    </section>
  )
}

function GridBg() {
  return (
    <div
      aria-hidden
      className="pointer-events-none absolute inset-0 [background-image:linear-gradient(to_right,oklch(0.87_0_0/0.4)_1px,transparent_1px),linear-gradient(to_bottom,oklch(0.87_0_0/0.4)_1px,transparent_1px)] [background-size:48px_48px] [mask-image:radial-gradient(ellipse_at_center,black_30%,transparent_75%)]"
    />
  )
}

function PreviewCard() {
  const stats = [
    { label: 'Net Worth', value: '₹ 42,18,540', delta: '+₹ 12,300 today' },
    { label: 'Investments', value: '₹ 28,40,120', delta: '8 platforms' },
    { label: 'Cash & FDs', value: '₹ 13,78,420', delta: '5 accounts' },
    { label: 'Unrealized P/L', value: '+₹ 3,02,180', delta: '+12.1%' },
  ]
  return (
    <div className="rounded-xl border bg-card p-1 shadow-sm">
      <div className="rounded-lg border bg-background p-6">
        <div className="mb-4 flex items-center justify-between">
          <div className="text-sm font-medium">Dashboard</div>
          <div className="text-xs text-muted-foreground">Today · 7 May 2026</div>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {stats.map((s) => (
            <div key={s.label} className="rounded-md border bg-card p-3 text-left">
              <div className="text-xs text-muted-foreground">{s.label}</div>
              <div className="mt-1 text-lg font-semibold tabular-nums">{s.value}</div>
              <div className="text-[11px] text-muted-foreground">{s.delta}</div>
            </div>
          ))}
        </div>
        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <div className="rounded-md border bg-card p-3 sm:col-span-2">
            <div className="text-xs font-medium">Cash flow · last 6 months</div>
            <FakeChart />
          </div>
          <div className="rounded-md border bg-card p-3">
            <div className="text-xs font-medium">Top holdings</div>
            <ul className="mt-2 space-y-1.5 text-xs">
              {[
                ['HDFCFLEXI', '+18.4%'],
                ['INFY', '+9.1%'],
                ['PARAGFLEXI', '+15.2%'],
                ['SBIN', '−2.3%'],
              ].map(([k, v]) => (
                <li key={k} className="flex items-center justify-between">
                  <span className="font-mono">{k}</span>
                  <span className="tabular-nums text-muted-foreground">{v}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}

function FakeChart() {
  const bars = [40, 62, 35, 78, 55, 90, 70, 85, 50, 72, 60, 95]
  return (
    <div className="mt-3 flex h-20 items-end gap-1">
      {bars.map((h, i) => (
        <div
          key={i}
          className="flex-1 rounded-sm bg-foreground/80"
          style={{ height: `${h}%`, opacity: 0.3 + (i / bars.length) * 0.7 }}
        />
      ))}
    </div>
  )
}

function Trust() {
  return (
    <section className="border-b bg-muted/30">
      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-6 py-10 text-sm sm:grid-cols-4">
        {[
          { icon: Layers, label: 'Every asset, one view' },
          { icon: ShieldCheck, label: 'Your data stays yours' },
          { icon: RefreshCw, label: 'Live prices, every day' },
          { icon: Sparkles, label: 'AI answers in plain English' },
        ].map(({ icon: Icon, label }) => (
          <div key={label} className="flex items-center gap-2 text-muted-foreground">
            <Icon className="size-4" />
            <span>{label}</span>
          </div>
        ))}
      </div>
    </section>
  )
}

function Features() {
  return (
    <section id="features" className="border-b">
      <div className="mx-auto max-w-6xl px-6 py-20">
        <SectionHeading
          eyebrow="What you can track"
          title="Built around how Indian portfolios actually work"
          subtitle="From your salary account to your last SIP — every asset has a home, and every balance is up to date."
        />
        <div className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {trackables.map((t) => (
            <FeatureCard key={t.label} icon={t.icon} title={t.label} desc={t.desc} />
          ))}
        </div>
      </div>
    </section>
  )
}

function FeatureCard({
  icon: Icon,
  title,
  desc,
}: {
  icon: typeof Building2
  title: string
  desc: string
}) {
  return (
    <div className="group rounded-xl border bg-card p-5 transition-all hover:border-foreground/20 hover:shadow-sm">
      <div className="mb-3 flex size-9 items-center justify-center rounded-md border bg-background">
        <Icon className="size-4" />
      </div>
      <div className="text-sm font-semibold">{title}</div>
      <div className="mt-1.5 text-xs leading-relaxed text-muted-foreground">{desc}</div>
    </div>
  )
}

function AIAssistantSection() {
  return (
    <section id="assistant" className="border-b">
      <div className="mx-auto grid max-w-6xl gap-12 px-6 py-20 lg:grid-cols-2 lg:items-center">
        <div>
          <Eyebrow icon={Sparkles}>AI Assistant</Eyebrow>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">
            Ask your portfolio anything.
          </h2>
          <p className="mt-4 text-muted-foreground">
            Get straight answers about your own finances. The assistant only sees your data,
            sticks to financial questions, and turns broker statements into ready-to-import
            files in seconds.
          </p>
          <ul className="mt-6 space-y-3 text-sm">
            {[
              'Plain-English answers about your transactions, holdings and gains.',
              'Strictly your own books — never another household’s data.',
              'Pin important answers so they’re always part of the next conversation.',
              'Drop a broker statement, the assistant cleans it up for one-click import.',
            ].map((line) => (
              <li key={line} className="flex items-start gap-2">
                <Zap className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
                <span className="text-muted-foreground">{line}</span>
              </li>
            ))}
          </ul>
          <div className="mt-8 flex gap-2">
            <AccountButton size="sm" />
          </div>
        </div>
        <ChatMock />
      </div>
    </section>
  )
}

function ChatMock() {
  return (
    <div className="rounded-xl border bg-card shadow-sm">
      <div className="flex items-center gap-2 border-b px-4 py-2.5 text-xs text-muted-foreground">
        <div className="flex size-5 items-center justify-center rounded-md bg-foreground text-background">
          <Sparkles className="size-3" />
        </div>
        Your finance assistant
      </div>
      <div className="space-y-4 p-5 text-sm">
        <UserBubble>How much did I invest in HDFC Flexi Cap last quarter?</UserBubble>
        <ToolChip>
          <Wallet className="size-3" /> Looking up your investments…
        </ToolChip>
        <AssistantBubble>
          <p>You made <strong>3 SIP installments</strong> totaling <strong>₹ 30,000</strong> in HDFC Flexi Cap.</p>
          <table className="mt-3 w-full text-xs">
            <thead className="text-muted-foreground">
              <tr>
                <th className="py-1 text-left font-normal">Date</th>
                <th className="py-1 text-right font-normal">Units</th>
                <th className="py-1 text-right font-normal">NAV</th>
                <th className="py-1 text-right font-normal">Amount</th>
              </tr>
            </thead>
            <tbody className="font-mono tabular-nums">
              <tr className="border-t">
                <td className="py-1">2026-01-05</td>
                <td className="py-1 text-right">62.41</td>
                <td className="py-1 text-right">160.21</td>
                <td className="py-1 text-right">₹ 10,000</td>
              </tr>
              <tr className="border-t">
                <td className="py-1">2026-02-05</td>
                <td className="py-1 text-right">61.10</td>
                <td className="py-1 text-right">163.66</td>
                <td className="py-1 text-right">₹ 10,000</td>
              </tr>
              <tr className="border-t">
                <td className="py-1">2026-03-05</td>
                <td className="py-1 text-right">59.04</td>
                <td className="py-1 text-right">169.38</td>
                <td className="py-1 text-right">₹ 10,000</td>
              </tr>
            </tbody>
          </table>
        </AssistantBubble>
      </div>
    </div>
  )
}

function ImportSection() {
  return (
    <section id="imports" className="border-b bg-muted/30">
      <div className="mx-auto grid max-w-6xl gap-12 px-6 py-20 lg:grid-cols-2 lg:items-center">
        <ImportMock />
        <div>
          <Eyebrow icon={Upload}>CSV Imports</Eyebrow>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">
            From broker statement to ledger entries — in one upload.
          </h2>
          <p className="mt-4 text-muted-foreground">
            Drop a Coin, Zerodha or bank CSV. Every row is checked, every account matched, and
            if anything looks off, nothing gets imported — your books stay clean.
          </p>
          <ul className="mt-6 space-y-3 text-sm">
            {[
              ['Bank statements', 'All your credits and debits, ready to tag and search.'],
              ['Investment trades', 'Every buy and sell, automatically matched to the right fund or stock.'],
              ['Fixed deposits & PPF', 'Maturity dates calculated for you. Overdue ones surface on the dashboard.'],
            ].map(([head, body]) => (
              <li key={head} className="flex items-start gap-3 rounded-md border bg-background p-3">
                <FileSpreadsheet className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
                <div>
                  <div className="text-sm font-medium">{head}</div>
                  <div className="text-xs text-muted-foreground">{body}</div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}

function ImportMock() {
  const rows = [
    ['2026-04-08', 'BUY', 'HDFCFLEXI', '12.41', '₹ 5,000', 'OK'],
    ['2026-04-15', 'BUY', 'PARAGFLEXI', '8.92', '₹ 5,000', 'OK'],
    ['2026-04-22', 'SELL', 'AXISBLUECHIP', '14.30', '₹ 7,500', 'OK'],
    ['2026-04-29', 'BUY', 'INFY', '3.00', '₹ 4,500', 'OK'],
  ]
  return (
    <div className="rounded-xl border bg-card shadow-sm">
      <div className="flex items-center justify-between border-b px-4 py-2.5 text-xs">
        <div className="flex items-center gap-2 text-muted-foreground">
          <FileSpreadsheet className="size-3.5" />
          coin-mf-orders.csv
        </div>
        <span className="rounded-full bg-foreground/10 px-2 py-0.5 text-[10px] font-medium">
          411 rows · processed
        </span>
      </div>
      <div className="p-4">
        <table className="w-full text-xs">
          <thead className="text-muted-foreground">
            <tr>
              <th className="py-1.5 text-left font-normal">Date</th>
              <th className="py-1.5 text-left font-normal">Side</th>
              <th className="py-1.5 text-left font-normal">Instrument</th>
              <th className="py-1.5 text-right font-normal">Units</th>
              <th className="py-1.5 text-right font-normal">Amount</th>
              <th className="py-1.5 text-right font-normal">Status</th>
            </tr>
          </thead>
          <tbody className="font-mono tabular-nums">
            {rows.map((r) => (
              <tr key={r[0]} className="border-t">
                <td className="py-1.5">{r[0]}</td>
                <td className="py-1.5">
                  <span
                    className={
                      r[1] === 'BUY'
                        ? 'rounded-sm bg-foreground/10 px-1.5 py-0.5 text-[10px] font-medium'
                        : 'rounded-sm border px-1.5 py-0.5 text-[10px] font-medium'
                    }
                  >
                    {r[1]}
                  </span>
                </td>
                <td className="py-1.5">{r[2]}</td>
                <td className="py-1.5 text-right">{r[3]}</td>
                <td className="py-1.5 text-right">{r[4]}</td>
                <td className="py-1.5 text-right text-muted-foreground">{r[5]}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function BottomCTA() {
  return (
    <section className="border-b">
      <div className="mx-auto max-w-4xl px-6 py-24 text-center">
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          Stop bouncing between apps.
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-muted-foreground">
          One place for your bank accounts, mutual funds, fixed deposits, stocks and PPF — and an
          assistant that helps you make sense of all of it.
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <AccountButton size="lg" className="h-10 px-4" />
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="bg-background">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-8 text-xs text-muted-foreground sm:flex-row">
        <div className="flex items-center gap-2">
          <FinTrackMark size={18} />
          <span><span>Fin</span><span className="text-muted-foreground">Track</span></span>
          <span className="text-muted-foreground/60">·</span>
          <span>all your money in one ledger</span>
        </div>
        <div>Made for personal investors who want their own numbers.</div>
      </div>
    </footer>
  )
}

function SectionHeading({
  eyebrow,
  title,
  subtitle,
}: {
  eyebrow: string
  title: string
  subtitle: string
}) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      <div className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
        {eyebrow}
      </div>
      <h2 className="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">{title}</h2>
      <p className="mt-4 text-muted-foreground">{subtitle}</p>
    </div>
  )
}

function Eyebrow({ icon: Icon, children }: { icon: typeof Sparkles; children: React.ReactNode }) {
  return (
    <div className="inline-flex items-center gap-2 rounded-full border bg-background px-3 py-1 text-xs">
      <Icon className="size-3" />
      <span className="font-medium">{children}</span>
    </div>
  )
}

function UserBubble({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex justify-end">
      <div className="max-w-[80%] rounded-2xl rounded-br-sm bg-foreground px-4 py-2 text-sm text-background">
        {children}
      </div>
    </div>
  )
}

function AssistantBubble({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex justify-start">
      <div className="max-w-[90%] rounded-2xl rounded-bl-sm border bg-background px-4 py-3 text-sm">
        {children}
      </div>
    </div>
  )
}

function ToolChip({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex justify-start">
      <div className="inline-flex items-center gap-1.5 rounded-md border bg-muted px-2 py-1 font-mono text-[11px] text-muted-foreground">
        {children}
      </div>
    </div>
  )
}
