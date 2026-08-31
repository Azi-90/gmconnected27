import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { supabase } from '../lib/supabase'
import { triggerNewsGeneration } from '../lib/newsTrigger'
import { Card, PageHeader, Button } from '../components/ui'
import type { ProgressionLogEntry } from '../types'

const STAT_FIELDS = [
  { key: 'gamesPlayed', label: 'GP', column: 'games_played' },
  { key: 'goals', label: 'G', column: 'goals' },
  { key: 'assists', label: 'A', column: 'assists' },
  { key: 'shots', label: 'Shots', column: 'shots' },
  { key: 'hits', label: 'Hits', column: 'hits' },
  { key: 'blocks', label: 'Blk', column: 'blocks' },
  { key: 'takeaways', label: 'TkA', column: 'takeaways' },
  { key: 'giveaways', label: 'GvA', column: 'giveaways' },
  { key: 'faceoffPct', label: 'FO%', column: 'faceoff_pct' },
  { key: 'plusMinus', label: '+/-', column: 'plus_minus' },
  { key: 'savePct', label: 'SV%', column: 'save_pct' },
  { key: 'gaa', label: 'GAA', column: 'gaa' },
  { key: 'wins', label: 'W', column: 'wins' },
] as const

type StatDraft = Record<(typeof STAT_FIELDS)[number]['key'], string>

const EMPTY_DRAFT: StatDraft = {
  gamesPlayed: '0', goals: '0', assists: '0', shots: '0', hits: '0', blocks: '0',
  takeaways: '0', giveaways: '0', faceoffPct: '', plusMinus: '0', savePct: '', gaa: '', wins: '0',
}

function mapStatRow(row: any): StatDraft {
  return {
    gamesPlayed: String(row.games_played ?? 0),
    goals: String(row.goals ?? 0),
    assists: String(row.assists ?? 0),
    shots: String(row.shots ?? 0),
    hits: String(row.hits ?? 0),
    blocks: String(row.blocks ?? 0),
    takeaways: String(row.takeaways ?? 0),
    giveaways: String(row.giveaways ?? 0),
    faceoffPct: row.faceoff_pct != null ? String(row.faceoff_pct) : '',
    plusMinus: String(row.plus_minus ?? 0),
    savePct: row.save_pct != null ? String(row.save_pct) : '',
    gaa: row.gaa != null ? String(row.gaa) : '',
    wins: String(row.wins ?? 0),
  }
}

