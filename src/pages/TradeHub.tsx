import { useEffect, useMemo, useState } from 'react'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { useTeamClaims } from '../lib/useTeamClaims'
import { useTrades } from '../lib/useTrades'
import { triggerNewsGeneration } from '../lib/newsTrigger'
import { supabase } from '../lib/supabase'
import type { Trade, TradeAsset, DraftPick } from '../types'
import { Card, PageHeader, TeamBadge, Button } from '../components/ui'

function assetLabel(asset: TradeAsset): string {
  return asset.type === 'pick' ? asset.label : asset.playerName
}

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

function AssetPicker({
  teamId,
  selected,
  onChange,
}: {
  teamId: string
  selected: TradeAsset[]
  onChange: (assets: TradeAsset[]) => void
}) {
  const { playersByTeam, teamsById } = useLeagueData()
  const roster = playersByTeam(teamId)
  const [picks, setPicks] = useState<DraftPick[]>([])

  useEffect(() => {
    let active = true
    supabase
      .from('draft_picks')
      .select('*')
      .eq('current_owner_team_id', teamId)
      .eq('used', false)
      .order('draft_year')
      .then(({ data }) => {
        if (active) setPicks((data ?? []).map(mapPickRow))
      })
    return () => {
      active = false
    }
  }, [teamId])

  const pickLabel = (pick: DraftPick) => {
    const originalAbbr = teamsById.get(pick.originalTeamId)?.abbr
    const via = pick.originalTeamId !== teamId && originalAbbr ? ` (via ${originalAbbr})` : ''
    const positionLabel = pick.pickNumber ? `#${pick.pickNumber} overall` : '1st round'
    return `${pick.draftYear} Pick — ${positionLabel}${via}`
  }

  return (
    <div className="max-h-40 space-y-1 overflow-y-auto rounded-md border border-[var(--border)] bg-[var(--bg)] p-2">
      {roster.map((p) => {
        const checked = selected.some((a) => a.type === 'player' && a.playerId === p.id)
        return (
          <label key={p.id} className="flex items-center gap-2 rounded px-1.5 py-1 text-[13px] hover:bg-[var(--bg-panel-alt)]">
            <input
              type="checkbox"
              checked={checked}
              onChange={(e) => {
                if (e.target.checked) {
                  onChange([...selected, { type: 'player', playerId: p.id, playerName: p.name }])
                } else {
                  onChange(selected.filter((a) => !(a.type === 'player' && a.playerId === p.id)))
                }
              }}
            />
            <span className="text-white">{p.name}</span>
            <span className="text-[var(--text-muted)]">{p.position}</span>
          </label>
        )
      })}
      {picks.length > 0 && (
        <>
          <div className="mt-1 border-t border-[var(--border)] pt-1 text-[10px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
            Draft Picks
          </div>
          {picks.map((pick) => {
            const checked = selected.some((a) => a.type === 'pick' && a.pickId === pick.id)
            return (
              <label key={pick.id} className="flex items-center gap-2 rounded px-1.5 py-1 text-[13px] hover:bg-[var(--bg-panel-alt)]">
                <input
                  type="checkbox"
                  checked={checked}
                  onChange={(e) => {
                    if (e.target.checked) {
                      onChange([...selected, { type: 'pick', pickId: pick.id, label: pickLabel(pick) }])
                    } else {
                      onChange(selected.filter((a) => !(a.type === 'pick' && a.pickId === pick.id)))
                    }
                  }}
                />
                <span className="text-white">{pickLabel(pick)}</span>
              </label>
            )
          })}
        </>
      )}
    </div>
  )
}

function ProposeTradeForm({
  myTeamId,
  isCommissioner,
  onSubmit,
  onCancel,
}: {
  myTeamId: string | null
  isCommissioner: boolean
  onSubmit: (trade: Omit<Trade, 'id' | 'status' | 'createdAt'>) => void
  onCancel: () => void
}) {
  const { teams } = useLeagueData()
  const [fromTeamId, setFromTeamId] = useState(myTeamId ?? teams[0]?.id ?? '')
  const [toTeamId, setToTeamId] = useState(teams.find((t) => t.id !== fromTeamId)?.id ?? '')
  const [assetsFromTeam, setAssetsFromTeam] = useState<TradeAsset[]>([])
  const [assetsToTeam, setAssetsToTeam] = useState<TradeAsset[]>([])
  const [note, setNote] = useState('')

  const canSubmit =
    fromTeamId !== toTeamId && (assetsFromTeam.length > 0 || assetsToTeam.length > 0)

  return (
    <Card className="space-y-4 p-5">
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className="mb-1 block text-[11px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
            Sending Club
          </label>
          {isCommissioner ? (
            <select
              value={fromTeamId}
              onChange={(e) => setFromTeamId(e.target.value)}
              className="w-full rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white"
            >
              {teams.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.city} {t.name}
                </option>
              ))}
            </select>
          ) : (
            <div className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white">
              {teams.find((t) => t.id === fromTeamId)?.city} {teams.find((t) => t.id === fromTeamId)?.name}
            </div>
          )}
          <div className="mt-2">
            <AssetPicker teamId={fromTeamId} selected={assetsFromTeam} onChange={setAssetsFromTeam} />
          </div>
        </div>

        <div>
          <label className="mb-1 block text-[11px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
            Receiving Club
          </label>
          <select
            value={toTeamId}
            onChange={(e) => setToTeamId(e.target.value)}
            className="w-full rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white"
          >
            {teams.filter((t) => t.id !== fromTeamId).map((t) => (
              <option key={t.id} value={t.id}>
                {t.city} {t.name}
              </option>
            ))}
          </select>
          <div className="mt-2">
            <AssetPicker teamId={toTeamId} selected={assetsToTeam} onChange={setAssetsToTeam} />
          </div>
        </div>
      </div>

      <div>
        <label className="mb-1 block text-[11px] font-bold uppercase tracking-wide text-[var(--text-muted)]">
          Note (optional)
        </label>
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={2}
          placeholder="Retained salary, draft picks, conditions..."
          className="w-full rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white placeholder:text-[var(--text-muted)]/70"
        />
      </div>

      <div className="flex justify-end gap-3">
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          disabled={!canSubmit}
          onClick={() => onSubmit({ fromTeamId, toTeamId, assetsFromTeam, assetsToTeam, note })}
        >
          Submit Offer
        </Button>
      </div>
    </Card>
  )
}

