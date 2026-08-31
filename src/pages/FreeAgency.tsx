import { Fragment, useMemo, useState } from 'react'
import { useAuth } from '../lib/AuthContext'
import { useLeagueData } from '../lib/LeagueDataContext'
import { useTeamClaims } from '../lib/useTeamClaims'
import { useFreeAgentOffers } from '../lib/useFreeAgentOffers'
import { triggerNewsGeneration } from '../lib/newsTrigger'
import { supabase } from '../lib/supabase'
import type { FreeAgentOffer } from '../types'
import { Card, PageHeader, Button } from '../components/ui'
import { formatMoney } from '../lib/format'

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
  const { teams } = useLeagueData()
  const [teamId, setTeamId] = useState(myTeamId ?? teams[0]?.id ?? '')
  const [aav, setAav] = useState('')
  const [termYears, setTermYears] = useState('1')

  const aavNumber = Number(aav)
  const termNumber = Number(termYears)
  const canSubmit = teamId && aavNumber > 0 && termNumber >= 1 && termNumber <= 8

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
          min={1}
          value={aav}
          onChange={(e) => setAav(e.target.value)}
          placeholder="AAV ($)"
          className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white placeholder:text-[var(--text-muted)]"
        />
        <input
          type="number"
          min={1}
          max={8}
          value={termYears}
          onChange={(e) => setTermYears(e.target.value)}
          placeholder="Term (years)"
          className="rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-[13px] text-white placeholder:text-[var(--text-muted)]"
        />
      </div>
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
    awarded: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
    declined: 'bg-red-500/15 text-red-300 border-red-500/30',
  }

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
        {offer.status === 'pending' && isCommissioner && (
          <>
            <Button onClick={() => onDecide(offer.id, 'awarded')} disabled={rfaBlocked}>
              Award
            </Button>
            <Button variant="secondary" onClick={() => onDecide(offer.id, 'declined')}>
              Decline
            </Button>
          </>
        )}
        {offer.status === 'pending' && !isCommissioner && isProposer && (
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
  const { offers, loading: offersLoading, submitOffer, decideOffer, withdrawOffer } = useFreeAgentOffers()
  const [openOffer, setOpenOffer] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

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
        description={`${season} · ${freeAgents.length} unsigned players · every club may bid, the commissioner awards the deal.`}
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
              const pendingCount = faOffers.filter((o) => o.status === 'pending').length
              return (
                <Fragment key={fa.id}>
                  <tr
                    className={`border-b border-[var(--border)]/60 last:border-0 hover:bg-[var(--bg-panel-alt)] ${
                      i % 2 === 1 ? 'bg-white/[0.015]' : ''
                    }`}
                  >
                    <td className="px-3 py-2 font-semibold text-white">{fa.name}</td>
                    <td className="px-3 py-2">{fa.position}</td>
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
                        {pendingCount > 0 ? `${pendingCount} Offer${pendingCount > 1 ? 's' : ''}` : 'Offers'}
                      </Button>
                    </td>
                  </tr>
                  {openOffer === fa.id && (
                    <tr>
                      <td colSpan={7} className="bg-[var(--bg-panel-alt)]/40 px-3 py-3">
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
