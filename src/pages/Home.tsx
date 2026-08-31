import { Link } from 'react-router-dom'
import { Card, StatTile, TeamBadge, CapSpaceText, CapProgressBar, Button } from '../components/ui'
import { formatCompactMoney, formatMoney } from '../lib/format'
import { useAuth } from '../lib/AuthContext'
import { useTeamClaims } from '../lib/useTeamClaims'
import { useLeagueData } from '../lib/LeagueDataContext'
import { useTrades } from '../lib/useTrades'
import { useFreeAgentOffers } from '../lib/useFreeAgentOffers'
import { useNews } from '../lib/useNews'
import type { Team } from '../types'

function timeAgo(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diffMs / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}

function MyTeamNotifications({ teamId }: { teamId: string }) {
  const { season, tradeDeadline, players, freeAgents } = useLeagueData()
  const { profile } = useAuth()
  const { trades } = useTrades()
  const { offers } = useFreeAgentOffers()
  const { articles } = useNews()

  const isCommissioner = Boolean(profile?.is_commissioner)

  const myTrades = trades.filter(
    (t) => (t.fromTeamId === teamId || t.toTeamId === teamId) && (t.status === 'pending' || t.status === 'gm_approved'),
  )
  const actionableTrades = myTrades.filter(
    (t) => (t.status === 'pending' && t.toTeamId === teamId) || (t.status === 'gm_approved' && isCommissioner),
  )
  const waitingTrades = myTrades.filter((t) => !actionableTrades.includes(t))

  const rfaAlerts = offers
    .filter((o) => o.status === 'pending' && o.teamId !== teamId)
    .map((o) => ({ offer: o, fa: freeAgents.find((f) => f.id === o.freeAgentId) }))
    .filter((x) => x.fa && x.fa.status === 'RFA' && !x.fa.rfaWaived && x.fa.lastTeam === teamId)

  const expiring = players.filter((p) => p.teamId === teamId && p.expiryYear === season)
  const retiring = players.filter((p) => p.teamId === teamId && p.retirementAnnouncedSeason === season)

  const teamNews = articles.filter((a) => a.teamIds.includes(teamId)).slice(0, 5)

  const deadlineMs = tradeDeadline ? new Date(tradeDeadline).getTime() - Date.now() : null
  const deadlineSoon = deadlineMs !== null && deadlineMs > 0 && deadlineMs < 1000 * 60 * 60 * 24 * 7

  const hasAnything =
    actionableTrades.length > 0 ||
    waitingTrades.length > 0 ||
    rfaAlerts.length > 0 ||
    expiring.length > 0 ||
    retiring.length > 0 ||
    teamNews.length > 0 ||
    deadlineSoon

  if (!hasAnything) return null

  return (
    <Card className="p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
        Team Notifications
      </p>
      <div className="mt-3 space-y-2">
        {actionableTrades.map((t) => (
          <Link
            key={t.id}
            to="/trade-hub"
            className="flex items-center justify-between rounded-md border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-[13px] text-amber-200 hover:bg-amber-500/15"
          >
            <span>A trade needs your approval</span>
            <span className="font-bold">Review →</span>
          </Link>
        ))}
        {waitingTrades.map((t) => (
          <div
            key={t.id}
            className="flex items-center justify-between rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-[var(--text-muted)]"
          >
            <span>Trade proposed — waiting on the other side</span>
          </div>
        ))}
        {rfaAlerts.map(({ offer, fa }) => (
          <Link
            key={offer.id}
            to="/free-agency"
            className="flex items-center justify-between rounded-md border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-[13px] text-amber-200 hover:bg-amber-500/15"
          >
            <span>Outside offer on your former RFA {fa?.name} — waive or let it stand</span>
            <span className="font-bold">Review →</span>
          </Link>
        ))}
        {expiring.length > 0 && (
          <div className="flex items-center justify-between rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-[var(--text-muted)]">
            <span>
              {expiring.length} contract{expiring.length > 1 ? 's' : ''} expiring after {season}:{' '}
              {expiring.map((p) => p.name).join(', ')}
            </span>
          </div>
        )}
        {retiring.length > 0 && (
          <div className="flex items-center justify-between rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-[var(--text-muted)]">
            <span>
              {retiring.map((p) => p.name).join(', ')} plan{retiring.length === 1 ? 's' : ''} to retire at
              the end of {season}
            </span>
          </div>
        )}
        {deadlineSoon && (
          <Link
            to="/trade-hub"
            className="flex items-center justify-between rounded-md border border-sky-500/30 bg-sky-500/10 px-3 py-2 text-[13px] text-sky-300 hover:bg-sky-500/15"
          >
            <span>Trade deadline is coming up — {new Date(tradeDeadline!).toLocaleDateString()}</span>
          </Link>
        )}
        {teamNews.map((a) => (
          <Link
            key={a.id}
            to="/news"
            className="flex items-center justify-between rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white hover:bg-[var(--bg-panel-alt)]"
          >
            <span>{a.headline}</span>
            <span className="text-[var(--text-muted)]">{timeAgo(a.createdAt)}</span>
          </Link>
        ))}
      </div>
    </Card>
  )
}

