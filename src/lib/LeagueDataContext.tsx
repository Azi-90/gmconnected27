import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { supabase } from './supabase'
import type { Team, Player, FreeAgent, Prospect } from '../types'

interface LeagueState {
  season: string
  salaryCap: number
  phase: 'season' | 'offseason' | 'draft'
  draftClassYear: number
  tradeDeadline: string | null
}

interface LeagueDataValue {
  loading: boolean
  season: string
  salaryCap: number
  phase: LeagueState['phase']
  draftClassYear: number
  tradeDeadline: string | null
  teams: Team[]
  teamsById: Map<string, Team>
  players: Player[]
  playersByTeam: (teamId: string) => Player[]
  freeAgents: FreeAgent[]
  prospects: Prospect[]
  refresh: () => Promise<void>
}

const LeagueDataContext = createContext<LeagueDataValue | null>(null)

function mapTeamRow(row: any, capUsed: number, playerCount: number, salaryCap: number): Team {
  return {
    id: row.id,
    city: row.city,
    name: row.name,
    abbr: row.abbr,
    conference: row.conference,
    division: row.division,
    color: row.color,
    gmName: row.gm_name,
    capUsed,
    capSpace: salaryCap - capUsed,
    playerCount,
  }
}

function mapPlayerRow(row: any): Player {
  return {
    id: row.id,
    teamId: row.team_id,
    name: row.name,
    number: row.number,
    position: row.position,
    shoots: row.shoots,
    height: row.height,
    weight: row.weight,
    born: row.born,
    birthplace: row.birthplace,
    contractType: row.contract_type,
    capHit: row.cap_hit,
    salary: row.salary,
    signingBonus: row.signing_bonus,
    totalValue: row.total_value,
    clause: row.clause,
    termYears: row.term_years,
    expiryYear: row.expiry_year,
    status: row.status,
    overall: row.overall,
    retirementAnnouncedSeason: row.retirement_announced_season,
    onTradeBlock: row.on_trade_block ?? false,
  }
}

function mapFreeAgentRow(row: any): FreeAgent {
  return {
    id: row.id,
    name: row.name,
    position: row.position,
    age: row.age,
    lastTeam: row.last_team_id,
    lastCapHit: row.last_cap_hit,
    status: row.status,
    rfaWaived: row.rfa_waived ?? false,
  }
}

function mapProspectRow(row: any): Prospect {
  return {
    id: row.id,
    rank: row.rank,
    name: row.name,
    position: row.position,
    height: row.height,
    weight: row.weight,
    nationality: row.nationality,
    club: row.club,
    league: row.league,
    ovrLow: row.ovr_low,
    ovrHigh: row.ovr_high,
    potential: row.potential,
    projLow: row.proj_low,
    projHigh: row.proj_high,
    readiness: row.readiness,
    draftedByTeamId: row.drafted_by_team_id,
  }
}

export function LeagueDataProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true)
  const [leagueState, setLeagueState] = useState<LeagueState>({
    season: '2026-27',
    salaryCap: 104_000_000,
    phase: 'season',
    draftClassYear: 2027,
    tradeDeadline: null,
  })
  const [teams, setTeams] = useState<Team[]>([])
  const [teamsById, setTeamsById] = useState<Map<string, Team>>(new Map())
  const [players, setPlayers] = useState<Player[]>([])
  const [freeAgents, setFreeAgents] = useState<FreeAgent[]>([])
  const [prospects, setProspects] = useState<Prospect[]>([])

  const refresh = useCallback(async () => {
    const [stateRes, teamsRes, playersRes, faRes] = await Promise.all([
      supabase.from('league_state').select('*').single(),
      supabase.from('league_teams').select('*'),
      supabase.from('players').select('*'),
      supabase.from('free_agents').select('*').is('signed_by_team_id', null),
    ])

    const state: LeagueState = stateRes.data
      ? {
          season: stateRes.data.season,
          salaryCap: stateRes.data.salary_cap,
          phase: stateRes.data.phase,
          draftClassYear: stateRes.data.draft_class_year,
          tradeDeadline: stateRes.data.trade_deadline,
        }
      : leagueState
    setLeagueState(state)

    const prospectsRes = await supabase
      .from('draft_prospects')
      .select('*')
      .eq('draft_year', state.draftClassYear)
      .order('rank')

    const playerRows = (playersRes.data ?? []).map(mapPlayerRow)
    const teamRows = teamsRes.data ?? []

    const mappedTeams = teamRows.map((row: any) => {
      const teamPlayers = playerRows.filter((p) => p.teamId === row.id)
      const capUsed = teamPlayers.reduce((sum, p) => sum + p.capHit, 0)
      return mapTeamRow(row, capUsed, teamPlayers.length, state.salaryCap)
    })

    setTeams(mappedTeams)
    setTeamsById(new Map(mappedTeams.map((t) => [t.id, t])))
    setPlayers(playerRows)
    setFreeAgents((faRes.data ?? []).map(mapFreeAgentRow))
    setProspects((prospectsRes.data ?? []).map(mapProspectRow))
    setLoading(false)
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  const playersByTeam = useCallback((teamId: string) => players.filter((p) => p.teamId === teamId), [players])

  return (
    <LeagueDataContext.Provider
      value={{
        loading,
        season: leagueState.season,
        salaryCap: leagueState.salaryCap,
        phase: leagueState.phase,
        draftClassYear: leagueState.draftClassYear,
        tradeDeadline: leagueState.tradeDeadline,
        teams,
        teamsById,
        players,
        playersByTeam,
        freeAgents,
        prospects,
        refresh,
      }}
    >
      {children}
    </LeagueDataContext.Provider>
  )
}

export function useLeagueData() {
  const ctx = useContext(LeagueDataContext)
  if (!ctx) throw new Error('useLeagueData must be used within LeagueDataProvider')
  return ctx
}
