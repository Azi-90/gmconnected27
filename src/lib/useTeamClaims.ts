import { useCallback, useEffect, useState } from 'react'
import { isSupabaseConfigured, supabase } from './supabase'

export interface TeamClaim {
  teamId: string
  userId: string
  discordUsername: string | null
  avatarUrl: string | null
}

export function useTeamClaims() {
  const [claims, setClaims] = useState<Map<string, TeamClaim>>(new Map())
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setLoading(false)
      return
    }
    const { data } = await supabase
      .from('team_claims')
      .select('team_id, user_id, profiles ( discord_username, avatar_url )')
    const next = new Map<string, TeamClaim>()
    for (const row of data ?? []) {
      const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles
      next.set(row.team_id, {
        teamId: row.team_id,
        userId: row.user_id,
        discordUsername: profile?.discord_username ?? null,
        avatarUrl: profile?.avatar_url ?? null,
      })
    }
    setClaims(next)
    setLoading(false)
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  const claimTeam = useCallback(
    async (teamId: string, userId: string) => {
      const { error } = await supabase.from('team_claims').insert({ team_id: teamId, user_id: userId })
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  const releaseTeam = useCallback(
    async (teamId: string) => {
      const { error } = await supabase.from('team_claims').delete().eq('team_id', teamId)
      if (!error) await refresh()
      return error
    },
    [refresh],
  )

  return { claims, loading, claimTeam, releaseTeam }
}