function MyTeamCard({ salaryCap }: { salaryCap: number }) {
  const { user } = useAuth()
  const { claims } = useTeamClaims()
  const { teamsById, playersByTeam } = useLeagueData()

  if (!user) return null
  const myClaim = [...claims.values()].find((c) => c.userId === user.id)
  if (!myClaim) return null

  const team = teamsById.get(myClaim.teamId)
  if (!team) return null

  const topContracts = [...playersByTeam(team.id)].sort((a, b) => b.capHit - a.capHit).slice(0, 5)

  return (
    <div className="space-y-4">
      <div
        className="overflow-hidden rounded-xl border border-[var(--border)]"
        style={{ background: `linear-gradient(120deg, ${team.color}33, var(--bg-panel) 70%)` }}
      >
        <div className="flex flex-wrap items-start justify-between gap-6 px-6 py-6">
          <div className="flex items-center gap-4">
            <TeamBadge team={team} size={52} />
            <div>
              <p className="text-[11px] font-bold uppercase tracking-widest text-slate-200">
                Your Club
              </p>
              <h2 className="text-2xl font-extrabold tracking-tight text-white">
                {team.city} {team.name}
              </h2>
            </div>
          </div>
          <div className="min-w-[220px]">
            <p className="mb-1 text-[11px] font-bold uppercase tracking-widest text-slate-200">
              Cap Situation
            </p>
            <CapProgressBar used={team.capUsed} cap={salaryCap} />
            <div className="mt-1 flex justify-between text-[12px] font-semibold">
              <span className="text-slate-200">{formatMoney(team.capUsed)} used</span>
              <CapSpaceText value={team.capSpace} compact={`${formatMoney(team.capSpace)} space`} />
            </div>
          </div>
        </div>

        <div className="border-t border-[var(--border)] bg-[var(--bg-panel)]/60 px-6 py-4">
          <p className="mb-2 text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
            Top Contracts
          </p>
          <div className="flex flex-wrap gap-4">
            {topContracts.map((p) => (
              <div key={p.id} className="text-[13px]">
                <span className="font-bold text-white">{p.name}</span>{' '}
                <span className="text-[var(--text-muted)]">{p.position}</span>
                <span className="ml-1.5 font-semibold text-white">{formatMoney(p.capHit)}</span>
              </div>
            ))}
          </div>
          <div className="mt-4 flex gap-3">
            <Link to={`/teams/${team.id}`}>
              <Button>Manage My Team</Button>
            </Link>
            <Link to="/trade-hub">
              <Button variant="secondary">Trade Hub</Button>
            </Link>
          </div>
        </div>
      </div>

      <MyTeamNotifications teamId={team.id} />
    </div>
  )
}

export default function Home() {
  const { claims } = useTeamClaims()
  const { loading, teams, season, salaryCap } = useLeagueData()
  const { articles, loading: newsLoading } = useNews()

  if (loading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  const mostCapSpace = [...teams].sort((a: Team, b: Team) => b.capSpace - a.capSpace).slice(0, 6)
  const recentNews = articles.slice(0, 5)

  return (
    <div className="space-y-6">
      <MyTeamCard salaryCap={salaryCap} />

      <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-gradient-to-br from-[#123a63] via-[#0f2a49] to-[var(--bg-panel)] px-6 py-10 sm:px-10">
        <div className="flex flex-wrap items-center gap-6">
          <img src="/logo.jpg" alt="GMCHL" className="h-24 w-24 shrink-0 rounded-lg object-cover shadow-lg sm:h-28 sm:w-28" />
          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest text-sky-300">
              NHL 27 Connected Franchise · {season}
            </p>
            <h1 className="mt-2 text-3xl font-extrabold tracking-tight text-white sm:text-4xl">
              GMCHL League Hub
            </h1>
            <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-slate-200">
              Every roster, every contract, every dollar of cap space, kept year over year. Claim
              your club, manage your roster, and run the league from one place.
            </p>
            <div className="mt-6 flex gap-3">
              <Link to="/teams">
                <Button>Browse Teams</Button>
              </Link>
              <Link to="/teams">
                <Button variant="secondary">Cap Sheet</Button>
              </Link>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatTile label="Clubs" value={teams.length} />
        <StatTile label="GMs Claimed" value={`${claims.size} / ${teams.length}`} />
        <StatTile label="Salary Cap" value={formatCompactMoney(salaryCap)} />
        <StatTile label="Season" value={season} />
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <h2 className="mb-3 text-sm font-extrabold uppercase tracking-wide text-white">
            League News
          </h2>
          {newsLoading ? (
            <Card className="px-5 py-6 text-[14px] text-[var(--text-muted)]">Loading…</Card>
          ) : recentNews.length === 0 ? (
            <Card className="px-5 py-6 text-[14px] text-[var(--text-muted)]">
              No news yet. Once GMs start making moves, everything shows up here.
            </Card>
          ) : (
            <Card className="divide-y divide-[var(--border)]">
              {recentNews.map((a) => (
                <Link
                  key={a.id}
                  to="/news"
                  className="block px-4 py-3 hover:bg-[var(--bg-panel-alt)]"
                >
                  <div className="flex items-center justify-between gap-3">
                    <span className="font-bold text-white">{a.headline}</span>
                    <span className="shrink-0 text-[11px] text-[var(--text-muted)]">{timeAgo(a.createdAt)}</span>
                  </div>
                  <p className="mt-1 line-clamp-1 text-[13px] text-[var(--text-muted)]">{a.body}</p>
                </Link>
              ))}
            </Card>
          )}
        </div>

        <div className="space-y-6">
          <div>
            <h2 className="mb-3 text-sm font-extrabold uppercase tracking-wide text-white">
              Most Cap Space
            </h2>
            <Card className="divide-y divide-[var(--border)]">
              {mostCapSpace.map((team) => (
                <Link
                  key={team.id}
                  to={`/teams/${team.id}`}
                  className="flex items-center justify-between px-4 py-2.5 hover:bg-[var(--bg-panel-alt)]"
                >
                  <span className="flex items-center gap-2.5">
                    <TeamBadge team={team} size={24} />
                    <span className="text-[13px] font-semibold text-white">{team.abbr}</span>
                  </span>
                  <span className="text-[13px] font-bold">
                    <CapSpaceText value={team.capSpace} />
                  </span>
                </Link>
              ))}
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}
