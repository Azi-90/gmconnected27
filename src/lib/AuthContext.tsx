import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabase } from './supabase'

const DISCORD_GUILD_ID = import.meta.env.VITE_DISCORD_GUILD_ID as string | undefined

export interface Profile {
  id: string
  discord_username: string | null
  avatar_url: string | null
  guild_nickname: string | null
  is_commissioner: boolean
}

interface AuthContextValue {
  user: User | null
  profile: Profile | null
  loading: boolean
  /** True once we've tried and failed to confirm this user is a member of the league's Discord server. */
  guildLookupFailed: boolean
  signInWithDiscord: () => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

const PROFILE_COLUMNS = 'id, discord_username, avatar_url, guild_nickname, is_commissioner'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)
  const [guildLookupFailed, setGuildLookupFailed] = useState(false)

  const refreshProfile = async (userId: string) => {
    const { data } = await supabase.from('profiles').select(PROFILE_COLUMNS).eq('id', userId).single()
    setProfile(data ?? null)
  }

  const syncGuildNickname = async (newSession: Session) => {
    if (!DISCORD_GUILD_ID || !newSession.provider_token) return
    try {
      const res = await fetch(
        `https://discord.com/api/users/@me/guilds/${DISCORD_GUILD_ID}/member`,
        { headers: { Authorization: `Bearer ${newSession.provider_token}` } },
      )
      if (!res.ok) {
        setGuildLookupFailed(true)
        return
      }
      const member = await res.json()
      const nickname: string | null = member.nick || member.user?.global_name || member.user?.username || null
      if (nickname) {
        await supabase.from('profiles').update({ guild_nickname: nickname }).eq('id', newSession.user.id)
        await refreshProfile(newSession.user.id)
      }
    } catch {
      setGuildLookupFailed(true)
    }
  }

  useEffect(() => {
    if (!isSupabaseConfigured) {
      setLoading(false)
      return
    }

    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })

    const { data: listener } = supabase.auth.onAuthStateChange((event, newSession) => {
      setSession(newSession)
      if (event === 'SIGNED_IN' && newSession) {
        syncGuildNickname(newSession)
      }
    })

    return () => listener.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!session?.user) {
      setProfile(null)
      return
    }
    refreshProfile(session.user.id)
  }, [session?.user])

  const signInWithDiscord = async () => {
    if (!isSupabaseConfigured) {
      alert('Sign-in isn\'t set up yet — Supabase credentials are missing from this deployment.')
      return
    }
    await supabase.auth.signInWithOAuth({
      provider: 'discord',
      options: {
        redirectTo: window.location.origin,
        scopes: 'identify guilds guilds.members.read',
      },
    })
  }

  const signOut = async () => {
    await supabase.auth.signOut()
  }

  return (
    <AuthContext.Provider
      value={{
        user: session?.user ?? null,
        profile,
        loading,
        guildLookupFailed,
        signInWithDiscord,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
