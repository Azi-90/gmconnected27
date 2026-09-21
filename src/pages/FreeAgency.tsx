import { Fragment, useEffect, useMemo, useState } from 'react'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { useTeamClaims } from '../lib/useTeamClaims'
import { useFreeAgentOffers } from '../lib/useFreeAgentOffers'
import { triggerNewsGeneration } from '../lib/newsTrigger'
import { supabase } from '../lib/supabase'
import type { FreeAgentOffer } from '../types'
import { Card, PageHeader, Button } from '../components/ui'
import { formatMoney, NHL_MIN_SALARY, nhlMaxSalary } from '../lib/format'

function useNextResolutionCountdown() {
  const [label, setLabel] = useState('')

  useEffect(() => {
    const update = () => {
      const now = new Date()
      const next = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 5, 0, 0))
      if (next.getTime() <= now.getTime()) next.setUTCDate(next.getUTCDate() + 1)
      const ms = next.getTime() - now.getTime()
      const hours = Math.floor(ms / 3_600_000)
      const mins = Math.floor((ms % 3_600_000) / 60_000)
      setLabel(`${hours}h ${mins}m`)
    }
    update()
    const id = setInterval(update, 60_000)
    return () => clearInterval(id)
  }, [])

  return label
}

function OfferForm({
  freeAgentName,
  myTeamId,
  isCommissioner,
  onSubmit,
  onCancel,
}: {
  freeAgentName: string
  myTeamId: string | null
  isCommissioner: boolean
  onSubmit: (teamId: string, aav: number, termYears: number) => void
  onCancel: () => void
}) {
  const { teams, salaryCap } = useLeagueData()
  const [teamId, setTeamId] = useState(myTeamId ?? teams[0]?.id ?? '')
  const [aav, setAav] = useState('')
  const [termYears, setTermYears] = useState('1')

  const maxAav = nhlMaxSalary(salaryCap)
  const aavNumber = Number(aav)
  const termNumber = Number(termYears)
  const canSubmit =
    teamId && aavNumber >= NHL_MIN_SALARY && aavNumber <= maxAav && termNumber >= 1 && termNumber <= 7

  return (
    <Card className="mt-2 space-y-3 p-4">
      <p className="text-[13px] text-[var(--text-muted)]">
        Offer to <span className="font-bold text-white">{freeAgentName}</span>
      </p>
      <div className="grid gap-3 sm:grid-cols-3">
        {isCommissioner ? (
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
        ) : (
          <div className="flex items-center rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white">
            {teams.find((t) => t.id === teamId)?.city} {teams.find((t) => t.id === teamId)?.name}
          </div>
        )}
        <input
          type="number"
          min={NHL_MIN_SALARY}
          max={maxAav}
          value={aav}
          onChange={(e) => setAav(e.target.value)}
          placeholder="AAV ($)"
          className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white placeholder:text-[var(--text-muted)]"
        />
        <input
          type="number"
          min={1}
          max={7}
          value={termYears}
          onChange={(e) => setTermYears(e.target.value)}
          placeholder="Term (years)"
          className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white placeholder:text-[var(--text-muted)]"
        />
      </div>
      <p className="text-[11px] text-[var(--text-muted)]">
        NHL rules: {formatMoney(NHL_MIN_SALARY)}–{formatMoney(maxAav)} AAV, up to 7 years for a new-team signing.
      </p>
      <div className="flex justify-end gap-3">
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button disabled={!canSubmit} onClick={() => onSubmit(teamId, aavNumber, termNumber)}>
          Submit Offer
        </Button>
      </div>
    </Card>
  )
}

