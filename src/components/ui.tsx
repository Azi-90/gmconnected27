import { useState, type ReactNode } from 'react'
import type { Team, ContractStatus } from '../types'

export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-xl border border-[var(--border)] bg-[var(--bg-panel)] shadow-[var(--shadow-sm)] ${className}`}>
      {children}
    </div>
  )
}

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: ReactNode
  description?: ReactNode
  actions?: ReactNode
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[var(--border)] pb-5">
      <div className="flex items-start gap-3">
        <span className="mt-1.5 h-6 w-1 shrink-0 rounded-full bg-[var(--accent)]" />
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight text-white">{title}</h1>
          {description && (
            <p className="mt-1.5 max-w-2xl text-[14px] leading-relaxed text-[var(--text-muted)]">{description}</p>
          )}
        </div>
      </div>
      {actions && <div className="flex shrink-0 items-center gap-3">{actions}</div>}
    </div>
  )
}

export function StatTile({
  label,
  value,
  tone = 'neutral',
}: {
  label: string
  value: ReactNode
  tone?: 'neutral' | 'positive' | 'negative'
}) {
  const toneClass = tone === 'positive' ? 'text-[var(--positive)]' : tone === 'negative' ? 'text-[var(--negative)]' : 'text-white'
  return (
    <Card className="px-5 py-4">
      <div className="text-[10px] font-bold uppercase tracking-wider text-[var(--text-muted)]">
        {label}
      </div>
      <div className={`mt-1.5 text-2xl font-black tracking-tight ${toneClass}`}>{value}</div>
    </Card>
  )
}

const LOGO_EXTENSIONS = ['svg', 'png']

export function TeamBadge({ team, size = 36 }: { team: Team; size?: number }) {
  const [extIndex, setExtIndex] = useState(0)

  if (extIndex < LOGO_EXTENSIONS.length) {
    return (
      <img
        src={`/logos/${team.id}.${LOGO_EXTENSIONS[extIndex]}`}
        alt={`${team.city} ${team.name} logo`}
        width={size}
        height={size}
        style={{ width: size, height: size }}
        className="shrink-0 object-contain"
        onError={() => setExtIndex((i) => i + 1)}
      />
    )
  }

  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-full font-extrabold text-white ring-1 ring-white/10"
      style={{
        width: size,
        height: size,
        background: `linear-gradient(135deg, ${team.color}, ${team.color}99)`,
        fontSize: size * 0.34,
      }}
    >
      {team.abbr}
    </div>
  )
}

export function CapSpaceText({ value, compact }: { value: number; compact?: string }) {
  const positive = value >= 0
  return (
    <span className={positive ? 'text-[var(--positive)]' : 'text-[var(--negative)]'}>
      {compact ?? value.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 })}
    </span>
  )
}

export function StatusBadge({ status }: { status: ContractStatus }) {
  const styles: Record<ContractStatus, string> = {
    UFA: 'bg-sky-500/15 text-sky-300 border-sky-500/30',
    RFA: 'bg-amber-500/15 text-amber-300 border-amber-500/30',
    'RFA (ARB)': 'bg-amber-500/15 text-amber-300 border-amber-500/30',
    'UFA (No QO)': 'bg-slate-500/15 text-slate-300 border-slate-500/30',
  }
  return (
    <span
      className={`inline-flex rounded border px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${styles[status]}`}
    >
      {status}
    </span>
  )
}

export function Button({
  children,
  variant = 'primary',
  className = '',
  ...props
}: {
  children: ReactNode
  variant?: 'primary' | 'secondary'
  className?: string
} & React.ButtonHTMLAttributes<HTMLButtonElement>) {
  const base =
    'rounded-md px-4 py-2 text-[13px] font-bold uppercase tracking-wide transition-all duration-150 ' +
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--bg)] ' +
    'disabled:cursor-not-allowed disabled:opacity-40 active:scale-[0.98]'
  const variants = {
    primary: 'bg-[var(--accent)] text-white shadow-[var(--shadow-sm)] hover:bg-[var(--accent-hover)]',
    secondary:
      'bg-[var(--bg-panel-alt)] text-white border border-[var(--border)] hover:border-[var(--border-strong)] hover:bg-[var(--bg-elevated)]',
  }
  return (
    <button className={`${base} ${variants[variant]} ${className}`} {...props}>
      {children}
    </button>
  )
}

export function CapProgressBar({ used, cap }: { used: number; cap: number }) {
  const pct = Math.min(100, Math.max(0, (used / cap) * 100))
  const overCap = used > cap
  return (
    <div className="h-2 w-full overflow-hidden rounded-full bg-[var(--bg-panel-alt)]">
      <div
        className="h-full rounded-full transition-[width] duration-300"
        style={{
          width: `${pct}%`,
          background: overCap ? 'var(--negative)' : 'var(--positive)',
        }}
      />
    </div>
  )
}
