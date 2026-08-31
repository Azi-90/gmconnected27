import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const STYLE =
  'You are a fun, slightly irreverent beat writer for a fictional NHL dynasty league called GMCHL. ' +
  'Write ONE short news blurb (2-4 sentences) about the event below, plus a punchy headline. ' +
  'Respond with ONLY valid JSON in this exact shape, no markdown fences: {"headline": "...", "body": "..."}'

function buildPrompt(eventType: string, payload: any): string | null {
  switch (eventType) {
    case 'trade': {
      const { fromTeam, toTeam, assetsFromTeam, assetsToTeam, note } = payload
      return `${STYLE}\n\nEvent: ${fromTeam} traded ${assetsFromTeam.join(', ') || 'nothing'} to ${toTeam} in exchange for ${assetsToTeam.join(', ') || 'nothing'}.${note ? ` Note from the GMs: ${note}` : ''}`
    }
    case 'free_agency': {
      const { team, playerName, aav, termYears } = payload
      return `${STYLE}\n\nEvent: The ${team} signed free agent ${playerName} to a ${termYears}-year contract worth $${Number(aav).toLocaleString()} per year.`
    }
    case 'season_advance': {
      const { oldSeason, newSeason } = payload
      return `${STYLE}\n\nEvent: The GMCHL league has officially closed out the ${oldSeason} season and is moving into the ${newSeason} season. Expiring contracts hit free agency, remaining deals aged a year, and a new draft class just opened up.`
    }
    case 'draft_lottery': {
      const { season, topTeams } = payload
      return `${STYLE}\n\nEvent: The GMCHL draft lottery for the ${season} draft class was just drawn. Top of the order: ${topTeams.join(', ')}.`
    }
    case 'draft_complete': {
      const { draftYear, picks } = payload
      const list = picks.map((p: any, i: number) => `${i + 1}. ${p.team} — ${p.name} (${p.position})`).join('; ')
      return `${STYLE}\n\nEvent: The ${draftYear} GMCHL entry draft just wrapped. Full order: ${list}. Call out a couple of the most interesting picks or biggest reaches/steals.`
    }
    default:
      return null
  }
}

function parseArticle(raw: string): { headline: string; body: string } {
  try {
    const cleaned = raw.trim().replace(/^```(json)?/, '').replace(/```$/, '').trim()
    const parsed = JSON.parse(cleaned)
    if (parsed.headline && parsed.body) return parsed
  } catch {
    // fall through to the default below
  }
  return { headline: 'GMCHL League Update', body: raw || 'Something happened in the league.' }
}

Deno.serve(async (req) => {
  try {
    const { eventType, payload, teamIds } = await req.json()
    const prompt = buildPrompt(eventType, payload)
    if (!prompt) {
      return new Response(JSON.stringify({ error: `Unknown event type: ${eventType}` }), { status: 400 })
    }

    const aiRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 400,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!aiRes.ok) {
      const text = await aiRes.text()
      return new Response(JSON.stringify({ error: `Anthropic API error: ${text}` }), { status: 502 })
    }

    const aiData = await aiRes.json()
    const raw = aiData.content?.[0]?.text ?? ''
    const { headline, body } = parseArticle(raw)

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { error } = await supabase.from('news_articles').insert({
      headline,
      body,
      event_type: eventType,
      team_ids: teamIds ?? [],
    })

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
