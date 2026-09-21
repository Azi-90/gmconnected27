import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import { useAuth } from './AuthContext'

export interface TransactionLogEntry {
  id: string
  createdAt: string
  action: string
  summary: string
  teamIds: string[]
  acknowledged: boolean
}

function mapRow(row: any): TransactionLogEntry {
  return {
    id: row.id,
    createdAt: row.created_at,
    action: row.action,
    summary: row.summary,
    teamIds: row.team_ids ?? [],
    acknowledged: row.acknowledged,
  }
}

const POLL_MS = 30_000

export function useTransactionsLog() {
  const { profile } = useAuth()
  const isCommissioner = Boolean(profile?.is_commissioner)
  const [entries, setEntries] = useState<TransactionLogEntry[]>([])

  const refresh = useCallback(async () => {
    if (!isCommissioner) {
      setEntries([])
      return
    }
    const { data } = await supabase
      .from('transactions_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100)
    setEntries((data ?? []).map(mapRow))
  }, [isCommissioner])

  useEffect(() => {
    refresh()
    if (!isCommissioner) return
    const id = setInterval(refresh, POLL_MS)
    return () => clearInterval(id)
  }, [refresh, isCommissioner])

  const acknowledgeAll = useCallback(async () => {
    await supabase.rpc('acknowledge_all_transactions')
    await refresh()
  }, [refresh])

  const unreadCount = entries.filter((e) => !e.acknowledged).length

  return { entries, unreadCount, refresh, acknowledgeAll }
}
