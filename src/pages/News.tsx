import { useNews } from '../lib/useNews'
import { Card, PageHeader } from '../components/ui'

const EVENT_LABELS: Record<string, string> = {
  trade: 'Trade',
  free_agency: 'Free Agency',
  season_advance: 'Season',
  draft_lottery: 'Draft Lottery',
  draft_complete: 'Draft',
  retirement_announced: 'Retirement Watch',
  retirement: 'Retirement',
}

const EVENT_STYLES: Record<string, string> = {
  trade: 'border-sky-500/30 bg-sky-500/15 text-sky-300',
  free_agency: 'border-emerald-500/30 bg-emerald-500/15 text-emerald-300',
  season_advance: 'border-[var(--accent)]/40 bg-[var(--accent-soft)] text-[var(--accent-hover)]',
  draft_lottery: 'border-amber-500/30 bg-amber-500/15 text-amber-300',
  draft_complete: 'border-amber-500/30 bg-amber-500/15 text-amber-300',
  retirement_announced: 'border-amber-500/30 bg-amber-500/15 text-amber-300',
  retirement: 'border-slate-500/30 bg-slate-500/15 text-slate-300',
}

function timeAgo(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diffMs / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}

export default function News() {
  const { articles, loading } = useNews()

  return (
    <div className="space-y-4">
      <PageHeader
        title="League News"
        description="Everything happening around the GMCHL, newest first — auto-written whenever a trade, signing, draft, or season change goes through."
      />

      {loading ? (
        <p className="text-[var(--text-muted)]">Loading league data…</p>
      ) : articles.length === 0 ? (
        <Card className="px-5 py-8 text-center text-[14px] text-[var(--text-muted)]">
          Nothing posted yet. Articles show up automatically once trades, signings, or the draft
          start happening.
        </Card>
      ) : (
        <div className="space-y-3">
          {articles.map((article) => (
            <Card key={article.id} className="overflow-hidden transition-shadow hover:shadow-[var(--shadow-md)]">
              <div className="flex gap-4 p-5">
                <div className="flex-1">
                  <div className="flex items-center justify-between gap-3">
                    <span
                      className={`inline-flex rounded border px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${
                        EVENT_STYLES[article.eventType] ?? 'border-[var(--border)] bg-[var(--bg-panel-alt)] text-[var(--text-muted)]'
                      }`}
                    >
                      {EVENT_LABELS[article.eventType] ?? article.eventType}
                    </span>
                    <span className="text-[11px] text-[var(--text-muted)]">{timeAgo(article.createdAt)}</span>
                  </div>
                  <h2 className="mt-2 text-lg font-extrabold text-white">{article.headline}</h2>
                  <p className="mt-1 text-[14px] leading-relaxed text-[var(--text-muted)]">{article.body}</p>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
