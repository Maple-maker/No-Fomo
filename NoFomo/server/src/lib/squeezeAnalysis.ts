// ── Float + Short Squeeze Analysis ──
// Identifies extreme squeeze setups. (Shares Short / Float) is the core metric.
// Most profitable when paired with insider buying (insiders front-run the squeeze).
//
// Source: existing Yahoo stock data (shares_short, float_shares, shares_outstanding,
// short_ratio). Pure arithmetic — no extra API call.

import type { StockDataResult } from './stockData'

export type SqueezeLevel = 'none' | 'caution' | 'high' | 'extreme'

export interface SqueezeSignal {
  floatShares: number | null
  floatPct: number | null
  shortSqueezePct: number      // shares short / float * 100
  daysToCover: number | null   // short ratio
  squeezeLevel: SqueezeLevel
  signal: string
}

export function analyzeShortSqueeze(
  ticker: string,
  stockData?: Partial<StockDataResult> | null,
  insiderPct?: number | null,
): SqueezeSignal | null {
  if (!stockData) return null

  const sharesShort = stockData.shares_short ?? null
  const sharesOut = stockData.shares_outstanding ?? null

  let floatShares = stockData.float_shares ?? null
  if ((floatShares == null || floatShares <= 0) && sharesOut && sharesOut > 0) {
    const insiderFrac = insiderPct != null ? Math.min(0.95, Math.max(0, insiderPct / 100)) : 0
    floatShares = Math.round(sharesOut * (1 - insiderFrac))
  }

  if (sharesShort == null || sharesShort <= 0) return null

  let shortSqueezePct: number
  if (floatShares && floatShares > 0) {
    shortSqueezePct = Math.round((sharesShort / floatShares) * 10000) / 100
  } else if (stockData.short_pct_of_float != null) {
    shortSqueezePct = stockData.short_pct_of_float
  } else {
    return null
  }

  const floatPct = floatShares && sharesOut && sharesOut > 0
    ? Math.round((floatShares / sharesOut) * 10000) / 100
    : null

  const daysToCover = stockData.short_ratio ?? null

  let squeezeLevel: SqueezeLevel = 'none'
  if (shortSqueezePct > 50) squeezeLevel = 'extreme'
  else if (shortSqueezePct > 30) squeezeLevel = 'high'
  else if (shortSqueezePct > 20) squeezeLevel = 'caution'

  let signal: string
  const dtc = daysToCover != null ? `, ${daysToCover.toFixed(1)}d to cover` : ''
  switch (squeezeLevel) {
    case 'extreme': signal = `🚀 Extreme squeeze setup: ${shortSqueezePct}% of float short${dtc}`; break
    case 'high': signal = `🔥 High squeeze risk: ${shortSqueezePct}% of float short${dtc}`; break
    case 'caution': signal = `${shortSqueezePct}% of float short${dtc} — elevated`; break
    default: signal = `${shortSqueezePct}% of float short — normal`
  }

  return { floatShares, floatPct, shortSqueezePct, daysToCover, squeezeLevel, signal }
}