function OfferRow({
  offer,
  isCommissioner,
  isProposer,
  rfaBlocked,
  onDecide,
  onWithdraw,
}: {
  offer: FreeAgentOffer
  isCommissioner: boolean
  isProposer: boolean
  rfaBlocked: boolean
  onDecide: (id: string, status: 'awarded' | 'declined') => void
  onWithdraw: (id: string) => void
}) {
  const { teamsById } = useLeagueData()
  const team = teamsById.get(offer.teamId)
  if (!team) return null

  const statusStyles: Record<FreeAgentOffer['status'], string> = {
    pending: 'bg-amber-500/15 text-amber-300 border-amber-500/30',
    leading: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
    outbid: 'bg-slate-500/15 text-slate-300 border-slate-500/30',
    awarded: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
    declined: 'bg-red-500/15 text-red-300 border-red-500/30',
  }
  const isLive = offer.status === 'pending' || offer.status === 'leading' || offer.status === 'outbid'

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2">
      <div className="text-[13px]">
        <span className="font-bold text-white">{team.abbr}</span>{' '}
        <span className="text-[var(--text-muted)]">
          {formatMoney(offer.aav)} × {offer.termYears}yr
        </span>
        {rfaBlocked && (
          <span className="ml-2 text-[11px] text-amber-300">awaiting RFA waiver from original team</span>
        )}
      </div>
      <div className="flex items-center gap-2">
        <span className={`rounded border px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${statusStyles[offer.status]}`}>
          {offer.status}
        </span>
        {offer.status === 'leading' && isCommissioner && (
          <>
            <Button onClick={() => onDecide(offer.id, 'awarded')} disabled={rfaBlocked}>
              Award
            </Button>
            <Button variant="secondary" onClick={() => onDecide(offer.id, 'declined')}>
              Decline
            </Button>
          </>
        )}
        {offer.status === 'pending' && isCommissioner && (
          <Button variant="secondary" onClick={() => onDecide(offer.id, 'declined')}>
            Decline
          </Button>
        )}
        {isLive && !isCommissioner && isProposer && (
          <Button variant="secondary" onClick={() => onWithdraw(offer.id)}>
            Withdraw
          </Button>
        )}
      </div>
    </div>
  )
}

