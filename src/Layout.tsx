import { NavLink, Outlet } from 'react-router-dom'
import { useAuth } from './lib/AuthContext'
import { useLeagueData } from './lib/LeagueDataContext'

const NAV_LINKS = [
  { to: '/', label: 'Home' },
  { to: '/teams', label: 'Teams' },
  { to: '/standings', label: 'Standings' },
  { to: '/trade-hub', label: 'Trade Hub' },
  { to: '/free-agency', label: 'Free Agency' },
  { to: '/scouting', label: 'Draft Central' },
  { to: '/news', label: 'News' },
]

function AuthButton() {
  const { user, profile, loading, signInWithDiscord, signOut } = useAuth()

  if (loading) return <div className="h-9 w-9 shrink-0" />

  if (!user) {
    return (
      <button
        type="button"
        onClick={signInWithDiscord}
        className="shrink-0 whitespace-nowrap rounded-md bg-[var(--accent)] px-3 py-2 text-[12px] font-bold uppercase tracking-wide text-white transition-colors hover:bg-[var(--accent-hover)] sm:px-4 sm:text-[13px]"
      >
        <span className="hidden sm:inline">Sign in with Discord</span>
        <span className="sm:hidden">Sign In</span>
      </button>
    )
  }

  return (
    <div className="flex shrink-0 items-center gap-2 sm:gap-3">
      <div className="flex min-w-0 items-center gap-2">
        {profile?.avatar_url && (
          <img src={profile.avatar_url} alt="" className="h-7 w-7 shrink-0 rounded-full" />
        )}
        <span className="hidden max-w-[10ch] truncate whitespace-nowrap text-[13px] font-bold text-white sm:inline lg:max-w-none">
          {profile?.discord_username ?? 'GM'}
        </span>
        {profile?.is_commissioner && (
          <span className="hidden shrink-0 whitespace-nowrap rounded bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-bold uppercase text-amber-300 md:inline">
            Commissioner
          </span>
        )}
      </div>
      <button
        type="button"
        onClick={signOut}
        className="shrink-0 whitespace-nowrap rounded-md border border-[var(--border)] px-2.5 py-1.5 text-[11px] font-bold uppercase tracking-wide text-[var(--text-muted)] transition-colors hover:border-[var(--accent)] hover:text-white sm:px-3 sm:text-[12px]"
      >
        Sign Out
      </button>
    </div>
  )
}

export default function Layout() {
  const { season } = useLeagueData()
  const { profile } = useAuth()
  const navLinks = profile?.is_commissioner
    ? [...NAV_LINKS, { to: '/commissioner', label: 'Commissioner' }]
    : NAV_LINKS
  return (
    <>
      <header className="sticky top-0 z-40 border-b border-[var(--border)] bg-[var(--bg)]/95 backdrop-blur">
        <div className="mx-auto flex max-w-[1600px] items-center justify-between gap-3 px-4 py-2.5 sm:px-6">
          <NavLink to="/" className="flex shrink-0 items-center gap-2.5 whitespace-nowrap">
            <img src="/logo.jpg" alt="GMCHL" className="h-9 w-9 shrink-0 rounded object-contain" />
            <span className="flex items-baseline gap-2">
              <span className="text-lg font-extrabold tracking-tight text-white">GMCHL</span>
              <span className="hidden text-[11px] font-semibold uppercase tracking-wider text-[var(--text-muted)] md:inline">
                NHL 27 Connected
              </span>
            </span>
          </NavLink>
          <AuthButton />
        </div>
        <nav className="border-t border-[var(--border)]">
          <div className="mx-auto flex max-w-[1600px] items-center gap-5 overflow-x-auto px-4 py-2 sm:px-6">
            {navLinks.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                className={({ isActive }) =>
                  `shrink-0 whitespace-nowrap text-[12px] font-semibold uppercase tracking-wide transition-colors ${
                    isActive ? 'text-white' : 'text-[var(--text-muted)] hover:text-white'
                  }`
                }
              >
                {link.label}
              </NavLink>
            ))}
          </div>
        </nav>
      </header>

      <main className="mx-auto w-full max-w-[1600px] flex-1 px-4 py-6 sm:px-6">
        <Outlet />
      </main>

      <footer className="border-t border-[var(--border)]">
        <div className="mx-auto max-w-[1600px] px-4 py-4 text-center text-[12px] text-[var(--text-muted)] sm:px-6 sm:text-left">
          GMCHL — a fan-run NHL 27 Connected Franchise league, {season}. Player and contract data
          compiled for league use only. Not affiliated with the NHL or EA Sports.
        </div>
      </footer>
    </>
  )
}
