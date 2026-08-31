export type Conference = 'Eastern' | 'Western'
export type Division = 'Atlantic' | 'Metropolitan' | 'Central' | 'Pacific'

export interface Team {
  id: string
  city: string
  name: string
  abbr: string
  conference: Conference
  division: Division
  color: string
  gmName: string | null
  capUsed: number
  capSpace: number
  playerCount: number
}

export type Position = 'C' | 'LW' | 'RW' | 'D' | 'G'
export type Shoots = 'L' | 'R'

export type ContractStatus =
  | 'UFA'
  | 'RFA'
  | 'RFA (ARB)'
  | 'UFA (No QO)'

export interface Player {
  id: string
  teamId: string
  name: string
  number: number
  position: Position
  shoots: Shoots
  height: string
  weight: number
  born: string
  birthplace: string
  contractType: string
  capHit: number
  salary: number
  signingBonus: number
  totalValue: number
  clause: '—' | 'NMC' | 'NTC' | 'M-NTC'
  termYears: number
  expiryYear: string
  status: ContractStatus
  overall: number | null
  retirementAnnouncedSeason: string | null
}

export type ProspectPotential =
  | 'Elite'
  | 'Top 6'
  | 'Top 4D'
  | 'Starter'
  | 'Middle 6'
  | 'Bottom Pair'

export type ProspectReadiness = 'NHL Ready' | '1 Year Away' | '2 Years Away'

export interface Prospect {
  id: string
  rank: number
  name: string
  position: string
  height: string
  weight: number
  nationality: string
  club: string
  league: string
  ovrLow: number
  ovrHigh: number
  potential: ProspectPotential
  projLow: number
  projHigh: number
  readiness: ProspectReadiness
  draftedByTeamId: string | null
}

export interface FreeAgent {
  id: string
  name: string
  position: Position
  age: number
  lastTeam: string | null
  lastCapHit: number
  status: 'UFA' | 'RFA'
  rfaWaived: boolean
}

export type TradeAsset =
  | { type: 'player'; playerId: string; playerName: string }
  | { type: 'pick'; pickId: string; label: string }

export interface DraftPick {
  id: string
  draftYear: number
  originalTeamId: string
  currentOwnerTeamId: string
  pickNumber: number | null
  used: boolean
}

export interface TeamProspect {
  id: string
  teamId: string
  name: string
  position: string
  height: string
  weight: number
  nationality: string
  club: string
  league: string
  potential: ProspectPotential
  ovrLow: number
  ovrHigh: number
  readiness: ProspectReadiness
}

export interface Trade {
  id: string
  fromTeamId: string
  toTeamId: string
  assetsFromTeam: TradeAsset[]
  assetsToTeam: TradeAsset[]
  note: string
  status: 'pending' | 'gm_approved' | 'approved' | 'rejected'
  createdAt: string
}

export interface ProgressionLogEntry {
  id: string
  season: string
  playerId: string
  playerName: string
  oldOverall: number
  newOverall: number
  delta: number
  note: string
  createdAt: string
}

export interface FreeAgentOffer {
  id: string
  freeAgentId: string
  teamId: string
  aav: number
  termYears: number
  signingBonus: number
  status: 'pending' | 'awarded' | 'declined'
  createdAt: string
}
