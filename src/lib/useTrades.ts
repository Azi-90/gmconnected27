import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import type { Trade } from '../types'

function mapTradeRow(row: any): Trade {
  return {
    id: row.id,
    fromTeamId: row.from_team_id,
    toTeamId: row.to_team_id,
    assetsFromTeam: row.assets_from_team ?? [],
    assetsToTeam: row.assets_to_team ?? [],
    note: row.note ?? '',
    status: row.status,
    createdAt: row.created_at,
  }
}

export function useTrades() {
  const [trades, setTrades] = useState<Trade[]>([])
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    const { data } = await supabase.from('trades').select('*').order('created_at', { ascending: false })
    setTrades((data ?? []).map(mapTradeRow))
    setLoading(false)
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  const proposeTrade = useCallback(
    async (trade: Omit<Trade, 'id' | 'status' | 'createdAt'>) => {
      const { error } = await supabase.from('trades').insert({
        from_team_id: trade.fromTeamId,
        to_team_id: trade.toTeamId,
        assets_from_team: trade.assetsFromTeam,
        assets_to_team: trade.assetsToTeam,
        note: trade.note,
      })
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  const decideTrade = useCallback(
    async (id: string, status: 'gm_approved' | 'approved' | 'rejected') => {
      const { error } = await supabase.from('trades').update({ status }).eq('id', id)
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  const retractTrade = useCallback(
    async (id: string) => {
      const { error } = await supabase.from('trades').delete().eq('id', id)
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  return { trades, loading, proposeTrade, decideTrade, retractTrade }
}
