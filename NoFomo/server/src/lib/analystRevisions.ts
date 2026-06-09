// ── Analyst Estimate Revisions Tracking ──
// Detects earnings inflection 4-8 weeks before the stock reprices.
// Analysts lead price by 4-6 weeks; clustered upward revisions = consensus inflection.
//
// Source: Yahoo Finance recommendationTrend (already fetched in stockData.ts — no extra call).

import type { StockDataResult } from './stockData'

export interface RevisionSignal {
  revisionMomentum: number   // change in net bullishness over the window (positive = upgrades)
  revisionsUp: number        // approximate count of upgrades (net new buy-side ratings)
  revisionsDown: number      // approximate count of downgrades (net new sell-side ratings)
  netBuyChange: number       // change in (strongBuy + buy) headcount vs oldest period
  signal: string
}

function bullishness(p: { strongBuy: number; buy: number; sell: number; strongSell: number }): number {
  return p.strongBuy * 2 + p.buy - p.sell - p.strongSell * 2
}

/**
 * Compute analyst revision momentum from the recommendation trend.
 * Synchronous — reads the trend already present on stockData (no network call).
 * Returns null when trend data is unavailable or too thin to compare.
 */
export function trackAnalystRevisions(
  ticker: string,
  stockData?: Partial<StockDataResult> | null,
): RevisionSignal | null {
  const trend = stockData?.recommendation_trend
  if (!trend || trend.length < 2) return null

  const current = trend.find(t => t.period === '0m') ?? trend[0]
  const oldest = trend.find(t => t.period === '-3m')
    ?? trend.find(t => t.period === '-2m')
    ?? trend[trend.length - 1]

  if (!current || !oldest || current === oldest) return null

  const revisionMomentum = bullishness(current) - bullishness(oldest)
  const netBuyChange = (current.strongBuy + current.buy) - (oldest.strongBuy + oldest.buy)
  const netSellChange = (current.sell + current.strongSell) - (oldest.sell + oldest.strongSell)

  const revisionsUp = Math.max(0, netBuyChange)
  const revisionsDown = Math.max(0, netSellChange)

  let signal: string
  if (revisionMomentum >= 3 && revisionsUp >= 3) {
    signal = `🎯 Estimates revised sharply up (+${revisionsUp} buy ratings, momentum +${revisionMomentum}) — consensus inflection`
  } else if (revisionMomentum > 0 && revisionsUp >= 1) {
    signal = `Analyst sentiment improving (+${revisionsUp} buy ratings over 90d)`
  } else if (revisionMomentum < -2) {
    signal = `Analyst sentiment deteriorating (${revisionsDown} downgrades over 90d)`
  } else {
    signal = 'Analyst consensus stable'
  }

  return { revisionMomentum, revisionsUp, revisionsDown, netBuyChange, signal }
}
