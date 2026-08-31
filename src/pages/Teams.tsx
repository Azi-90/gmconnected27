import { useState } from 'react'
import { Link } from 'react-router-dom'
import type { Conference, Division } from '../types'
import { Card, PageHeader, TeamBadge, CapSpaceText, Button } from '../components/ui'
import { formatCompactMoney, formatMoney } from '../lib/format'
import { useAuth } from '../lib/AuthContext'
import { useTeamClaims } from '../lib/useTeamClaims'
import { useLeagueData } from '../lib/LeagueDataContext'

const STRUCTURE: { conference: Conference; divisions: Division[] }[] = [
  { conference: 'Eastern', divisions: ['Atlantic', 'Metropolitan'] },
  { conference: 'Western', divisions: ['Central', 'Pacific'] },
]

function normalize(value: string) {
  return value.trim().toLowerCase()
}

// GMs' Discord nicknames often follow a "TeamGM | Name" convention, so match either
// the whole identity string or any "|"/"-"/":"/"/"-separated segment of it.
function identityMatchesGmName(identity: string, gmName: string) {
  const target = normalize(gmName)
  if (normalize(identity) === target) return true
  return identity
    .split(/[|/:•–—-]/)
    .map((segment) => normalize(segment))
    .includes(target)
}

function CapSheetView() {
  const { teams, salaryCap, season } = useLeagueData()
  const sorted = [...teams].sort((a, b) => b.capUsed - a.capUsed)

  return (
    <div className="space-y-4">
      <p className="text-[14px] text-[var(--text-muted)]">
        Upper limit {formatMoney(salaryCap)} · {season} season · sorted by tightest cap situation.
      </p>
      <Card className="max-h-[640px] overflow-auto">
        <table className="w-full text-left text-sm">
          <thead className="sticky top-0 z-10 bg-[var(--bg-panel)]">
            <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
              <th className="px-3 py-2.5">Club</th>
              <th className="px-3 py-2.5">Division</th>
              <th className="px-3 py-2.5">GM</th>
              <th className="px-3 py-2.5">Players</th>
              <th className="px-3 py-2.5">Cap Used</th>
              <th className="px-3 py-2.5">Cap Space</th>
            </tr>
          </thead>
          <tbody>
            {sorted.map((team, i) => (
              <tr
                key={team.id}
                className={`border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                  i % 2 === 1 ? 'bg-white/[0.015]' : ''
                }`}
              >
                <td className="px-3 py-2.5">
                  <Link to={`/teams/${team.id}`} className="flex items-center gap-2.5 hover:underline">
                    <TeamBadge team={team} size={26} />
                    <span className="font-bold text-white">
                      {team.city} {team.name}
                    </span>
                  </Link>
                </td>
                <td className="px-3 py-2.5 text-[var(--text-muted)]">{team.division}</td>
                <td className="px-3 py-2.5 text-[var(--text-muted)]">{team.gmName ?? 'Unclaimed'}</td>
                <td className="px-3 py-2.5 text-[var(--text-muted)]">{team.playerCount}</td>
                <td className="px-3 py-2.5 font-semibold text-white">{formatMoney(team.capUsed)}</td>
                <td className="px-3 py-2.5 font-bold">
                  <CapSpaceText value={team.capSpace} compact={formatMoney(team.capSpace)} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}

export default function Teams() {
  const { user, profile, guildLookupFailed } = useAuth()
  const { claims, claimTeam, releaseTeam } = useTeamClaims()
  const { loading, teams } = useLeagueData()
  const [view, setView] = useState<'cards' | 'cap-sheet'>('cards')

  const myClaim = user ? [...claims.values()].find((c) => c.userId === user.id) : undefined
  const resolvedIdentity = profile?.guild_nickname ?? profile?.discord_username ?? null

  const matchesRoster = (gmName: string | null) =>
    Boolean(resolvedIdentity && gmName && identityMatchesGmName(resolvedIdentity, gmName))

  const hasAnyMatch = teams.some((t) => matchesRoster(t.gmName))

  if (loading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Clubs"
        description={
          <>
            Pick a club to see its roster, contracts and cap sheet.
            {user && !myClaim && ' Claim your club below to manage it.'}
          </>
        }
        actions={
          <div className="flex overflow-hidden rounded-md border border-[var(--border)]">
            {(['cards', 'cap-sheet'] as const).map((key) => (
              <button
                key={key}
                onClick={() => setView(key)}
                className={`px-3 py-1.5 text-[12px] font-bold uppercase tracking-wide transition-colors ${
                  view === key ? 'bg-[var(--accent)] text-white' : 'text-[var(--text-muted)] hover:text-white'
                }`}
              >
                {key === 'cards' ? 'Cards' : 'Cap Sheet'}
              </button>
            ))}
          </div>
        }
      />

      {user && !myClaim && !hasAnyMatch && (
        <Card className="border-amber-500/30 bg-amber-500/10 px-4 py-3 text-[13px] text-amber-200">
          We couldn't find a club on the league roster assigned to{' '}
          <span className="font-bold">{resolvedIdentity ?? 'your Discord account'}</span>.{' '}
          {guildLookupFailed
            ? "Make sure you selected this league's Discord server when you signed in (sign out and back in if you skipped it), "
            : ''}
          or ask the commissioner to check the roster.
        </Card>
      )}

      {view === 'cap-sheet' ? (
        <CapSheetView />
      ) : (
        <>
          {STRUCTURE.map(({ conference, divisions }) => (
        <div key={conference} className="space-y-6">
          <h2 className="text-sm font-extrabold uppercase tracking-wider text-white">
            {conference} Conference
          </h2>
          {divisions.map((division) => (
            <div key={division}>
              <h3 className="mb-3 text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
                {division} Division
              </h3>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
                {teams
                  .filter((t) => t.conference === conference && t.division === division)
                  .map((team) => {
                    const claim = claims.get(team.id)
                    const isMine = claim?.userId === user?.id
                    const isMyAssignedTeam = matchesRoster(team.gmName)
                    return (
                      <Card
                        key={team.id}
                        className="h-full overflow-hidden transition-all duration-150 hover:-translate-y-0.5 hover:border-[var(--border-strong)] hover:shadow-[var(--shadow-md)]"
                      >
                        <div className="h-1.5" style={{ background: team.color }} />
                        <Link to={`/teams/${team.id}`} className="flex items-center gap-3 px-4 pt-3">
                          <TeamBadge team={team} />
                          <div>
                            <div className="text-[15px] font-extrabold text-white">
                              {team.city} {team.name}
                            </div>
                            <div className="text-[12px] text-[var(--text-muted)]">
                              {claim
                                ? `GM ${claim.discordUsername ?? 'Claimed'}`
                                : `GM ${team.gmName ?? 'Unclaimed'} (league roster)`}
                            </div>
                          </div>
                        </Link>
                        <div className="flex items-center justify-between px-4 py-3 text-[12px]">
                          <span className="text-[var(--text-muted)]">
                            {team.playerCount} players
                          </span>
                          <span className="font-bold">
                            <CapSpaceText
                              value={team.capSpace}
                              compact={formatCompactMoney(team.capSpace) + ' space'}
                            />
                          </span>
                        </div>
                        {user && (
                          <div className="border-t border-[var(--border)] px-4 py-2.5">
                            {isMine ? (
                              <Button
                                variant="secondary"
                                className="w-full"
                                onClick={() => releaseTeam(team.id)}
                              >
                                Release Team
                              </Button>
                            ) : claim ? (
                              <span className="block text-center text-[11px] font-semibold uppercase tracking-wide text-[var(--text-muted)]">
                                Claimed
                              </span>
                            ) : !isMyAssignedTeam ? (
                              <span className="block text-center text-[11px] font-semibold uppercase tracking-wide text-[var(--text-muted)]">
                                Assigned to {team.gmName ?? 'another GM'}
                              </span>
                            ) : myClaim ? (
                              <span className="block text-center text-[11px] font-semibold uppercase tracking-wide text-[var(--text-muted)]">
                                Release your team to claim this one
                              </span>
                            ) : (
                              <Button
                                className="w-full"
                                onClick={() => user && claimTeam(team.id, user.id)}
                              >
                                Claim This Team
                              </Button>
                            )}
                          </div>
                        )}
                        {profile?.is_commissioner && claim && !isMine && (
                          <div className="border-t border-[var(--border)] px-4 py-2">
                            <button
                              onClick={() => releaseTeam(team.id)}
                              className="text-[11px] font-semibold uppercase tracking-wide text-[var(--negative)] hover:underline"
                            >
                              Commissioner: unclaim
                            </button>
                          </div>
                        )}
                      </Card>
                    )
                  })}
              </div>
            </div>
          ))}
        </div>
          ))}
        </>
      )}
    </div>
  )
}