function TradeRow({
  trade,
  myTeamId,
  isCommissioner,
  onDecide,
  onRetract,
}: {
  trade: Trade
  myTeamId: string | null
  isCommissioner: boolean
  onDecide: (id: string, status: 'gm_approved' | 'approved' | 'rejected') => void
  onRetract: (id: string) => void
}) {
  const { teamsById } = useLeagueData()
  const fromTeam = teamsById.get(trade.fromTeamId)
  const toTeam = teamsById.get(trade.toTeamId)
  if (!fromTeam || !toTeam) return null

  const isReceivingGm = myTeamId === trade.toTeamId
  const gmCanDecide = trade.status === 'pending' && (isCommissioner || isReceivingGm)
  const commissionerCanDecide = trade.status === 'gm_approved' && isCommissioner
  const canRetract = trade.status === 'pending' && (isCommissioner || myTeamId === trade.fromTeamId)
  const waitingOnCommissioner = trade.status === 'gm_approved' && !isCommissioner

  const statusStyles: Record<Trade['status'], string> = {
    pending: 'bg-amber-500/15 text-amber-300 border-amber-500/30',
    gm_approved: 'bg-sky-500/15 text-sky-300 border-sky-500/30',
    approved: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
    rejected: 'bg-red-500/15 text-red-300 border-red-500/30',
  }

  const statusLabels: Record<Trade['status'], string> = {
    pending: 'pending',
    gm_approved: 'awaiting commissioner',
    approved: 'approved',
    rejected: 'rejected',
  }

  return (
    <Card className="p-4">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-1 flex-wrap items-center gap-4">
          <div className="flex items-center gap-2">
            <TeamBadge team={fromTeam} size={28} />
            <div>
              <div className="text-[13px] font-bold text-white">{fromTeam.abbr} sends</div>
              <div className="text-[13px] text-[var(--text-muted)]">
                {trade.assetsFromTeam.map(assetLabel).join(', ') || '—'}
              </div>
            </div>
          </div>
          <span className="text-[var(--text-muted)]">⇄</span>
          <div className="flex items-center gap-2">
            <TeamBadge team={toTeam} size={28} />
            <div>
              <div className="text-[13px] font-bold text-white">{toTeam.abbr} sends</div>
              <div className="text-[13px] text-[var(--text-muted)]">
                {trade.assetsToTeam.map(assetLabel).join(', ') || '—'}
              </div>
            </div>
          </div>
        </div>
        <span className={`rounded border px-2 py-1 text-[11px] font-bold uppercase tracking-wide ${statusStyles[trade.status]}`}>
          {statusLabels[trade.status]}
        </span>
      </div>
      {trade.note && <p className="mt-2 text-[13px] text-[var(--text-muted)]">{trade.note}</p>}
      {waitingOnCommissioner && (
        <p className="mt-3 text-[13px] text-[var(--text-muted)]">
          The receiving GM has signed off — waiting on the commissioner for final approval.
        </p>
      )}
      {(gmCanDecide || commissionerCanDecide || canRetract) && (
        <div className="mt-3 flex gap-2">
          {gmCanDecide && (
            <>
              <Button onClick={() => onDecide(trade.id, 'gm_approved')}>Approve</Button>
              <Button variant="secondary" onClick={() => onDecide(trade.id, 'rejected')}>
                Reject
              </Button>
            </>
          )}
          {commissionerCanDecide && (
            <>
              <Button onClick={() => onDecide(trade.id, 'approved')}>Final Approve</Button>
              <Button variant="secondary" onClick={() => onDecide(trade.id, 'rejected')}>
                Reject
              </Button>
            </>
          )}
          {canRetract && !gmCanDecide && (
            <Button variant="secondary" onClick={() => onRetract(trade.id)}>
              Retract Offer
            </Button>
          )}
        </div>
      )}
    </Card>
  )
}

