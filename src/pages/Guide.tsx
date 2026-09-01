import { useEffect, useState } from 'react'
import { PageHeader, Card } from '../components/ui'

const SECTIONS: { id: string; label: string }[] = [
  { id: 'welcome', label: 'Welcome' },
  { id: 'sign-in', label: 'Signing In' },
  { id: 'home', label: 'Home Dashboard' },
  { id: 'teams', label: 'Teams & Rosters' },
  { id: 'trade-hub', label: 'Trade Hub' },
  { id: 'free-agency', label: 'Free Agency' },
  { id: 'draft', label: 'Draft Central' },
  { id: 'standings-news', label: 'Standings & News' },
  { id: 'resigning', label: 'Re-Signing' },
  { id: 'retirement', label: 'Retirement' },
  { id: 'commish', label: 'Commissioner Tools' },
  { id: 'faq', label: 'Troubleshooting' },
]

function Tag({ tone, children }: { tone: 'all' | 'commish'; children: string }) {
  const styles =
    tone === 'commish'
      ? 'bg-amber-500/15 text-amber-300 border-amber-500/30'
      : 'bg-sky-500/15 text-sky-300 border-sky-500/30'
  return (
    <span className={`inline-flex shrink-0 rounded border px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${styles}`}>
      {children}
    </span>
  )
}

function SectionHead({ n, title, tag }: { n: string; title: string; tag?: 'all' | 'commish' }) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <span className="text-[11px] font-bold tracking-wider text-[var(--accent)]">{n}</span>
      <h2 className="text-xl font-extrabold tracking-tight text-white">{title}</h2>
      {tag && <Tag tone={tag}>{tag === 'commish' ? 'Commissioner Only' : 'All GMs'}</Tag>}
    </div>
  )
}

function Steps({ items }: { items: { title: string; body: string }[] }) {
  return (
    <ol className="space-y-3">
      {items.map((item, i) => (
        <li key={item.title} className="flex gap-3 text-[13.5px]">
          <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--accent-soft)] text-[12px] font-bold text-[var(--accent-hover)]">
            {i + 1}
          </span>
          <span>
            <b className="text-white">{item.title}</b>
            <br />
            <span className="text-[var(--text-muted)]">{item.body}</span>
          </span>
        </li>
      ))}
    </ol>
  )
}

function Callout({ warn, children }: { warn?: boolean; children: React.ReactNode }) {
  return (
    <div
      className={`mt-3 rounded-r-lg border-l-[3px] px-4 py-3 text-[13px] ${
        warn ? 'border-[var(--warning)] bg-amber-500/10' : 'border-[var(--accent)] bg-[var(--accent-soft)]'
      }`}
    >
      {children}
    </div>
  )
}

