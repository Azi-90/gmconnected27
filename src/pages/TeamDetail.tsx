import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { useTeamClaims } from '../lib/useTeamClaims'
import { supabase } from '../lib/supabase'
import { triggerNewsGeneration } from '../lib/newsTrigger'
import type { Player, Position, TeamProspect } from '../types'
import { Card, TeamBadge, CapSpaceText, StatusBadge, Button } from '../components/ui'
import { formatMoney } from '../lib/format'

function mapTeamProspectRow(row: any): TeamProspect {
  return {
    id: row.id,
    teamId: row.team_id,
    name: row.name,
    position: row.position,
    height: row.height,
    weight: row.weight,
    nationality: row.nationality,
    club: row.club,
    league: row.league,
    potential: row.potential,
    ovrLow: row.ovr_low,
    ovrHigh: row.ovr_high,
    readiness: row.readiness,
  }
}

const GROUPS: { title: string; positions: Position[] }[] = [
  { title: 'Forwards', positions: ['C', 'LW', 'RW'] },
  { title: 'Defensemen', positions: ['D'] },
  { title: 'Goalies', positions: ['G'] },
]

const CSV_HEADER = [
  'Player', 'Number', 'Position', 'Shoots', 'Height', 'Weight', 'Born', 'Birthplace',
  'Contract Type', 'Cap Hit', 'Salary', 'Signing Bonus', 'Total Value', 'Clause', 'Term (Years)', 'Expiry', 'Status',
]

function playerToCsvRow(p: Player): string {
  return [
    p.name, p.number, p.position, p.shoots, p.height, p.weight, p.born, p.birthplace,
    p.contractType, p.capHit, p.salary, p.signingBonus, p.totalValue, p.clause, p.termYears, p.expiryYear, p.status,
  ]
    .map((field) => `"${String(field).replace(/"/g, '""')}"`)
    .join(',')
}

