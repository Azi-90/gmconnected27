import { useEffect, useMemo, useState } from 'react'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { supabase } from '../lib/supabase'
import { triggerNewsGeneration } from '../lib/newsTrigger'
import type { DraftPick } from '../types'
import { Card, PageHeader, Button, TeamBadge } from '../components/ui'

function mapPickRow(row: any): DraftPick {
  return {
    id: row.id,
    draftYear: row.draft_year,
    originalTeamId: row.original_team_id,
    currentOwnerTeamId: row.current_owner_team_id,
    pickNumber: row.pick_number,
    used: row.used,
  }
}

const POSITION_FILTERS = ['All', 'F', 'C', 'LW', 'RW', 'D', 'G'] as const

const DEVELOPMENT_ODDS = [
  { label: 'Expected development', pct: 60, tone: 'neutral' as const },
  { label: 'Breakout development', pct: 20, tone: 'positive' as const },
  { label: 'Slow development', pct: 15, tone: 'warning' as const },
  { label: 'Bust development', pct: 5, tone: 'negative' as const },
]

const TONE_CLASS: Record<string, string> = {
  positive: 'text-[var(--positive)]',
  neutral: 'text-white',
  warning: 'text-[var(--warning)]',
  negative: 'text-[var(--negative)]',
}

function DraftBoardCard({
  picks,
  onLotteryRun,
}: {
  picks: DraftPick[]
  onLotteryRun: () => void
}) {
  const { profile } = useAuth()
  const { draftClassYear, teamsById } = useLeagueData()
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<string | null>(null)

  const hasLottery = picks.some((p) => p.pickNumber !== null)
  const picksMade = picks.filter((p) => p.used).length
  const onClockPick = picks.find((p) => !p.used) ?? null

  const runLottery = async () => {
    setRunning(true)
    const { error } = await supabase.rpc('run_draft_lottery')
    setRunning(false)
    if (error) setResult(`Failed: ${error.message}`)
    else {
      setResult('Lottery drawn — draft order is set below.')
      await onLotteryRun()
      const { data } = await supabase
        .from('draft_lottery_results')
        .select('draft_order')
        .eq('draft_year', draftClassYear)
        .maybeSingle()
      const order = (data?.draft_order as string[] | undefined) ?? []
      const topTeams = order.slice(0, 5).map((id) => teamsById.get(id)?.abbr ?? id)
      if (topTeams.length > 0) {
        triggerNewsGeneration('draft_lottery', { season: draftClassYear, topTeams }, order.slice(0, 5))
      }
    }
  }

  return (
    <Card className="p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
        {draftClassYear} Draft Lottery
      </p>

      {!hasLottery ? (
        <>
          <p className="mt-2 text-[13px] text-[var(--text-muted)]">
            Not drawn yet. Odds are weighted by standings — the worst record gets the best odds,
            just like the real thing.
          </p>
          {profile?.is_commissioner && (
            <Button className="mt-3" onClick={runLottery} disabled={running}>
              {running ? 'Drawing…' : 'Run Draft Lottery'}
            </Button>
          )}
        </>
      ) : (
        <>
          {onClockPick ? (
            <p className="mt-2 text-[13px] text-[var(--text-muted)]">
              On the clock: pick {picksMade + 1} of {picks.length} —{' '}
              <span className="font-bold text-white">
                {teamsById.get(onClockPick.currentOwnerTeamId)?.city} {teamsById.get(onClockPick.currentOwnerTeamId)?.name}
              </span>
              {onClockPick.currentOwnerTeamId !== onClockPick.originalTeamId && (
                <span className="text-[var(--text-muted)]"> (via {teamsById.get(onClockPick.originalTeamId)?.abbr})</span>
              )}
            </p>
          ) : (
            <p className="mt-2 text-[13px] text-[var(--positive)]">
              Round complete — remaining prospects moved to Free Agency.
            </p>
          )}
          <div className="mt-3 flex flex-wrap gap-2">
            {picks.map((pick) => {
              const team = teamsById.get(pick.currentOwnerTeamId)
              if (!team) return null
              const isOnClock = onClockPick?.id === pick.id
              return (
                <span
                  key={pick.id}
                  className={`flex items-center gap-1.5 rounded-md border px-2 py-1 text-[11px] font-bold ${
                    isOnClock
                      ? 'border-[var(--accent)] bg-[var(--accent)]/15 text-white'
                      : pick.used
                        ? 'border-[var(--border)] text-[var(--text-muted)] opacity-60'
                        : 'border-[var(--border)] text-white'
                  }`}
                >
                  {pick.pickNumber}. <TeamBadge team={team} size={16} /> {team.abbr}
                </span>
              )
            })}
          </div>
          {profile?.is_commissioner && picksMade === 0 && (
            <Button variant="secondary" className="mt-3" onClick={runLottery} disabled={running}>
              {running ? 'Redrawing…' : 'Re-run Lottery'}
            </Button>
          )}
        </>
      )}

      {result && <p className="mt-3 text-[13px] text-[var(--positive)]">{result}</p>}
    </Card>
  )
}

