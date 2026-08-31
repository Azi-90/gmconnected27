import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import type { FreeAgentOffer } from '../types'

function mapOfferRow(row: any): FreeAgentOffer {
  return {
    id: row.id,
    freeAgentId: row.free_agent_id,
    teamId: row.team_id,
    aav: row.aav,
    termYears: row.term_years,
    signingBonus: row.signing_bonus ?? 0,
    status: row.status,
    createdAt: row.created_at,
  }
}

export function useFreeAgentOffers() {
  const [offers, setOffers] = useState<FreeAgentOffer[]>([])
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    const { data } = await supabase
      .from('free_agent_offers')
      .select('*')
      .order('created_at', { ascending: false })
    setOffers((data ?? []).map(mapOfferRow))
    setLoading(false)
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  const submitOffer = useCallback(
    async (offer: { freeAgentId: string; teamId: string; aav: number; termYears: number; signingBonus?: number }) => {
      const { error } = await supabase.from('free_agent_offers').insert({
        free_agent_id: offer.freeAgentId,
        team_id: offer.teamId,
        aav: offer.aav,
        term_years: offer.termYears,
        signing_bonus: offer.signingBonus ?? 0,
      })
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  const decideOffer = useCallback(
    async (id: string, status: 'awarded' | 'declined') => {
      const { error } = await supabase.from('free_agent_offers').update({ status }).eq('id', id)
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  const withdrawOffer = useCallback(
    async (id: string) => {
      const { error } = await supabase.from('free_agent_offers').delete().eq('id', id)
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  return { offers, loading, submitOffer, decideOffer, withdrawOffer }
}