export default function FreeAgency() {
  const { loading: leagueLoading, freeAgents, season, refresh, teamsById } = useLeagueData()
  const { user, profile } = useAuth()
  const { claims } = useTeamClaims()
  const { offers, pendingCounts, loading: offersLoading, submitOffer, decideOffer, withdrawOffer } = useFreeAgentOffers()
  const [openOffer, setOpenOffer] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const nextResolution = useNextResolutionCountdown()

  const myTeamId = user ? [...claims.values()].find((c) => c.userId === user.id)?.teamId ?? null : null
  const isCommissioner = Boolean(profile?.is_commissioner)
  const canBid = Boolean(myTeamId || isCommissioner)

  const offersByFreeAgent = useMemo(() => {
    const map = new Map<string, FreeAgentOffer[]>()
    for (const offer of offers) {
      const list = map.get(offer.freeAgentId) ?? []
      list.push(offer)
      map.set(offer.freeAgentId, list)
    }
    return map
  }, [offers])

  if (leagueLoading || offersLoading) {
    return <p className="text-[var(--text-muted)]">Loading league data…</p>
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Free Agency"
        description={`${season} · ${freeAgents.length} unsigned players · bidding is blind — offers stay hidden until nightly resolution picks the leading bid, then the commissioner awards it.`}
        actions={
          <span className="text-[12px] font-semibold text-[var(--text-muted)]">
            Next resolution in <span className="text-white">{nextResolution || '…'}</span> (12:00 AM EST)
          </span>
        }
      />

      {actionError && (
        <Card className="border-red-500/30 bg-red-500/10 px-4 py-3 text-[13px] text-red-300">
          {actionError}
        </Card>
      )}

      <Card className="max-h-[720px] overflow-auto">
        <table className="w-full text-left text-sm">
          <thead className="sticky top-0 z-10 bg-[var(--bg-panel)]">
            <tr className="border-b border-[var(--border)] text-[11px] uppercase tracking-wide text-[var(--text-muted)]">
              <th className="px-3 py-2.5">Player</th>
              <th className="px-3 py-2.5">Pos</th>
              <th className="px-3 py-2.5">OVR</th>
              <th className="px-3 py-2.5">Age</th>
              <th className="px-3 py-2.5">Last Team</th>
              <th className="px-3 py-2.5">Last Cap Hit</th>
              <th className="px-3 py-2.5">Status</th>
              <th className="px-3 py-2.5" />
            </tr>
          </thead>
          <tbody>
            {freeAgents.map((fa, i) => {
              const faOffers = offersByFreeAgent.get(fa.id) ?? []
              const leadingOffer = faOffers.find((o) => o.status === 'leading')
              const blindCount = pendingCounts.get(fa.id) ?? 0
              return (
                <Fragment key={fa.id}>
                  <tr
                    className={`border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                      i % 2 === 1 ? 'bg-white/[0.015]' : ''
                    }`}
                  >
                    <td className="px-3 py-2 font-semibold text-white">{fa.name}</td>
                    <td className="px-3 py-2">{fa.position}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">{fa.overall ?? '—'}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">{fa.age}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">{fa.lastTeam ?? '—'}</td>
                    <td className="px-3 py-2 text-[var(--text-muted)]">
                      {fa.lastCapHit ? formatMoney(fa.lastCapHit) : '—'}
                    </td>
                    <td className="px-3 py-2">
                      <span
                        className={`inline-flex rounded border px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${
                          fa.status === 'UFA'
                            ? 'border-sky-500/30 bg-sky-500/15 text-sky-300'
                            : 'border-amber-500/30 bg-amber-500/15 text-amber-300'
                        }`}
                      >
                        {fa.status}
                      </span>
                    </td>
                    <td className="px-3 py-2 text-right">
                      <Button
                        variant="secondary"
                        onClick={() => setOpenOffer(openOffer === fa.id ? null : fa.id)}
                      >
                        {leadingOffer
                          ? `Leading ${formatMoney(leadingOffer.aav)}`
                          : blindCount > 0
                            ? `${blindCount} Blind Bid${blindCount > 1 ? 's' : ''}`
                            : 'Offers'}
                      </Button>
                    </td>
                  </tr>
                  {openOffer === fa.id && (
                    <tr>
                      <td colSpan={8} className="bg-[var(--bg-panel-alt)]/40 px-3 py-3">
                        {fa.status === 'RFA' && !fa.rfaWaived && (
                          <div className="mb-3 flex flex-wrap items-center justify-between gap-2 rounded-md border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-[13px] text-amber-200">
                            <span>
                              Restricted free agent — {fa.lastTeam ?? 'the original team'} has first right of
                              refusal. Outside offers can't be awarded until they waive it.
                            </span>
                            {(isCommissioner || myTeamId === fa.lastTeam) && (
                              <Button
                                variant="secondary"
                                onClick={async () => {
                                  const { error } = await supabase.rpc('waive_rfa_rights', { p_free_agent_id: fa.id })
                                  if (error) setActionError(error.message)
                                  else {
                                    setActionError(null)
                                    await refresh()
                                  }
                                }}
                              >
                                Waive RFA Rights
                              </Button>
                            )}
                          </div>
                        )}
                        {blindCount > 0 && !leadingOffer && (
                          <p className="mb-3 text-[12px] text-[var(--text-muted)]">
                            {blindCount} blind bid{blindCount > 1 ? 's' : ''} in progress — amounts stay hidden until
                            tonight's resolution at 12:00 AM EST.
                          </p>
                        )}
                        {faOffers.length > 0 && (
                          <div className="mb-3 space-y-1.5">
                            {faOffers.map((offer) => (
                              <OfferRow
                                key={offer.id}
                                offer={offer}
                                isCommissioner={isCommissioner}
                                isProposer={offer.teamId === myTeamId}
                                rfaBlocked={fa.status === 'RFA' && !fa.rfaWaived && offer.teamId !== fa.lastTeam}
                                onDecide={async (id, status) => {
                                  const error = await decideOffer(id, status)
                                  if (error) {
                                    setActionError(error.message)
                                  } else {
                                    setActionError(null)
                                    await refresh()
                                    if (status === 'awarded') {
                                      const team = teamsById.get(offer.teamId)
                                      if (team) {
                                        triggerNewsGeneration(
                                          'free_agency',
                                          {
                                            team: `${team.city} ${team.name}`,
                                            playerName: fa.name,
                                            aav: offer.aav,
                                            termYears: offer.termYears,
                                          },
                                          [offer.teamId],
                                        )
                                      }
                                    }
                                  }
                                }}
                                onWithdraw={withdrawOffer}
                              />
                            ))}
                          </div>
                        )}
                        {canBid ? (
                          <OfferForm
                            freeAgentName={fa.name}
                            myTeamId={myTeamId}
                            isCommissioner={isCommissioner}
                            onCancel={() => setOpenOffer(null)}
                            onSubmit={async (teamId, aav, termYears) => {
                              const error = await submitOffer({ freeAgentId: fa.id, teamId, aav, termYears })
                              if (!error) setOpenOffer(null)
                            }}
                          />
                        ) : (
                          <p className="text-[13px] text-[var(--text-muted)]">
                            {user ? 'Claim a club to submit an offer.' : 'Sign in and claim a club to submit an offer.'}
                          </p>
                        )}
                      </td>
                    </tr>
                  )}
                </Fragment>
              )
            })}
          </tbody>
        </table>
      </Card>
    </div>
  )
}