export default function Scouting() {
  const { loading, prospects, teamsById, draftClassYear, refresh } = useLeagueData()
  const { profile } = useAuth()
  const [posFilter, setPosFilter] = useState<(typeof POSITION_FILTERS)[number]>('All')
  const [search, setSearch] = useState('')
  const [selectedRank, setSelectedRank] = useState<number | null>(null)
  const [picks, setPicks] = useState<DraftPick[]>([])
  const [drafting, setDrafting] = useState(false)

  const filtered = useMemo(() => {
    return prospects.filter((p) => {
      const posMatch = posFilter === 'All' || p.position === posFilter
      const searchMatch = p.name.toLowerCase().includes(search.toLowerCase())
      return posMatch && searchMatch
    })
  }, [posFilter, search, prospects])

  const refreshPicks = async () => {
    const { data } = await supabase
      .from('draft_picks')
      .select('*')
      .eq('draft_year', draftClassYear)
      .order('pick_number', { ascending: true, nullsFirst: false })
    setPicks((data ?? []).map(mapPickRow))
  }

  useEffect(() => {
    refreshPicks()
  }, [draftClassYear])

  if (loading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  const selected = prospects.find((p) => p.rank === selectedRank) ?? prospects[0]

  if (!selected) {
    return (
      <Card className="px-5 py-8 text-center text-[14px] text-[var(--text-muted)]">
        No draft class loaded yet.
      </Card>
    )
  }

  const hasLottery = picks.some((p) => p.pickNumber !== null)
  const picksMade = picks.filter((p) => p.used).length
  const onClockPick = picks.find((p) => !p.used) ?? null
  const onClockTeam = onClockPick ? teamsById.get(onClockPick.currentOwnerTeamId) : undefined

  const draftSelected = async () => {
    if (!onClockPick) return
    setDrafting(true)
    const wasLastPick = picksMade + 1 >= picks.length
    const { error } = await supabase.rpc('draft_prospect', {
      p_prospect_id: selected.id,
      p_pick_id: onClockPick.id,
    })
    setDrafting(false)
    if (!error) {
      await refresh()
      await refreshPicks()
      if (wasLastPick && picks.length > 0) {
        const { data } = await supabase
          .from('draft_prospects')
          .select('name, position, drafted_by_team_id')
          .eq('draft_year', draftClassYear)
          .not('drafted_by_team_id', 'is', null)
        const byTeam = new Map((data ?? []).map((row) => [row.drafted_by_team_id as string, row]))
        const orderedPicks = [...picks].sort((a, b) => (a.pickNumber ?? 0) - (b.pickNumber ?? 0))
        const draftPicksSummary = orderedPicks
          .map((pick) => {
            const row = byTeam.get(pick.currentOwnerTeamId)
            const team = teamsById.get(pick.currentOwnerTeamId)
            return row && team ? { team: team.abbr, name: row.name, position: row.position } : null
          })
          .filter((p): p is { team: string; name: string; position: string } => p !== null)
        if (draftPicksSummary.length > 0) {
          triggerNewsGeneration(
            'draft_complete',
            { draftYear: draftClassYear, picks: draftPicksSummary },
            orderedPicks.map((p) => p.currentOwnerTeamId),
          )
        }
      }
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Draft Central"
        description="2027 NHL Draft Class · top 40 ranked prospects · rankings sourced from Elite Prospects. The commissioner runs the draft once the season wraps."
      />

      <DraftBoardCard picks={picks} onLotteryRun={refreshPicks} />

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex overflow-hidden rounded-md border border-[var(--border)]">
          {POSITION_FILTERS.map((pos) => (
            <button
              key={pos}
              onClick={() => setPosFilter(pos)}
              className={`px-3 py-1.5 text-[12px] font-bold uppercase tracking-wide ${
                posFilter === pos ? 'bg-[var(--accent)] text-white' : 'text-[var(--text-muted)] hover:text-white'
              }`}
            >
              {pos === 'All' ? 'All Positions' : pos}
            </button>
          ))}
        </div>
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search prospects..."
          className="w-56 rounded-md border border-[var(--border)] bg-[var(--bg-panel)] px-3 py-1.5 text-[13px] text-white placeholder:text-[var(--text-muted)]"
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-[1fr_320px]">
        <Card className="max-h-[720px] overflow-auto">
          <table className="w-full text-left text-sm">
            <thead className="sticky top-0 z-10 bg-[var(--bg-panel)]">
              <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
                <th className="px-3 py-2.5">Rank</th>
                <th className="px-3 py-2.5">Player</th>
                <th className="px-3 py-2.5">Pos</th>
                <th className="px-3 py-2.5">H/W</th>
                <th className="px-3 py-2.5">Nat</th>
                <th className="px-3 py-2.5">Club</th>
                <th className="px-3 py-2.5">OVR Range</th>
                <th className="px-3 py-2.5">Potential</th>
                <th className="px-3 py-2.5">Proj.</th>
                <th className="px-3 py-2.5">Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((p) => {
                const draftedTeam = p.draftedByTeamId ? teamsById.get(p.draftedByTeamId) : undefined
                return (
                  <tr
                    key={p.rank}
                    onClick={() => setSelectedRank(p.rank)}
                    className={`cursor-pointer border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                      selected.rank === p.rank ? 'bg-[var(--bg-panel-alt)]' : ''
                    } ${p.draftedByTeamId ? 'opacity-50' : ''}`}
                  >
                    <td className="px-3 py-2 text-[var(--text-muted)]">{p.rank}</td>
                    <td className="px-3 py-2 font-semibold text-white">{p.name}</td>
                    <td className="px-3 py-2">{p.position}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">
                      {p.height} · {p.weight}
                    </td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">{p.nationality}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">
                      {p.club} <span className="text-[11px]">({p.league})</span>
                    </td>
                    <td className="px-3 py-2 font-bold text-white">
                      {p.ovrLow}–{p.ovrHigh}
                    </td>
                    <td className="px-3 py-2 font-semibold text-amber-300">{p.potential}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">
                      {p.projLow}–{p.projHigh}
                    </td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">
                      {draftedTeam ? `Drafted: ${draftedTeam.abbr}` : p.readiness}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Card>

        <div className="space-y-4">
          <Card className="p-5">
            <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
              Prospect Detail
            </p>
            <h2 className="mt-1 text-lg font-extrabold text-white">
              #{selected.rank} {selected.name}
            </h2>
            <p className="text-[13px] text-[var(--text-muted)]">
              {selected.nationality} · {selected.club} ({selected.league})
            </p>
            <p className="mt-1 text-[13px] text-[var(--text-muted)]">
              {selected.position} · {selected.height} · {selected.weight} lbs
            </p>

            <div className="mt-4 grid grid-cols-2 gap-3">
              <div className="rounded-md border border-[var(--border)] px-3 py-2">
                <div className="text-[10px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
                  OVR Range
                </div>
                <div className="text-[16px] font-extrabold text-white">
                  {selected.ovrLow}–{selected.ovrHigh}
                </div>
              </div>
              <div className="rounded-md border border-[var(--border)] px-3 py-2">
                <div className="text-[10px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
                  Potential
                </div>
                <div className="text-[16px] font-extrabold text-amber-300">{selected.potential}</div>
              </div>
              <div className="rounded-md border border-[var(--border)] px-3 py-2">
                <div className="text-[10px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
                  Proj. Range
                </div>
                <div className="text-[16px] font-extrabold text-white">
                  {selected.projLow}–{selected.projHigh}
                </div>
              </div>
              <div className="rounded-md border border-[var(--border)] px-3 py-2">
                <div className="text-[10px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
                  Readiness
                </div>
                <div className="text-[16px] font-extrabold text-white">{selected.readiness}</div>
              </div>
            </div>

            {selected.draftedByTeamId ? (
              <p className="mt-4 rounded-md border border-[var(--border)] px-3 py-2 text-center text-[13px] font-bold text-white">
                Drafted by {teamsById.get(selected.draftedByTeamId)?.city}{' '}
                {teamsById.get(selected.draftedByTeamId)?.name}
              </p>
            ) : profile?.is_commissioner && onClockTeam ? (
              <Button className="mt-4 w-full" onClick={draftSelected} disabled={drafting}>
                {drafting ? 'Drafting…' : `Draft to ${onClockTeam.city} ${onClockTeam.name}`}
              </Button>
            ) : (
              <p className="mt-4 text-center text-[11px] text-[var(--text-muted)]">
                {hasLottery ? 'Round complete.' : 'Waiting on the draft lottery.'}
              </p>
            )}
          </Card>

          <Card className="p-5">
            <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
              How Overalls Develop
            </p>
            <p className="mt-2 text-[13px] leading-relaxed text-[var(--text-muted)]">
              A drafted prospect enters the league inside its overall range and then rolls a
              development curve every time the commissioner advances the season.
            </p>
            <div className="mt-3 space-y-2">
              {DEVELOPMENT_ODDS.map((odd) => (
                <div key={odd.label} className="flex items-center justify-between text-[13px]">
                  <span className="text-[var(--text-muted)]">{odd.label}</span>
                  <span className={`font-bold ${TONE_CLASS[odd.tone]}`}>{odd.pct}%</span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </div>
  )
}
