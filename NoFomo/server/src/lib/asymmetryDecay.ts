// ── Asymmetry Decay / Window-Close Detection ──
// A setup that was asymmetric (NVDA 2019: smaller, cheap vs. growth, runway) becomes
// consensus and fully-valued (NVDA today: $3T+, 60+ analysts, priced for perfection).
// When asymmetry is gone, the window has CLOSED and the name should leave the radar.
// Pure (no I/O): runs at scan-time and during the sweep. Every reason is explicit.

export type WindowStatus = 'open' | 'closing' | 'closed'

export interface AsymmetryInput {
  marketCap?: string | number | null
  analystCount?: number | null
  price?: number | null
  analystTargetMean?: number | null
  structuredUpsidePct?: number | null
  peerPercentileRank?: number | null
  rsi?: number | null
  priceHistory?: number[] | null
  compositeScore?: number | null
  contrarianScore?: number | null
  hasUpcomingCatalyst?: boolean | null
  researchedAt?: string | null
  nowMs?: number
}

export interface AsymmetryVerdict {
  status: WindowStatus
  openScore: number
  decayPoints: number
  reasons: string[]
  expiresAt: string
}

const MEGA_CAP_USD = 1_000_000_000_000
const LARGE_CAP_USD = 500_000_000_000
const BIG_CAP_USD = 250_000_000_000
const CLOSED_AT = 60
const CLOSING_AT = 30
const TTL_OPEN_DAYS = 21
const TTL_CLOSING_DAYS = 10
const STALE_DAYS = 21
const DAY_MS = 24 * 60 * 60 * 1000

export function parseMarketCap(cap: string | number | null | undefined): number | null {
  if (cap == null) return null
  if (typeof cap === 'number') return cap > 0 ? cap : null
  const m = cap.replace(/[$,\s]/g, '').match(/^([\d.]+)\s*([TBMK]?)/i)
  if (!m) return null
  const n = parseFloat(m[1])
  if (!Number.isFinite(n)) return null
  const mult: Record<string, number> = { T: 1e12, B: 1e9, M: 1e6, K: 1e3, '': 1 }
  return n * (mult[m[2].toUpperCase()] ?? 1)
}

function pricePosition(price?: number | null, history?: number[] | null): number | null {
  if (price == null || !history || history.length < 20) return null
  const low = Math.min(...history), high = Math.max(...history)
  if (high <= low) return null
  return Math.max(0, Math.min(1, (price - low) / (high - low)))
}

export function evaluateAsymmetry(input: AsymmetryInput): AsymmetryVerdict {
  const now = input.nowMs ?? Date.now()
  const reasons: string[] = []
  let decay = 0

  const cap = parseMarketCap(input.marketCap)
  if (cap != null) {
    if (cap >= MEGA_CAP_USD) { decay += 40; reasons.push(`Mega-cap ($${(cap / 1e12).toFixed(1)}T) — a 3x+ return is implausible at this size`) }
    else if (cap >= LARGE_CAP_USD) { decay += 25; reasons.push(`Large-cap ($${(cap / 1e9).toFixed(0)}B) — limited room for asymmetric upside`) }
    else if (cap >= BIG_CAP_USD) { decay += 12; reasons.push(`$${(cap / 1e9).toFixed(0)}B cap — approaching the size where 3x gets hard`) }
  }

  const ac = input.analystCount
  if (ac != null) {
    if (ac >= 30) { decay += 30; reasons.push(`Consensus name — ${ac} analysts cover it (no longer underfollowed)`) }
    else if (ac >= 20) { decay += 20; reasons.push(`Well-covered — ${ac} analysts (edge narrowing)`) }
    else if (ac >= 12) { decay += 10; reasons.push(`${ac} analysts — coverage building`) }
  }

  let upside: number | null = null
  // Only trust the analyst target when it's actually populated (>0). A missing/zero
  // target must NOT be read as "trading above target" (that bug pruned every stock
  // whenever the analyst feed was unavailable). Fall back to the thesis upside instead.
  if (input.analystTargetMean != null && input.analystTargetMean > 0 && input.price != null && input.price > 0) {
    upside = ((input.analystTargetMean - input.price) / input.price) * 100
  } else if (input.structuredUpsidePct != null) {
    upside = input.structuredUpsidePct
  }
  if (upside != null && (ac ?? 0) >= 3) {
    if (upside < 0) { decay += 30; reasons.push(`Trading above analyst mean target (${Math.round(upside)}% downside to target)`) }
    else if (upside < 10) { decay += 20; reasons.push(`Only ${Math.round(upside)}% upside to mean target — repriced`) }
    else if (upside < 20) { decay += 10; reasons.push(`${Math.round(upside)}% upside to target — most of the move is in`) }
  }

  if (input.peerPercentileRank != null) {
    if (input.peerPercentileRank > 80) { decay += 20; reasons.push(`Expensive vs. peers (${input.peerPercentileRank}th percentile)`) }
    else if (input.peerPercentileRank > 70) { decay += 12; reasons.push(`Premium valuation vs. peers (${input.peerPercentileRank}th percentile)`) }
  }

  const pos = pricePosition(input.price, input.priceHistory)
  if (input.rsi != null && input.rsi > 75 && (pos == null || pos > 0.85)) { decay += 20; reasons.push(`Overbought (RSI ${Math.round(input.rsi)}) near 52-week high — easy money made`) }
  else if (input.rsi != null && input.rsi > 70) { decay += 8; reasons.push(`Overbought (RSI ${Math.round(input.rsi)})`) }

  if (input.hasUpcomingCatalyst === false) { decay += 12; reasons.push('No identifiable upcoming catalyst — the repricing event may have passed') }

  if (input.compositeScore != null && input.compositeScore < 50) { decay += 18; reasons.push(`Composite signal score decayed to ${input.compositeScore}`) }
  if (input.contrarianScore != null && input.contrarianScore < 30) { decay += 12; reasons.push(`Contrarian score collapsed to ${input.contrarianScore} — thesis now consensus`) }

  let ageDays: number | null = null
  if (input.researchedAt) {
    const t = new Date(input.researchedAt).getTime()
    if (Number.isFinite(t)) ageDays = (now - t) / DAY_MS
  }
  if (ageDays != null && ageDays > STALE_DAYS) { decay += 25; reasons.push(`Stale — last researched ${Math.round(ageDays)} days ago`) }
  else if (ageDays != null && ageDays > 14) { decay += 12; reasons.push(`Aging — last researched ${Math.round(ageDays)} days ago`) }

  const status: WindowStatus = decay >= CLOSED_AT ? 'closed' : decay >= CLOSING_AT ? 'closing' : 'open'
  const openScore = Math.max(0, Math.min(100, 100 - decay))
  const base = input.researchedAt && Number.isFinite(new Date(input.researchedAt).getTime()) ? new Date(input.researchedAt).getTime() : now
  const ttlDays = status === 'closed' ? 0 : status === 'closing' ? TTL_CLOSING_DAYS : TTL_OPEN_DAYS
  const expiresAt = new Date(base + ttlDays * DAY_MS).toISOString()
  if (reasons.length === 0) reasons.push('Asymmetry intact — window open')

  return { status, openScore, decayPoints: decay, reasons, expiresAt }
}

export function isExpired(verdict: AsymmetryVerdict, nowMs?: number): boolean {
  if (verdict.status === 'closed') return true
  const now = nowMs ?? Date.now()
  const exp = new Date(verdict.expiresAt).getTime()
  return Number.isFinite(exp) && now > exp
}