function downloadRosterCsv(teamAbbr: string, roster: Player[]) {
  const csv = [CSV_HEADER.join(','), ...roster.map(playerToCsvRow)].join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${teamAbbr}-roster-2026-27.csv`
  link.click()
  URL.revokeObjectURL(url)
}

export default function TeamDetail() {
  const { teamId } = useParams<{ teamId: string }>()
  const [tab, setTab] = useState<'roster' | 'cap-sheet' | 'prospects'>('roster')

  const { loading, teamsById, playersByTeam, salaryCap, season, refresh } = useLeagueData()
  const { claims } = useTeamClaims()

  if (loading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  const team = teamId ? teamsById.get(teamId) : undefined
  const roster = teamId ? playersByTeam(teamId) : []
  const claim = teamId ? claims.get(teamId) : undefined

  if (!team) {
    return <p className="text-[var(--text-muted)]">Team not found.</p>
  }

  return (
    <div className="space-y-6">
      <div
        className="overflow-hidden rounded-xl border-2"
        style={{
          borderColor: `${team.color}80`,
          background: `linear-gradient(135deg, ${team.color}59, var(--bg-panel) 60%)`,
        }}
      >
        <div className="px-6 py-7">
          <div className="flex items-center gap-5">
            <TeamBadge team={team} size={64} />
            <div>
              <p className="text-[11px] font-bold uppercase tracking-widest text-slate-200">
                {team.conference} · {team.division}
              </p>
              <h1 className="text-4xl font-black uppercase tracking-tight text-white">
                {team.city} {team.name}
              </h1>
              <p className="mt-1 text-[13px] text-slate-200">
                General Manager:{' '}
                <span className="font-bold text-white">
                  {claim ? claim.discordUsername ?? 'Claimed' : `${team.gmName ?? 'Unclaimed'} (league roster)`}
                </span>
              </p>
            </div>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-px border-t-2 sm:grid-cols-4" style={{ borderColor: `${team.color}80`, background: `${team.color}40` }}>
          <div className="bg-[var(--bg-panel)] px-5 py-4">
            <div className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-muted)]">
              Cap Used
            </div>
            <div className="mt-1 text-2xl font-black text-white">{formatMoney(team.capUsed)}</div>
            <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-[var(--bg-panel-alt)]">
              <div
                className="h-full rounded-full"
                style={{
                  width: `${Math.min(100, Math.max(0, (team.capUsed / salaryCap) * 100))}%`,
                  background: team.capUsed > salaryCap ? 'var(--negative)' : 'var(--positive)',
                }}
              />
            </div>
          </div>
          <div className="bg-[var(--bg-panel)] px-5 py-4">
            <div className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-muted)]">
              Cap Space
            </div>
            <div className="mt-1 text-2xl font-black">
              <CapSpaceText value={team.capSpace} compact={formatMoney(team.capSpace)} />
            </div>
          </div>
          <div className="bg-[var(--bg-panel)] px-5 py-4">
            <div className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-muted)]">
              Roster
            </div>
            <div className="mt-1 text-2xl font-black text-white">{team.playerCount}</div>
          </div>
          <div className="bg-[var(--bg-panel)] px-5 py-4">
            <div className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-muted)]">
              Avg Cap Hit
            </div>
            <div className="mt-1 text-2xl font-black text-white">
              {formatMoney(team.playerCount > 0 ? Math.round(team.capUsed / team.playerCount) : 0)}
            </div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between border-b border-[var(--border)]">
        <div className="flex gap-6">
          {(['roster', 'cap-sheet', 'prospects'] as const).map((key) => (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`border-b-2 pb-2 pt-1 text-[13px] font-bold uppercase tracking-wide transition-colors ${
                tab === key
                  ? 'border-[var(--accent)] text-white'
                  : 'border-transparent text-[var(--text-muted)] hover:text-white'
              }`}
            >
              {key === 'cap-sheet' ? 'Cap Sheet' : key}
            </button>
          ))}
        </div>
        <Button
          variant="secondary"
          className="mb-2"
          disabled={roster.length === 0}
          onClick={() => downloadRosterCsv(team.abbr, roster)}
        >
          Export Roster CSV
        </Button>
      </div>

      {tab === 'prospects' ? (
        <ProspectsTab teamId={team.id} />
      ) : roster.length === 0 ? (
        <Card className="px-6 py-10 text-center text-[14px] text-[var(--text-muted)]">
          No roster data loaded for {team.city} {team.name} yet. Full detail is seeded for Ottawa
          as the reference club — the commissioner can bulk-load every other team once real
          rosters are imported.
        </Card>
      ) : tab === 'roster' ? (
        <RosterTab roster={roster} />
      ) : (
        <CapSheetTab
          roster={roster}
          season={season}
          salaryCap={salaryCap}
          teamId={team.id}
          teamAbbr={team.abbr}
          refresh={refresh}
        />
      )}
    </div>
  )
}

function ProspectsTab({ teamId }: { teamId: string }) {
  const [prospects, setProspects] = useState<TeamProspect[] | null>(null)

  useEffect(() => {
    let active = true
    supabase
      .from('team_prospects')
      .select('*')
      .eq('team_id', teamId)
      .then(({ data }) => {
        if (active) setProspects((data ?? []).map(mapTeamProspectRow))
      })
    return () => {
      active = false
    }
  }, [teamId])

  if (prospects === null) {
    return <p className="text-[var(--text-muted)]">Loading prospects…</p>
  }

  if (prospects.length === 0) {
    return (
      <Card className="px-6 py-10 text-center text-[14px] text-[var(--text-muted)]">
        No organizational prospects seeded yet — the commissioner can seed them from Commissioner
        Tools.
      </Card>
    )
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {prospects.map((p) => (
        <Card key={p.id} className="p-4">
          <div className="flex items-center justify-between">
            <span className="font-bold text-white">{p.name}</span>
            <span className="text-[12px] text-[var(--text-muted)]">{p.position}</span>
          </div>
          <p className="mt-1 text-[12px] text-[var(--text-muted)]">
            {p.nationality} · {p.club} ({p.league})
          </p>
          <p className="mt-1 text-[12px] text-[var(--text-muted)]">
            {p.height} · {p.weight} lbs
          </p>
          <div className="mt-2 flex items-center justify-between text-[12px]">
            <span className="font-semibold text-amber-300">{p.potential}</span>
            <span className="text-white">
              {p.ovrLow}–{p.ovrHigh} OVR
            </span>
          </div>
          <p className="mt-1 text-[11px] text-[var(--text-muted)]">{p.readiness}</p>
        </Card>
      ))}
    </div>
  )
}

function RosterTab({ roster }: { roster: Player[] }) {
  return (
    <div className="space-y-8">
      {GROUPS.map((group) => {
        const players = roster.filter((p) => group.positions.includes(p.position))
        if (players.length === 0) return null
        return (
          <div key={group.title}>
            <h3 className="mb-2 flex items-center gap-2 text-[13px] font-extrabold uppercase tracking-wide text-white">
              <span className="h-4 w-1 rounded bg-[var(--accent)]" />
              {group.title} <span className="text-[var(--text-muted)]">{players.length}</span>
            </h3>
            <Card className="max-h-[420px] overflow-auto">
              <table className="w-full text-left text-[13px]">
                <thead className="sticky top-0 z-10 bg-[var(--bg-panel)]">
                  <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
                    <th className="px-3 py-1.5">Player</th>
                    <th className="px-3 py-1.5">#</th>
                    <th className="px-3 py-1.5">Pos</th>
                    <th className="px-3 py-1.5">OVR</th>
                    <th className="px-3 py-1.5">Sh</th>
                    <th className="px-3 py-1.5">Ht</th>
                    <th className="px-3 py-1.5">Wt</th>
                    <th className="px-3 py-1.5">Born</th>
                    <th className="px-3 py-1.5">Birthplace</th>
                    <th className="px-3 py-1.5">Cap Hit</th>
                    <th className="px-3 py-1.5">Term</th>
                    <th className="px-3 py-1.5">Expiry</th>
                  </tr>
                </thead>
                <tbody>
                  {players.map((p, i) => (
                    <tr
                      key={p.id}
                      className={`border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                        i % 2 === 1 ? 'bg-white/[0.015]' : ''
                      }`}
                    >
                      <td className="px-3 py-1.5 font-semibold text-white">
                        {p.name}
                        {p.retirementAnnouncedSeason && (
                          <span className="ml-1.5 rounded border border-amber-500/30 bg-amber-500/15 px-1 py-0.5 text-[10px] font-bold uppercase text-amber-300">
                            Retiring
                          </span>
                        )}
                      </td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.number}</td>
                      <td className="px-3 py-1.5">{p.position}</td>
                      <td className="px-3 py-1.5 font-bold text-amber-300">{p.overall ?? '—'}</td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.shoots}</td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.height}</td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.weight}</td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.born}</td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.birthplace}</td>
                      <td className="px-3 py-1.5 font-bold text-white">{formatMoney(p.capHit)}</td>
                      <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.termYears} yr</td>
                      <td className="px-3 py-1.5">
                        <span className="text-[var(--text-muted)]">{p.expiryYear}</span>{' '}
                        <StatusBadge status={p.status} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
          </div>
        )
      })}
    </div>
  )
}

function ResignForm({
  player,
  teamAbbr,
  onDone,
}: {
  player: Player
  teamAbbr: string
  onDone: () => void
}) {
  const [aav, setAav] = useState(String(player.capHit))
  const [termYears, setTermYears] = useState('2')
  const [submitting, setSubmitting] = useState(false)
  const [result, setResult] = useState<{ outcome: string; expectedAav: number } | { error: string } | null>(null)

  const submit = async () => {
    setSubmitting(true)
    const { data, error } = await supabase.rpc('propose_resign', {
      p_player_id: player.id,
      p_aav: Number(aav),
      p_term_years: Number(termYears),
    })
    setSubmitting(false)
    if (error) {
      setResult({ error: error.message })
      return
    }
    setResult(data as { outcome: string; expectedAav: number })
    if (data?.outcome === 'accepted') {
      triggerNewsGeneration(
        'free_agency',
        { team: teamAbbr, playerName: player.name, aav: Number(aav), termYears: Number(termYears) },
        [player.teamId],
      )
      onDone()
    }
  }

  return (
    <div className="mt-2 flex flex-wrap items-center gap-2 rounded-md border border-[var(--border)] bg-[var(--bg)] p-2">
      <input
        type="number"
        value={aav}
        onChange={(e) => setAav(e.target.value)}
        placeholder="AAV ($)"
        className="w-32 rounded border border-[var(--border)] bg-[var(--bg-panel)] px-2 py-1 text-[12px] text-white"
      />
      <input
        type="number"
        min={1}
        max={8}
        value={termYears}
        onChange={(e) => setTermYears(e.target.value)}
        placeholder="Years"
        className="w-20 rounded border border-[var(--border)] bg-[var(--bg-panel)] px-2 py-1 text-[12px] text-white"
      />
      <Button onClick={submit} disabled={submitting}>
        {submitting ? 'Offering…' : 'Offer'}
      </Button>
      {result && 'error' in result && <span className="text-[12px] text-[var(--negative)]">{result.error}</span>}
      {result && 'outcome' in result && result.outcome === 'countered' && (
        <span className="text-[12px] text-amber-300">
          Countered — they want around {formatMoney(result.expectedAav)}/yr
        </span>
      )}
      {result && 'outcome' in result && result.outcome === 'rejected' && (
        <span className="text-[12px] text-[var(--negative)]">Rejected outright — try free agency later</span>
      )}
      {result && 'outcome' in result && result.outcome === 'accepted' && (
        <span className="text-[12px] text-[var(--positive)]">Signed!</span>
      )}
    </div>
  )
}

function seasonStartYear(season: string): number {
  return parseInt(season.split('-')[0], 10)
}

function formatSeasonLabel(startYear: number): string {
  return `${startYear}-${String((startYear + 1) % 100).padStart(2, '0')}`
}

function CapSheetTab({
  roster,
  season,
  salaryCap,
  teamId,
  teamAbbr,
  refresh,
}: {
  roster: Player[]
  season: string
  salaryCap: number
  teamId: string
  teamAbbr: string
  refresh: () => Promise<void>
}) {
  const { user, profile } = useAuth()
  const { claims } = useTeamClaims()
  const [resigning, setResigning] = useState<string | null>(null)

  const isCommissioner = Boolean(profile?.is_commissioner)
  const myClaim = user ? [...claims.values()].find((c) => c.userId === user.id) : undefined
  const canManage = isCommissioner || myClaim?.teamId === teamId

  const currentStart = seasonStartYear(season)
  const maxExpiryStart = roster.reduce((max, p) => Math.max(max, seasonStartYear(p.expiryYear)), currentStart)
  const seasons: number[] = []
  for (let y = currentStart; y <= maxExpiryStart; y++) seasons.push(y)

  const sorted = [...roster].sort((a, b) => b.capHit - a.capHit)

  const byType = new Map<string, { count: number; capHit: number }>()
  for (const p of roster) {
    const entry = byType.get(p.contractType) ?? { count: 0, capHit: 0 }
    entry.count += 1
    entry.capHit += p.capHit
    byType.set(p.contractType, entry)
  }

  return (
    <div className="space-y-4">
      <Card className="max-h-[480px] overflow-auto">
        <table className="w-full text-left text-[13px]">
          <thead className="sticky top-0 z-10 bg-[var(--bg-panel)]">
            <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
              <th className="sticky left-0 z-20 bg-[var(--bg-panel)] px-3 py-1.5">Player</th>
              <th className="px-3 py-1.5">Type</th>
              {seasons.map((y) => (
                <th key={y} className="px-3 py-1.5 text-right">
                  {formatSeasonLabel(y)}
                </th>
              ))}
              {canManage && <th className="px-3 py-1.5" />}
            </tr>
          </thead>
          <tbody>
            {sorted.map((p, i) => {
              const expiryStart = seasonStartYear(p.expiryYear)
              return (
                <tr
                  key={p.id}
                  className={`border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                    i % 2 === 1 ? 'bg-white/[0.015]' : ''
                  }`}
                >
                  <td className="sticky left-0 z-10 bg-[var(--bg-panel)] px-3 py-1.5 font-semibold text-white">
                    {p.name} <span className="text-[var(--text-muted)]">{p.position}</span>
                    {p.retirementAnnouncedSeason && (
                      <span className="ml-1.5 rounded border border-amber-500/30 bg-amber-500/15 px-1 py-0.5 text-[10px] font-bold uppercase text-amber-300">
                        Retiring
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-1.5 text-[var(--text-muted)]">{p.contractType}</td>
                  {seasons.map((y) => {
                    const covered = y <= expiryStart
                    const isFinalYear = y === expiryStart
                    return (
                      <td
                        key={y}
                        className={`px-3 py-1.5 text-right ${
                          covered ? 'font-semibold text-white' : 'text-[var(--text-muted)]'
                        } ${isFinalYear ? 'bg-amber-500/10' : ''}`}
                      >
                        {covered ? formatMoney(p.capHit) : '—'}
                        {isFinalYear && (
                          <span className="ml-1 text-[10px] font-bold uppercase text-amber-300">{p.status}</span>
                        )}
                      </td>
                    )
                  })}
                  {canManage && (
                    <td className="px-3 py-1.5 text-right">
                      {p.retirementAnnouncedSeason ? (
                        <span className="text-[11px] text-[var(--text-muted)]">—</span>
                      ) : (
                        <Button variant="secondary" onClick={() => setResigning(resigning === p.id ? null : p.id)}>
                          Re-sign
                        </Button>
                      )}
                    </td>
                  )}
                </tr>
              )
            })}
          </tbody>
          <tfoot>
            <tr className="border-t-2 border-[var(--border)] bg-[var(--bg-panel-alt)]/60">
              <td className="sticky left-0 z-10 bg-[var(--bg-panel-alt)]/60 px-3 py-2 font-bold text-white" colSpan={2}>
                Team Total
              </td>
              {seasons.map((y) => {
                const total = sorted.reduce((sum, p) => sum + (y <= seasonStartYear(p.expiryYear) ? p.capHit : 0), 0)
                return (
                  <td key={y} className="px-3 py-2 text-right font-bold text-white">
                    {formatMoney(total)}
                  </td>
                )
              })}
              {canManage && <td />}
            </tr>
            <tr>
              <td className="sticky left-0 z-10 bg-[var(--bg-panel)] px-3 py-1.5 font-semibold text-[var(--text-muted)]" colSpan={2}>
                Projected Cap Space
              </td>
              {seasons.map((y) => {
                const total = sorted.reduce((sum, p) => sum + (y <= seasonStartYear(p.expiryYear) ? p.capHit : 0), 0)
                return (
                  <td key={y} className="px-3 py-1.5 text-right font-bold">
                    <CapSpaceText value={salaryCap - total} compact={formatMoney(salaryCap - total)} />
                  </td>
                )
              })}
              {canManage && <td />}
            </tr>
          </tfoot>
        </table>
        {resigning && (
          <div className="border-t border-[var(--border)] p-3">
            <ResignForm
              player={sorted.find((p) => p.id === resigning)!}
              teamAbbr={teamAbbr}
              onDone={async () => {
                await refresh()
                setResigning(null)
              }}
            />
          </div>
        )}
      </Card>

      <p className="text-[11px] text-[var(--text-muted)]">
        Future seasons assume the cap ceiling holds at {formatMoney(salaryCap)} — update once the real number for
        that year is known. The highlighted cell marks each contract's final season.
      </p>

      <Card className="overflow-x-auto">
        <table className="w-full text-left text-[13px]">
          <thead>
            <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
              <th className="px-3 py-2">Contract Type</th>
              <th className="px-3 py-2">Players</th>
              <th className="px-3 py-2">Combined Cap Hit</th>
            </tr>
          </thead>
          <tbody>
            {[...byType.entries()].map(([type, entry]) => (
              <tr key={type} className="border-b border-[var(--border)]/60 last:border-0">
                <td className="px-3 py-2 font-semibold text-white">{type}</td>
                <td className="px-3 py-2 text-[var(--text-muted)]">{entry.count}</td>
                <td className="px-3 py-2 font-bold text-white">{formatMoney(entry.capHit)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}