function DeadlineBanner({ tradeDeadline }: { tradeDeadline: string | null }) {
  if (!tradeDeadline) return null
  const deadline = new Date(tradeDeadline)
  const diffMs = deadline.getTime() - Date.now()
  const passed = diffMs <= 0

  if (passed) {
    return (
      <Card className="border-red-500/30 bg-red-500/10 px-4 py-3 text-[13px] text-red-300">
        The trade deadline passed on {deadline.toLocaleString()}. No new trades can be proposed —
        trades already in progress can still be finalized.
      </Card>
    )
  }

  const days = Math.floor(diffMs / (1000 * 60 * 60 * 24))
  const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
  return (
    <Card className="border-amber-500/30 bg-amber-500/10 px-4 py-3 text-[13px] text-amber-200">
      Trade deadline: {deadline.toLocaleString()} — {days}d {hours}h remaining.
    </Card>
  )
}

export default function TradeHub() {
  const { loading: leagueLoading, teamsById, tradeDeadline } = useLeagueData()
  const { user, profile } = useAuth()
  const { claims } = useTeamClaims()
  const { trades, loading: tradesLoading, proposeTrade, decideTrade, retractTrade } = useTrades()
  const [showForm, setShowForm] = useState(false)
  const [filter, setFilter] = useState<'pending' | 'settled' | 'all'>('pending')

  const myTeamId = user ? [...claims.values()].find((c) => c.userId === user.id)?.teamId ?? null : null
  const isCommissioner = Boolean(profile?.is_commissioner)
  const deadlinePassed = Boolean(tradeDeadline && new Date(tradeDeadline).getTime() <= Date.now())
  const canPropose = Boolean((myTeamId || isCommissioner) && !deadlinePassed)

  const handleDecide = async (id: string, status: 'gm_approved' | 'approved' | 'rejected') => {
    const trade = trades.find((t) => t.id === id)
    const error = await decideTrade(id, status)
    if (!error && status === 'approved' && trade) {
      const fromTeam = teamsById.get(trade.fromTeamId)
      const toTeam = teamsById.get(trade.toTeamId)
      if (fromTeam && toTeam) {
        triggerNewsGeneration(
          'trade',
          {
            fromTeam: `${fromTeam.city} ${fromTeam.name}`,
            toTeam: `${toTeam.city} ${toTeam.name}`,
            assetsFromTeam: trade.assetsFromTeam.map(assetLabel),
            assetsToTeam: trade.assetsToTeam.map(assetLabel),
            note: trade.note,
          },
          [trade.fromTeamId, trade.toTeamId],
        )
      }
    }
  }

  const visible = useMemo(() => {
    if (filter === 'all') return trades
    if (filter === 'pending') return trades.filter((t) => t.status === 'pending' || t.status === 'gm_approved')
    return trades.filter((t) => t.status === 'approved' || t.status === 'rejected')
  }, [trades, filter])

  if (leagueLoading || tradesLoading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Trade Hub"
        description="Every deal starts here. A GM posts an offer, the receiving club approves it, the commissioner gives final sign-off, and the trade moves the players immediately — then the commissioner replicates it in NHL 27. The hub is the league's source of truth."
        actions={
          <div className="flex overflow-hidden rounded-md border border-[var(--border)]">
            {(['pending', 'settled', 'all'] as const).map((key) => (
              <button
                key={key}
                onClick={() => setFilter(key)}
                className={`px-3 py-1.5 text-[12px] font-bold uppercase tracking-wide transition-colors ${
                  filter === key ? 'bg-[var(--accent)] text-white' : 'text-[var(--text-muted)] hover:text-white'
                }`}
              >
                {key}
              </button>
            ))}
          </div>
        }
      />

      <DeadlineBanner tradeDeadline={tradeDeadline} />

      {!canPropose && !deadlinePassed && (
        <Card className="px-4 py-3 text-[13px] text-[var(--text-muted)]">
          {user ? 'Claim a club to propose trades.' : 'Sign in and claim a club to propose trades.'}
        </Card>
      )}

      {canPropose && !showForm && <Button onClick={() => setShowForm(true)}>Propose a Trade</Button>}

      {showForm && (
        <ProposeTradeForm
          myTeamId={myTeamId}
          isCommissioner={isCommissioner}
          onCancel={() => setShowForm(false)}
          onSubmit={async (trade) => {
            const error = await proposeTrade(trade)
            if (!error) setShowForm(false)
          }}
        />
      )}

      {visible.length === 0 ? (
        <Card className="px-5 py-8 text-center text-[14px] text-[var(--text-muted)]">
          Nothing here yet. GMs post offers from the GM Desk.
        </Card>
      ) : (
        <div className="space-y-3">
          {visible.map((trade) => (
            <TradeRow
              key={trade.id}
              trade={trade}
              myTeamId={myTeamId}
              isCommissioner={isCommissioner}
              onDecide={handleDecide}
              onRetract={retractTrade}
            />
          ))}
        </div>
      )}
    </div>
  )
}
