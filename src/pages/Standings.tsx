import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { supabase } from '../lib/supabase'
import { Card, PageHeader, TeamBadge, Button } from '../components/ui'

interface StandingsRow {
  teamId: string
  wins: number
  losses: number
  otLosses: number
}

export default function Standings() {
  const { profile } = useAuth()
  const { loading, teams, season } = useLeagueData()
  const [rows, setRows] = useState<Map<string, StandingsRow>>(new Map())
  const [editing, setEditing] = useState<Record<string, { wins: string; losses: string; otLosses: string }>>({})
  const [saving, setSaving] = useState<string | null>(null)

  const refresh = async () => {
    const { data } = await supabase.from('standings').select('*').eq('season', season)
    const next = new Map<string, StandingsRow>()
    for (const row of data ?? []) {
      next.set(row.team_id, { teamId: row.team_id, wins: row.wins, losses: row.losses, otLosses: row.ot_losses })
    }
    setRows(next)
  }

  useEffect(() => {
    if (!loading) refresh()
  }, [loading, season])

  if (loading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  const startEdit = (teamId: string) => {
    const existing = rows.get(teamId)
    setEditing((prev) => ({
      ...prev,
      [teamId]: {
        wins: String(existing?.wins ?? 0),
        losses: String(existing?.losses ?? 0),
        otLosses: String(existing?.otLosses ?? 0),
      },
    }))
  }

  const save = async (teamId: string) => {
    const draft = editing[teamId]
    if (!draft) return
    setSaving(teamId)
    await supabase.from('standings').upsert({
      team_id: teamId,
      season,
      wins: parseInt(draft.wins, 10) || 0,
      losses: parseInt(draft.losses, 10) || 0,
      ot_losses: parseInt(draft.otLosses, 10) || 0,
    })
    setSaving(null)
    setEditing((prev) => {
      const next = { ...prev }
      delete next[teamId]
      return next
    })
    await refresh()
  }

  const sorted = [...teams].sort((a, b) => {
    const ra = rows.get(a.id)
    const rb = rows.get(b.id)
    const ptsA = ra ? ra.wins * 2 + ra.otLosses : -1
    const ptsB = rb ? rb.wins * 2 + rb.otLosses : -1
    return ptsB - ptsA
  })

  return (
    <div className="space-y-6">
      <PageHeader
        title="Standings"
        description={
          <>
            {season} season · entered by the commissioner from the games played in NHL 27.{' '}
            {profile?.is_commissioner && 'Click a row to edit its record.'}
          </>
        }
      />

      <div>
        <h2 className="mb-3 text-sm font-extrabold uppercase tracking-wide text-white">
          League Standings
        </h2>
        <Card className="max-h-[720px] overflow-auto">
          <table className="w-full text-left text-sm">
            <thead className="sticky top-0 z-10 bg-[var(--bg-panel)]">
              <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
                <th className="px-3 py-2.5">Rank</th>
                <th className="px-3 py-2.5">Club</th>
                <th className="px-3 py-2.5">GP</th>
                <th className="px-3 py-2.5">W</th>
                <th className="px-3 py-2.5">L</th>
                <th className="px-3 py-2.5">OTL</th>
                <th className="px-3 py-2.5">PTS</th>
                {profile?.is_commissioner && <th className="px-3 py-2.5" />}
              </tr>
            </thead>
            <tbody>
              {sorted.map((team, i) => {
                const r = rows.get(team.id)
                const gp = r ? r.wins + r.losses + r.otLosses : 0
                const pts = r ? r.wins * 2 + r.otLosses : 0
                const draft = editing[team.id]
                return (
                  <tr
                    key={team.id}
                    className={`border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                      i % 2 === 1 ? 'bg-white/[0.015]' : ''
                    }`}
                  >
                    <td className="px-3 py-2">
                      <span
                        className={`inline-flex h-5 w-5 items-center justify-center rounded-full text-[11px] font-bold ${
                          i < 3 ? 'bg-[var(--accent-soft)] text-[var(--accent-hover)]' : 'text-[var(--text-muted)]'
                        }`}
                      >
                        {i + 1}
                      </span>
                    </td>
                    <td className="px-3 py-2">
                      <Link to={`/teams/${team.id}`} className="flex items-center gap-2.5 hover:underline">
                        <TeamBadge team={team} size={24} />
                        <span className="font-bold text-white">{team.city} {team.name}</span>
                      </Link>
                    </td>
                    {draft ? (
                      <>
                        <td className="px-3 py-2 text-[var(--text-muted)]">
                          {(parseInt(draft.wins, 10) || 0) + (parseInt(draft.losses, 10) || 0) + (parseInt(draft.otLosses, 10) || 0)}
                        </td>
                        <td className="px-3 py-2">
                          <input
                            value={draft.wins}
                            onChange={(e) => setEditing((p) => ({ ...p, [team.id]: { ...draft, wins: e.target.value } }))}
                            className="w-14 rounded border border-[var(--border)] bg-[var(--bg)] px-1.5 py-1 text-white"
                          />
                        </td>
                        <td className="px-3 py-2">
                          <input
                            value={draft.losses}
                            onChange={(e) => setEditing((p) => ({ ...p, [team.id]: { ...draft, losses: e.target.value } }))}
                            className="w-14 rounded border border-[var(--border)] bg-[var(--bg)] px-1.5 py-1 text-white"
                          />
                        </td>
                        <td className="px-3 py-2">
                          <input
                            value={draft.otLosses}
                            onChange={(e) => setEditing((p) => ({ ...p, [team.id]: { ...draft, otLosses: e.target.value } }))}
                            className="w-14 rounded border border-[var(--border)] bg-[var(--bg)] px-1.5 py-1 text-white"
                          />
                        </td>
                        <td className="px-3 py-2 text-[var(--text-muted)]">—</td>
                        <td className="px-3 py-2 text-right">
                          <Button onClick={() => save(team.id)} disabled={saving === team.id}>
                            {saving === team.id ? 'Saving…' : 'Save'}
                          </Button>
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="px-3 py-2 text-[var(--text-muted)]">{gp}</td>
                        <td className="px-3 py-2 text-[var(--text-muted)]">{r?.wins ?? 0}</td>
                        <td className="px-3 py-2 text-[var(--text-muted)]">{r?.losses ?? 0}</td>
                        <td className="px-3 py-2 text-[var(--text-muted)]">{r?.otLosses ?? 0}</td>
                        <td className="px-3 py-2 font-bold text-white">{pts}</td>
                        {profile?.is_commissioner && (
                          <td className="px-3 py-2 text-right">
                            <Button variant="secondary" onClick={() => startEdit(team.id)}>
                              Edit
                            </Button>
                          </td>
                        )}
                      </>
                    )}
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Card>
      </div>
    </div>
  )
}