function FormulaTable({ rows, headers }: { headers: [string, string]; rows: [string, string][] }) {
  return (
    <table className="mt-2.5 w-full text-left text-[13px]">
      <thead>
        <tr className="text-[10.5px] uppercase tracking-wide text-[var(--text-faint)]">
          <th className="border-b border-[var(--border)] py-1.5 font-medium">{headers[0]}</th>
          <th className="border-b border-[var(--border)] py-1.5 font-medium">{headers[1]}</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(([a, b]) => (
          <tr key={a}>
            <td className="border-b border-[var(--border)]/60 py-1.5">{a}</td>
            <td className="border-b border-[var(--border)]/60 py-1.5 font-mono text-[var(--accent-hover)]">{b}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

export default function Guide() {
  const [active, setActive] = useState(SECTIONS[0].id)

  useEffect(() => {
    const ids = SECTIONS.map((s) => s.id)
    // A section becomes "active" once it's scrolled up past this line near the top of
    // the viewport — simpler and more reliable here than IntersectionObserver, since the
    // sticky header means the first section never reaches the very top of the page.
    const triggerLine = 120
    let ticking = false

    const updateActive = () => {
      ticking = false
      let current = ids[0]
      for (const id of ids) {
        const el = document.getElementById(id)
        if (el && el.getBoundingClientRect().top <= triggerLine) current = id
      }
      setActive(current)
    }

    const onScroll = () => {
      if (ticking) return
      ticking = true
      requestAnimationFrame(updateActive)
    }

    updateActive()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className="space-y-6">
      <PageHeader
        title="GM Playbook"
        description="Every feature on the site, and how to use it — from claiming your club to running a trade deadline."
      />

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-[200px_minmax(0,1fr)]">
        <nav className="hidden lg:block">
          <div className="sticky top-20 space-y-0.5">
            <div className="px-2 pb-2 text-[10.5px] font-bold uppercase tracking-wider text-[var(--text-faint)]">
              On the Bench
            </div>
            {SECTIONS.map((s) => (
              <a
                key={s.id}
                href={`#${s.id}`}
                className={`block rounded-md border-l-2 px-2.5 py-1.5 text-[13px] font-medium transition-colors ${
                  active === s.id
                    ? 'border-[var(--accent)] bg-[var(--accent-soft)] text-white'
                    : 'border-transparent text-[var(--text-muted)] hover:bg-[var(--bg-panel-alt)] hover:text-white'
                }`}
              >
                {s.label}
              </a>
            ))}
          </div>
        </nav>

        {/* mobile section jump */}
        <nav className="-mx-1 flex gap-2 overflow-x-auto pb-1 lg:hidden">
          {SECTIONS.map((s) => (
            <a
              key={s.id}
              href={`#${s.id}`}
              className="shrink-0 whitespace-nowrap rounded-full border border-[var(--border)] px-3 py-1.5 text-[12px] font-semibold text-[var(--text-muted)]"
            >
              {s.label}
            </a>
          ))}
        </nav>

        <main className="min-w-0 space-y-10">
          <section id="welcome" className="scroll-mt-24 space-y-3">
            <SectionHead n="01" title="Welcome" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              GMCHL runs our NHL 27 Connected Franchise entirely from the browser — one roster, one cap sheet, and one trade
              log, shared by every GM. Nothing you do here touches the game file directly; think of it as the league's front
              office, sitting next to your controller.
            </p>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">What lives here</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                Rosters and contracts for all 32 teams, a trade desk with commissioner sign-off, free-agent bidding, the
                draft board, standings, league news, and the re-signing and retirement logic that keeps rosters moving
                between seasons — all kept in sync automatically as GMs make moves.
              </p>
            </Card>
          </section>

          <section id="sign-in" className="scroll-mt-24 space-y-3">
            <SectionHead n="02" title="Signing In & Claiming Your Team" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              You need to be in the league's Discord server before you can claim a club — that's how the site checks who's
              assigned to which team.
            </p>
            <Card className="p-5">
              <h3 className="mb-3 text-[13px] font-bold text-white">First time setup</h3>
              <Steps
                items={[
                  {
                    title: 'Click "Sign in with Discord"',
                    body: "Top right of any page. Use the Discord account that's in the GMCHL server.",
                  },
                  {
                    title: 'Open the Teams page',
                    body: "If your server nickname matches the GM name already on file for your club, you'll see a Claim Team button on that club's card.",
                  },
                  {
                    title: 'Claim it',
                    body: "Once claimed, that club is yours — you can re-sign players, propose trades, place bids, and toggle the trade block for your own roster.",
                  },
                ]}
              />
              <Callout>
                Nicknames like <span className="font-mono">"WildGM | killerc00kie"</span> work fine — the site checks the
                whole nickname and each piece around the <span className="font-mono">|</span> separator.
              </Callout>
              <Callout warn>
                <b>Can't find your club?</b> The name on file for your team doesn't match your Discord nickname exactly.
                Ping the commissioner — see Troubleshooting below.
              </Callout>
            </Card>
          </section>

          <section id="home" className="scroll-mt-24 space-y-3">
            <SectionHead n="03" title="Home Dashboard" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Your landing page after signing in — built to answer "what needs my attention today?" before anything else.
            </p>
            <div className="grid gap-3 sm:grid-cols-3">
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">Your Notifications</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  Trades waiting on your approval vs. the other side, RFA offers needing a response, contracts expiring
                  soon, players retiring, and a trade deadline reminder.
                </p>
              </Card>
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">League News</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  An automatic write-up whenever a trade executes, a free agent signs, the season advances, or the draft
                  wraps.
                </p>
              </Card>
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">League Snapshot</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  Clubs claimed, salary cap ceiling, current season, and a "most cap space" leaderboard across all 32
                  teams.
                </p>
              </Card>
            </div>
          </section>

          <section id="teams" className="scroll-mt-24 space-y-3">
            <SectionHead n="04" title="Teams & Rosters" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Every club's roster, contracts, and prospect pipeline — with your own club unlocked for edits.
            </p>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">Browsing all 32 clubs</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                The Teams page opens as <span className="font-mono">Cards</span> — one tile per club, grouped by
                conference and division. Flip the toggle to <span className="font-mono">Cap Sheet</span> for a
                league-wide table sorted by cap situation instead.
              </p>
            </Card>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">Inside a club</h3>
              <div className="mb-2 flex gap-2">
                {['Roster', 'Cap Sheet', 'Prospects'].map((t) => (
                  <span key={t} className="rounded-full border border-[var(--border)] px-2.5 py-1 text-[11px] font-semibold text-[var(--text-muted)]">
                    {t}
                  </span>
                ))}
              </div>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                <b className="text-white">Roster</b> lists every player with overall rating, age, and contract terms.{' '}
                <b className="text-white">Cap Sheet</b> lays contracts out year-by-year — each contract's final season is
                highlighted, with team totals and projected cap space below. <b className="text-white">Prospects</b> shows
                your top organizational prospects, their potential tier, and how close they are to NHL-ready.
              </p>
            </Card>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">Managing your own club</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                On your team only, each player row gets a <span className="font-mono">Re-sign</span> button and an{' '}
                <span className="font-mono">Add to Block</span> toggle for the trade block. There's also an{' '}
                <span className="font-mono">Export Roster CSV</span> button if you want your roster in a spreadsheet.
              </p>
            </Card>
          </section>

          <section id="trade-hub" className="scroll-mt-24 space-y-3">
            <SectionHead n="05" title="Trade Hub" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Every trade goes through two approvals before it's final — nothing executes just because you clicked
              "Propose."
            </p>
            <Card className="p-5">
              <h3 className="mb-3 text-[13px] font-bold text-white">Proposing a trade</h3>
              <Steps
                items={[
                  {
                    title: 'Pick the other team',
                    body: 'Add players or draft picks from either side — the picker shows age, overall, cap hit, and term for every player, plus a badge if they’re on the trade block.',
                  },
                  { title: 'Send it', body: "The trade lands on the receiving GM's Trade Hub, marked pending." },
                  { title: 'Receiving GM approves', body: 'Moves it to gm_approved — both sides have now agreed.' },
                  {
                    title: 'Commissioner signs off',
                    body: 'Only then does the trade execute — players and picks move, rosters and cap sheets update everywhere.',
                  },
                ]}
              />
            </Card>
            <div className="grid gap-3 sm:grid-cols-2">
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">Trade Block</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  Flag your own players as available from their team page, and every GM can see the full league-wide
                  block, grouped by team, right on the Trade Hub.
                </p>
              </Card>
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">Draft Picks</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  Picks are tradeable assets too. Ownership can change hands independently of who originally earned the
                  pick through standings.
                </p>
              </Card>
            </div>
            <Callout>A banner at the top of the Trade Hub tracks the trade deadline once the commissioner sets one for the season.</Callout>
          </section>

          <section id="free-agency" className="scroll-mt-24 space-y-3">
            <SectionHead n="06" title="Free Agency" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Bid on unsigned players with a real offer — term, AAV, and signing bonus — not just a claim button.
            </p>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">Placing a bid</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                Open Free Agency, pick a player, and submit AAV, term, and signing bonus. The player's last team and cap
                hit are shown so you know what you're bidding against.
              </p>
            </Card>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">Restricted free agents</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                RFAs are flagged with a banner. Outside offers can be submitted and seen by everyone, but they can't be{' '}
                <b className="text-white">awarded</b> until the player's original team explicitly waives its right of
                first refusal.
              </p>
            </Card>
          </section>

          <section id="draft" className="scroll-mt-24 space-y-3">
            <SectionHead n="07" title="Draft Central" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              The board, the class, and the picks — ordered by whoever actually owns each slot today.
            </p>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">The board</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                Draft order follows current pick ownership, not just standings — a pick you traded for shows up under
                your name.
              </p>
            </Card>
            <Card className="p-5">
              <h3 className="mb-2 text-[13px] font-bold text-white">Scouting a prospect</h3>
              <p className="text-[13.5px] text-[var(--text-muted)]">
                Each prospect lists a potential tier (Elite down to Bottom Pair), an overall range, and a readiness read
                — NHL Ready, one year away, or two.
              </p>
            </Card>
          </section>

          <section id="standings-news" className="scroll-mt-24 space-y-3">
            <SectionHead n="08" title="Standings & News" tag="all" />
            <div className="grid gap-3 sm:grid-cols-2">
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">Standings</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  Division and conference standings, with the top three in each division marked.
                </p>
              </Card>
              <Card className="p-5">
                <h3 className="mb-2 text-[13px] font-bold text-white">News</h3>
                <p className="text-[13px] text-[var(--text-muted)]">
                  A full archive of every auto-generated article, color-coded by event type.
                </p>
              </Card>
            </div>
          </section>

          <section id="resigning" className="scroll-mt-24 space-y-3">
            <SectionHead n="09" title="Re-Signing Your Players" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Submit a real offer to your own player, and the site judges it against what that player's actually worth
              right now.
            </p>
            <Card className="p-5">
              <h3 className="mb-1 text-[13px] font-bold text-white">How the offer is judged</h3>
              <p className="text-[13px] text-[var(--text-muted)]">Your offer is compared to an expected value: the player's current cap hit, scaled by age.</p>
              <FormulaTable
                headers={['Age', 'Multiplier']}
                rows={[
                  ['Under 27', '× 1.10'],
                  ['27 – 31', '× 1.00'],
                  ['32 – 35', '× 0.92'],
                  ['36 and up', '× 0.80'],
                ]}
              />
              <p className="mt-3 text-[13.5px] text-[var(--text-muted)]">
                Offer <b className="text-white">95%</b> of expected value or more and it's accepted outright. Land
                between <b className="text-white">80–95%</b> and the player counters with what they'd actually take.
                Come in under <b className="text-white">80%</b> and the offer is rejected.
              </p>
            </Card>
          </section>

          <section id="retirement" className="scroll-mt-24 space-y-3">
            <SectionHead n="10" title="Retirement" tag="all" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Older players carry real retirement odds each offseason — and you'll always get a season's warning first.
            </p>
            <Card className="p-5">
              <FormulaTable
                headers={['Age', 'Retirement Odds']}
                rows={[
                  ['32 – 34', '3%'],
                  ['35 – 37', '10%'],
                  ['38 – 39', '25%'],
                  ['40+', '45%'],
                ]}
              />
              <Callout>
                When a retirement rolls, it's <i>announced</i> that season — the player stays on your roster and cap
                sheet. The actual retirement happens at the start of the following season, so you always have time to
                plan around it.
              </Callout>
            </Card>
          </section>

          <section id="commish" className="scroll-mt-24 space-y-3">
            <SectionHead n="11" title="Commissioner Tools" tag="commish" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              Season-level controls, visible only to commissioners, for running the league from one page.
            </p>
            <div className="grid gap-3 sm:grid-cols-2">
              {[
                ['Advance Season', 'Rolls the league into the next season — expiring contracts move to free agency, prospects develop, announced retirements happen, and a new draft class is generated.'],
                ['Player Progression', 'Runs stat-based progression across the league so ratings track how players actually performed.'],
                ['Trade Deadline', "Sets the date shown in the Trade Hub's deadline banner for the current season."],
                ['Seed Team Prospects', 'Tops up any team sitting below five organizational prospects — safe to run more than once.'],
                ['Team GM Assignments', "Assigns a club's GM name directly from a signed-in user's exact Discord identity — pick from a dropdown instead of retyping a nickname."],
                ['Undo Last Action', 'A single-level undo for the last season-altering move — trades, signings, drafts, and progression runs all leave a snapshot behind.'],
              ].map(([title, body]) => (
                <Card key={title} className="p-5">
                  <h3 className="mb-2 text-[13px] font-bold text-white">{title}</h3>
                  <p className="text-[13px] text-[var(--text-muted)]">{body}</p>
                </Card>
              ))}
            </div>
          </section>

          <section id="faq" className="scroll-mt-24 space-y-3">
            <SectionHead n="12" title="Troubleshooting" />
            <p className="max-w-2xl text-[14px] text-[var(--text-muted)]">
              The handful of issues that come up most often, and the fastest way through them.
            </p>
            <Card className="divide-y divide-[var(--border)]/60 p-5">
              {[
                {
                  q: '"We couldn\'t find a club assigned to me"',
                  a: 'Your Discord nickname doesn\'t match the GM name on file for your team. Ask a commissioner to open Commissioner Tools → Team GM Assignments and assign you from the dropdown — it pulls your exact stored identity, so there\'s no typing involved.',
                },
                {
                  q: '"You need a verified e-mail or phone number" on Discord',
                  a: 'That\'s a Discord account requirement, not a GMCHL issue. In Discord, go to User Settings → My Account and verify an email or phone number, then sign in again.',
                },
                {
                  q: 'A contract or rating looks wrong',
                  a: 'Flag it to a commissioner with the player’s name and what it should be — league data gets corrected in a batch rather than one at a time.',
                },
                {
                  q: "I can't approve or execute a trade",
                  a: "Check the trade's stage on the Trade Hub. A pending trade needs the receiving GM first; a gm_approved trade is waiting on the commissioner.",
                },
              ].map((item) => (
                <div key={item.q} className="py-3 first:pt-0 last:pb-0">
                  <p className="text-[13.5px] font-bold text-white">{item.q}</p>
                  <p className="mt-1 text-[13px] text-[var(--text-muted)]">{item.a}</p>
                </div>
              ))}
            </Card>
          </section>
        </main>
      </div>
    </div>
  )
}