function PlayerProgressionCard() {
  const { teams, playersByTeam, season, refresh } = useLeagueData()
  const [teamId, setTeamId] = useState(teams[0]?.id ?? '')
  const [drafts, setDrafts] = useState<Record<string, StatDraft>>({})
  const [saving, setSaving] = useState(false)
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<string | null>(null)
  const [log, setLog] = useState<ProgressionLogEntry[]>([])

  const roster = teamId ? playersByTeam(teamId) : []

  const refreshLog = async () => {
    const { data } = await supabase
      .from('progression_log')
      .select('*')
      .eq('season', season)
      .order('created_at', { ascending: false })
      .limit(20)
    setLog(
      (data ?? []).map((row) => ({
        id: row.id,
        season: row.season,
        playerId: row.player_id,
        playerName: row.player_name,
        oldOverall: row.old_overall,
        newOverall: row.new_overall,
        delta: row.delta,
        note: row.note,
        createdAt: row.created_at,
      })),
    )
  }

  useEffect(() => {
    refreshLog()
  }, [season])

  useEffect(() => {
    const loadStats = async () => {
      if (!teamId) return
      const ids = playersByTeam(teamId).map((p) => p.id)
      if (ids.length === 0) {
        setDrafts({})
        return
      }
      const { data } = await supabase
        .from('player_season_stats')
        .select('*')
        .eq('season', season)
        .in('player_id', ids)
      const next: Record<string, StatDraft> = {}
      for (const p of playersByTeam(teamId)) next[p.id] = EMPTY_DRAFT
      for (const row of data ?? []) next[row.player_id] = mapStatRow(row)
      setDrafts(next)
    }
    loadStats()
  }, [teamId, season])

  const setField = (playerId: string, key: keyof StatDraft, value: string) => {
    setDrafts((prev) => ({ ...prev, [playerId]: { ...(prev[playerId] ?? EMPTY_DRAFT), [key]: value } }))
  }

  const saveStats = async () => {
    setSaving(true)
    const rows = roster.map((p) => {
      const d = drafts[p.id] ?? EMPTY_DRAFT
      return {
        player_id: p.id,
        season,
        games_played: parseInt(d.gamesPlayed, 10) || 0,
        goals: parseInt(d.goals, 10) || 0,
        assists: parseInt(d.assists, 10) || 0,
        shots: parseInt(d.shots, 10) || 0,
        hits: parseInt(d.hits, 10) || 0,
        blocks: parseInt(d.blocks, 10) || 0,
        takeaways: parseInt(d.takeaways, 10) || 0,
        giveaways: parseInt(d.giveaways, 10) || 0,
        faceoff_pct: d.faceoffPct === '' ? null : parseFloat(d.faceoffPct),
        plus_minus: parseInt(d.plusMinus, 10) || 0,
        save_pct: d.savePct === '' ? null : parseFloat(d.savePct),
        gaa: d.gaa === '' ? null : parseFloat(d.gaa),
        wins: parseInt(d.wins, 10) || 0,
      }
    })
    const { error } = await supabase.from('player_season_stats').upsert(rows)
    setSaving(false)
    setResult(error ? `Failed to save: ${error.message}` : 'Stats saved.')
  }

  const runProgression = async () => {
    setRunning(true)
    const { error } = await supabase.rpc('apply_player_progression', { p_season: season })
    setRunning(false)
    if (error) {
      setResult(`Progression failed: ${error.message}`)
    } else {
      setResult('Progression applied league-wide.')
      await refresh()
      await refreshLog()
    }
  }

  return (
    <Card className="p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
        Player Progression
      </p>
      <p className="mt-2 text-[13px] text-[var(--text-muted)]">
        Enter each player's {season} box score totals (10-game minimum to be eligible), then run
        progression once for the whole league. This only adjusts an overall that already exists —
        it won't invent one for players still waiting on real NHL 27 ratings. Use the resulting
        report to mirror the changes in NHL 27's Edit Player menu.
      </p>

      <div className="mt-4 flex items-center gap-3">
        <select
          value={teamId}
          onChange={(e) => setTeamId(e.target.value)}
          className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white"
        >
          {teams.map((t) => (
            <option key={t.id} value={t.id}>
              {t.city} {t.name}
            </option>
          ))}
        </select>
        <Button variant="secondary" onClick={saveStats} disabled={saving || roster.length === 0}>
          {saving ? 'Saving…' : 'Save Stats'}
        </Button>
        <Button onClick={runProgression} disabled={running}>
          {running ? 'Running…' : `Run Progression for ${season}`}
        </Button>
      </div>

      {roster.length > 0 && (
        <Card className="mt-4 overflow-x-auto">
          <table className="w-full text-left text-[12px]">
            <thead>
              <tr className="border-b border-[var(--border)] text-[10px] uppercase tracking-wide text-[var(--text-muted)]">
                <th className="px-2 py-2">Player</th>
                {STAT_FIELDS.map((f) => (
                  <th key={f.key} className="px-2 py-2">{f.label}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {roster.map((p) => {
                const d = drafts[p.id] ?? EMPTY_DRAFT
                return (
                  <tr key={p.id} className="border-b border-[var(--border)]/60 last:border-0">
                    <td className="px-2 py-1.5 font-semibold text-white">
                      {p.name} <span className="text-[var(--text-muted)]">{p.position}</span>
                    </td>
                    {STAT_FIELDS.map((f) => (
                      <td key={f.key} className="px-2 py-1.5">
                        <input
                          value={d[f.key]}
                          onChange={(e) => setField(p.id, f.key, e.target.value)}
                          className="w-14 rounded border border-[var(--border)] bg-[var(--bg)] px-1 py-1 text-white"
                        />
                      </td>
                    ))}
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Card>
      )}

      {result && <p className="mt-3 text-[13px] text-[var(--positive)]">{result}</p>}

      {log.length > 0 && (
        <div className="mt-4">
          <p className="mb-2 text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
            Recent Progression — {season}
          </p>
          <div className="space-y-1.5">
            {log.map((entry) => (
              <div
                key={entry.id}
                className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[12px]"
              >
                <span className="font-semibold text-white">{entry.playerName}</span>
                <span className="text-[var(--text-muted)]">
                  {entry.oldOverall} → {entry.newOverall} (
                  <span className={entry.delta >= 0 ? 'text-[var(--positive)]' : 'text-[var(--negative)]'}>
                    {entry.delta >= 0 ? '+' : ''}{entry.delta}
                  </span>
                  )
                </span>
                <span className="text-[var(--text-muted)]">{entry.note}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </Card>
  )
}

interface GmRow {
  id: string
  discordUsername: string | null
  guildNickname: string | null
  isCommissioner: boolean
  teamId: string | null
}

function ManageCommissioners() {
  const [rows, setRows] = useState<GmRow[]>([])
  const [loading, setLoading] = useState(true)
  const { user } = useAuth()

  const refresh = async () => {
    const [profilesRes, claimsRes] = await Promise.all([
      supabase.from('profiles').select('id, discord_username, guild_nickname, is_commissioner'),
      supabase.from('team_claims').select('team_id, user_id'),
    ])
    const claimByUser = new Map((claimsRes.data ?? []).map((c) => [c.user_id, c.team_id]))
    setRows(
      (profilesRes.data ?? []).map((p) => ({
        id: p.id,
        discordUsername: p.discord_username,
        guildNickname: p.guild_nickname,
        isCommissioner: p.is_commissioner,
        teamId: claimByUser.get(p.id) ?? null,
      })),
    )
    setLoading(false)
  }

  useEffect(() => {
    refresh()
  }, [])

  const toggle = async (row: GmRow) => {
    await supabase.from('profiles').update({ is_commissioner: !row.isCommissioner }).eq('id', row.id)
    await refresh()
  }

  if (loading) return <p className="text-[13px] text-[var(--text-muted)]">Loading GMs…</p>

  return (
    <Card className="overflow-x-auto">
      <table className="w-full text-left text-[13px]">
        <thead>
          <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
            <th className="px-3 py-2.5">Discord</th>
            <th className="px-3 py-2.5">Server Nickname</th>
            <th className="px-3 py-2.5">Team Claimed</th>
            <th className="px-3 py-2.5">Commissioner</th>
            <th className="px-3 py-2.5" />
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id} className="border-b border-[var(--border)]/60 last:border-0">
              <td className="px-3 py-2 font-semibold text-white">
                {row.discordUsername ?? '—'} {row.id === user?.id && <span className="text-[var(--text-muted)]">(you)</span>}
              </td>
              <td className="px-3 py-2 text-[var(--text-muted)]">{row.guildNickname ?? '—'}</td>
              <td className="px-3 py-2 text-[var(--text-muted)]">{row.teamId ?? 'Unclaimed'}</td>
              <td className="px-3 py-2">
                {row.isCommissioner ? (
                  <span className="rounded bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-bold uppercase text-amber-300">
                    Commissioner
                  </span>
                ) : (
                  '—'
                )}
              </td>
              <td className="px-3 py-2 text-right">
                <Button variant="secondary" onClick={() => toggle(row)}>
                  {row.isCommissioner ? 'Revoke' : 'Promote'}
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  )
}

const ACTION_LABELS: Record<string, string> = {
  advance_season: 'Advance Season',
  run_draft_lottery: 'Draft Lottery',
  draft_prospect: 'a draft pick',
  approve_trade: 'a trade approval',
  award_free_agent: 'a free-agent signing',
  apply_progression: 'a progression run',
}

function UndoLastActionCard() {
  const { refresh } = useLeagueData()
  const [lastAction, setLastAction] = useState<string | null>(null)
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<string | null>(null)

  const refreshLastAction = async () => {
    const { data } = await supabase
      .from('action_snapshots')
      .select('action')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    setLastAction(data?.action ?? null)
  }

  useEffect(() => {
    refreshLastAction()
  }, [])

  const runUndo = async () => {
    setRunning(true)
    const { error } = await supabase.rpc('undo_last_action')
    setRunning(false)
    if (error) {
      setResult(`Undo failed: ${error.message}`)
    } else {
      setResult('Restored to the state before that action.')
      await refresh()
      await refreshLastAction()
    }
  }

  if (!lastAction) return null

  return (
    <Card className="border-amber-500/30 bg-amber-500/10 p-5">
      <p className="text-[13px] text-amber-200">
        Last commissioner action: <span className="font-bold">{ACTION_LABELS[lastAction] ?? lastAction}</span>.
        This can still be undone (one level — undoing again after that isn't possible).
      </p>
      <Button variant="secondary" className="mt-3" onClick={runUndo} disabled={running}>
        {running ? 'Undoing…' : 'Undo Last Action'}
      </Button>
      {result && <p className="mt-3 text-[13px] text-[var(--positive)]">{result}</p>}
    </Card>
  )
}

function AdvanceSeasonCard() {
  const { season, teamsById, refresh } = useLeagueData()
  const [confirming, setConfirming] = useState(false)
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<string | null>(null)

  const startNextYear = () => {
    const [start] = season.split('-')
    const next = parseInt(start, 10) + 1
    return `${next}-${String((next + 1) % 100).padStart(2, '0')}`
  }

  const runAdvance = async () => {
    setRunning(true)
    const oldSeason = season
    const newSeason = startNextYear()
    const { error } = await supabase.rpc('advance_season')
    setRunning(false)
    setConfirming(false)
    if (error) {
      setResult(`Failed: ${error.message}`)
      return
    }

    setResult(`Advanced to the ${newSeason} season.`)
    await refresh()
    triggerNewsGeneration('season_advance', { oldSeason, newSeason })

    const { data: retired } = await supabase.from('retirement_log').select('*').eq('season', oldSeason)
    if (retired && retired.length > 0) {
      const players = retired.map((r) => ({ name: r.player_name, team: teamsById.get(r.team_id)?.abbr ?? r.team_id }))
      triggerNewsGeneration('retirement', { season: oldSeason, players }, retired.map((r) => r.team_id))
    }

    const { data: announced } = await supabase
      .from('players')
      .select('name, team_id')
      .eq('retirement_announced_season', newSeason)
    if (announced && announced.length > 0) {
      const players = announced.map((p) => ({ name: p.name, team: teamsById.get(p.team_id)?.abbr ?? p.team_id }))
      triggerNewsGeneration('retirement_announced', { season: newSeason, players }, announced.map((p) => p.team_id))
    }
  }

  return (
    <Card className="p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
        Season
      </p>
      <h2 className="mt-1 text-xl font-extrabold text-white">Currently: {season}</h2>
      <p className="mt-2 text-[13px] text-[var(--text-muted)]">
        Advancing to {startNextYear()} will: move every contract whose final season was {season}{' '}
        to free agency, count down every other contract's remaining term by one year, and open the
        next draft class.
      </p>

      <div className="mt-4 flex items-center gap-3">
        {!confirming ? (
          <Button onClick={() => setConfirming(true)}>Advance Season</Button>
        ) : (
          <>
            <Button onClick={runAdvance} disabled={running}>
              {running ? 'Advancing…' : `Confirm: advance to ${startNextYear()}`}
            </Button>
            <Button variant="secondary" onClick={() => setConfirming(false)} disabled={running}>
              Cancel
            </Button>
          </>
        )}
      </div>

      {result && <p className="mt-3 text-[13px] text-[var(--positive)]">{result}</p>}
    </Card>
  )
}

function TradeDeadlineCard() {
  const { tradeDeadline, refresh } = useLeagueData()
  const [value, setValue] = useState(tradeDeadline ? tradeDeadline.slice(0, 16) : '')
  const [saving, setSaving] = useState(false)
  const [result, setResult] = useState<string | null>(null)

  const save = async () => {
    setSaving(true)
    const { error } = await supabase
      .from('league_state')
      .update({ trade_deadline: value ? new Date(value).toISOString() : null })
      .eq('id', true)
    setSaving(false)
    if (error) setResult(`Failed: ${error.message}`)
    else {
      setResult(value ? 'Trade deadline set.' : 'Trade deadline cleared.')
      await refresh()
    }
  }

  return (
    <Card className="p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
        Trade Deadline
      </p>
      <p className="mt-2 text-[13px] text-[var(--text-muted)]">
        Once this passes, nobody — including the commissioner — can propose a new trade. Trades
        already pending can still be approved or rejected. Leave blank for no deadline.
      </p>
      <div className="mt-3 flex items-center gap-3">
        <input
          type="datetime-local"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white"
        />
        <Button onClick={save} disabled={saving}>
          {saving ? 'Saving…' : 'Save'}
        </Button>
      </div>
      {result && <p className="mt-3 text-[13px] text-[var(--positive)]">{result}</p>}
    </Card>
  )
}

function SeedTeamProspectsCard() {
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<string | null>(null)

  const run = async () => {
    setRunning(true)
    const { error } = await supabase.rpc('seed_team_prospects')
    setRunning(false)
    setResult(error ? `Failed: ${error.message}` : 'Seeded — teams without 5 prospects now have them.')
  }

  return (
    <Card className="p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">
        Team Prospect Pipelines
      </p>
      <p className="mt-2 text-[13px] text-[var(--text-muted)]">
        Gives every team without at least 5 organizational prospects a fresh set of 5. Safe to run
        more than once — teams that already have 5 are skipped.
      </p>
      <Button className="mt-3" onClick={run} disabled={running}>
        {running ? 'Seeding…' : 'Seed Team Prospects'}
      </Button>
      {result && <p className="mt-3 text-[13px] text-[var(--positive)]">{result}</p>}
    </Card>
  )
}

export default function CommissionerTools() {
  const { profile, loading } = useAuth()

  if (loading) return <p className="text-[var(--text-muted)]">Loading…</p>
  if (!profile?.is_commissioner) return <Navigate to="/" replace />

  return (
    <div className="space-y-6">
      <PageHeader title="Commissioner Tools" description="Season control and league administration." />

      <UndoLastActionCard />

      <AdvanceSeasonCard />

      <PlayerProgressionCard />

      <TradeDeadlineCard />

      <SeedTeamProspectsCard />

      <div>
        <h2 className="mb-3 text-sm font-extrabold uppercase tracking-wide text-white">
          Manage Commissioners
        </h2>
        <ManageCommissioners />
      </div>
    </div>
  )
}
