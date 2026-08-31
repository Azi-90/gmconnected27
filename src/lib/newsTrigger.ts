import { supabase } from './supabase'

export type NewsEventType =
  | 'trade'
  | 'free_agency'
  | 'season_advance'
  | 'draft_lottery'
  | 'draft_complete'
  | 'retirement_announced'
  | 'retirement'

function pick<T>(options: T[]): T {
  return options[Math.floor(Math.random() * options.length)]
}

function joinWithAnd(items: string[]): string {
  if (items.length === 0) return 'nothing'
  if (items.length === 1) return items[0]
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`
}

function money(value: number): string {
  return `$${Number(value).toLocaleString()}`
}

function buildArticle(eventType: NewsEventType, payload: any): { headline: string; body: string } | null {
  switch (eventType) {
    case 'trade': {
      const { fromTeam, toTeam, assetsFromTeam, assetsToTeam, note } = payload
      const from = joinWithAnd(assetsFromTeam)
      const to = joinWithAnd(assetsToTeam)
      const headline = pick([
        `${fromTeam} and ${toTeam} Swing a Deal`,
        `Trade Alert: ${fromTeam} ↔ ${toTeam}`,
        `${fromTeam} Shake Things Up With ${toTeam}`,
      ])
      const body = pick([
        `The ${fromTeam} send ${from} to the ${toTeam} in exchange for ${to}. GMs across the league are already arguing about who won this one.`,
        `In a deal that's sure to blow up the group chat, ${fromTeam} ship out ${from} while ${toTeam} part with ${to}.`,
        `${fromTeam} and ${toTeam} have agreed to a trade: ${from} heads one way, ${to} heads the other.`,
      ])
      return { headline, body: note ? `${body} ${note}` : body }
    }
    case 'free_agency': {
      const { team, playerName, aav, termYears } = payload
      const headline = pick([
        `${team} Ink ${playerName}`,
        `${playerName} Finds a New Home in ${team}`,
        `Signing Alert: ${team} Land ${playerName}`,
      ])
      const body = pick([
        `${team} have signed ${playerName} to a ${termYears}-year deal worth ${money(aav)} per season. Cap sheets around the league just got a little tighter.`,
        `${playerName} is officially off the market — ${team} won the bidding with a ${termYears}-year, ${money(aav)} AAV offer.`,
        `The rebuild continues: ${team} bring in ${playerName} on a fresh ${termYears}-year contract worth ${money(aav)} a year.`,
      ])
      return { headline, body }
    }
    case 'season_advance': {
      const { oldSeason, newSeason } = payload
      const headline = pick([`Curtains Close on ${oldSeason}`, `Welcome to the ${newSeason} Season`])
      const body = `The GMCHL has officially turned the page from ${oldSeason} to ${newSeason}. Expiring contracts hit free agency, every remaining deal aged a year, and a fresh draft class just opened up.`
      return { headline, body }
    }
    case 'draft_lottery': {
      const { season, topTeams } = payload
      const headline = pick([`${season} Draft Lottery Results Are In`, `Ping-Pong Balls Decide the ${season} Draft Order`])
      const body = `The lottery has spoken: ${joinWithAnd(topTeams)} will pick at the top of the ${season} draft. Fans of the bottom of the standings finally have something to cheer for.`
      return { headline, body }
    }
    case 'draft_complete': {
      const { draftYear, picks } = payload
      if (!picks?.length) return null
      const headline = pick([`${draftYear} Draft Wraps Up`, `The ${draftYear} Draft Is Done — Here's Who Went Where`])
      const body = `The ${draftYear} GMCHL entry draft is in the books. ${picks.length} prospects found new homes, headlined by ${picks[0].team} taking ${picks[0].name} (${picks[0].position}) first overall.`
      return { headline, body }
    }
    case 'retirement_announced': {
      const { season, players } = payload as { season: string; players: { name: string; team: string }[] }
      if (!players?.length) return null
      const names = joinWithAnd(players.map((p) => `${p.name} (${p.team})`))
      const headline = pick([`Retirement Watch: ${season}`, `Who's Hanging Up the Skates This Season`])
      const body = `Word around the league: ${names} plan${players.length === 1 ? 's' : ''} to retire at the end of the ${season} season. GMs have the rest of the year to plan around it.`
      return { headline, body }
    }
    case 'retirement': {
      const { season, players } = payload as { season: string; players: { name: string; team: string }[] }
      if (!players?.length) return null
      const names = joinWithAnd(players.map((p) => `${p.name} (${p.team})`))
      const headline = pick([`Thanks for the Memories`, `${season} Retirement Class`])
      const body = `${names} ${players.length === 1 ? 'has' : 'have'} officially retired after the ${season} season. Their cap hits are gone for good — moment of silence, then back to business.`
      return { headline, body }
    }
    default:
      return null
  }
}

export async function triggerNewsGeneration(eventType: NewsEventType, payload: Record<string, unknown>, teamIds: string[] = []) {
  const article = buildArticle(eventType, payload)
  if (!article) return
  await supabase.from('news_articles').insert({
    headline: article.headline,
    body: article.body,
    event_type: eventType,
    team_ids: teamIds,
  })
}
