export function formatMoney(value: number, opts: { compact?: boolean } = {}): string {
  const sign = value < 0 ? '-' : ''
  const abs = Math.abs(value)
  if (opts.compact) {
    if (abs >= 1_000_000) return `${sign}$${(abs / 1_000_000).toFixed(3).replace(/0+$/, '').replace(/\.$/, '')}M`
    if (abs >= 1_000) return `${sign}$${(abs / 1_000).toFixed(0)}K`
    return `${sign}$${abs}`
  }
  return `${sign}$${abs.toLocaleString('en-US')}`
}

export function formatCompactMoney(value: number): string {
  const sign = value < 0 ? '-' : ''
  const abs = Math.abs(value)
  const millions = abs / 1_000_000
  const trimmed = millions.toFixed(3).replace(/0+$/, '').replace(/\.$/, '')
  return `${sign}$${trimmed}M`
}
