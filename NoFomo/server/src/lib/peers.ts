// ── Peer Cohort Valuation Positioning ──
// Scores a ticker's valuation vs. its peer group across multiple multiples.

import { getStockData, type StockDataResult } from './stockData'

export interface PeerMetrics {
  psTtm: { ticker: number | null; median: number | null; rank: number }
  psForward: { ticker: number | null; median: number | null; rank: number }
  evEbitda: { ticker: number | null; median: number | null; rank: number }
  grossMargin: { ticker: number | null; median: number | null; rank: number }
  revGrowth: { ticker: number | null; median: number | null; rank: number }
  pegScore: { ticker: number | null; median: number | null; rank: number }
}

// One row of the head-to-head comparison table (target first, then peers).
export interface PeerCompany {
  ticker: string
  isTarget: boolean
  psTtm: number | null
  evEbitda: number | null
  grossMargin: number | null
  revGrowth: number | null
}

export interface PeerPositioning {
  peers: string[]
  percentileRank: number
  metrics: PeerMetrics
  verdict: 'cheap_growth' | 'fair' | 'expensive' | 'value_trap'
  table: PeerCompany[]
}

const PEER_GROUPS: Record<string, string[]> = {
  PLTR: ['AI', 'BBAI', 'SOUN'], NVDA: ['AMD', 'QCOM', 'MU'], AMD: ['NVDA', 'QCOM', 'INTC'],
  MU: ['QCOM', 'AVGO', 'WDC'], QCOM: ['NVDA', 'AMD', 'AVGO'], AVAV: ['KTOS', 'LMT', 'RTX'],
  KTOS: ['AVAV', 'LMT', 'RTX'], RKLB: ['ASTS', 'LUNR', 'RDW'], TSLA: ['RIVN', 'LCID', 'NIO'],
  RIVN: ['TSLA', 'LCID', 'GM'], PANW: ['CRWD', 'ZS', 'S'], DDOG: ['NET', 'ESTC', 'SNOW'],
  SNOW: ['DDOG', 'ESTC', 'MDB'], MDB: ['SNOW', 'ESTC', 'CRWD'], LLY: ['JNJ', 'MRNA', 'BNTX'],
  ISRG: ['SYK', 'BSX', 'MDT'], VRTX: ['REGN', 'BIIB', 'ALNY'], LMT: ['RTX', 'NOC', 'GD'],
  RTX: ['LMT', 'NOC', 'GD'], CEG: ['NEE', 'DUK', 'SO'], ETN: ['EMR', 'HON', 'PH'],
  APP: ['DASH', 'COIN', 'SQ'], VRT: ['ETN', 'NVT', 'PWR'], OKLO: ['SMR', 'CEG', 'VST'],
  ASTS: ['RKLB', 'GSAT', 'IRDM'], MSTR: ['COIN', 'CLSK', 'MARA'],
}

export function getPeers(ticker: string): string[] {
  return PEER_GROUPS[ticker.toUpperCase().trim()] ?? []
}

export async function getPeerPositioning(
  ticker: string,
  targetData: Partial<StockDataResult>,
): Promise<PeerPositioning | null> {
  const t = ticker.toUpperCase().trim()
  const peerTickers = PEER_GROUPS[t]
  if (!peerTickers || peerTickers.length === 0) return null

  try {
    const peersToFetch = peerTickers.slice(0, 3)
    const peerResults: (Partial<StockDataResult> | null)[] = await Promise.allSettled(
      peersToFetch.map(p => getStockData(p).catch(() => null)),
    ).then(results => results.map(r => (r.status === 'fulfilled' ? r.value : null)))

    const allData = [targetData, ...peerResults.filter(Boolean)]
    if (allData.length < 2) return null

    const psTtms = allData.map(d => d?.ps_ttm).filter(v => v != null && v > 0) as number[]
    const evEbitdas = allData.map(d => d?.ev_ebitda).filter(v => v != null && v > 0) as number[]
    const grossMargins = allData.map(d => d?.gross_margin).filter(v => v != null) as number[]
    const revGrowths = allData.map(d => d?.rev_growth_yoy).filter(v => v != null) as number[]

    const psTtmMedian = computeMedian(psTtms)
    const evEbitdaMedian = computeMedian(evEbitdas)
    const grossMarginMedian = computeMedian(grossMargins)
    const revGrowthMedian = computeMedian(revGrowths)

    const targetPeg = targetData.ps_ttm && targetData.rev_growth_yoy && targetData.rev_growth_yoy > 0
      ? targetData.ps_ttm / targetData.rev_growth_yoy : null
    const pegScores = allData.map(d => (d?.ps_ttm && d?.rev_growth_yoy && d.rev_growth_yoy > 0 ? d.ps_ttm / d.rev_growth_yoy : null))
      .filter(v => v != null) as number[]
    const pegMedian = computeMedian(pegScores)

    const ranks = [
      computeRank(targetData.ps_ttm, psTtms),
      computeRank(targetData.ev_ebitda, evEbitdas),
      computeRank(targetPeg, pegScores),
    ].filter(r => r >= 0)
    const percentileRank = ranks.length > 0 ? Math.round(ranks.reduce((a, b) => a + b) / ranks.length) : 50

    let verdict: PeerPositioning['verdict'] = 'fair'
    if (percentileRank < 30 && (targetData.rev_growth_yoy || 0) > (revGrowthMedian || 0)) verdict = 'cheap_growth'
    else if (percentileRank > 70 && (targetData.rev_growth_yoy || 0) < (revGrowthMedian || 0)) verdict = 'value_trap'
    else if (percentileRank > 70) verdict = 'expensive'

    // Head-to-head table: target first, then each peer (preserving order + nulls).
    const toRow = (tk: string, d: Partial<StockDataResult> | null, isTarget: boolean): PeerCompany => ({
      ticker: tk,
      isTarget,
      psTtm: d?.ps_ttm ?? null,
      evEbitda: d?.ev_ebitda ?? null,
      grossMargin: d?.gross_margin ?? null,
      revGrowth: d?.rev_growth_yoy ?? null,
    })
    const table: PeerCompany[] = [
      toRow(t, targetData, true),
      ...peersToFetch.map((p, i) => toRow(p, peerResults[i], false)),
    ]

    return {
      peers: peersToFetch,
      percentileRank,
      table,
      metrics: {
        psTtm: { ticker: targetData.ps_ttm || null, median: psTtmMedian, rank: computeRank(targetData.ps_ttm, psTtms) },
        psForward: { ticker: targetData.ps_ttm || null, median: psTtmMedian, rank: computeRank(targetData.ps_ttm, psTtms) },
        evEbitda: { ticker: targetData.ev_ebitda || null, median: evEbitdaMedian, rank: computeRank(targetData.ev_ebitda, evEbitdas) },
        grossMargin: { ticker: targetData.gross_margin || null, median: grossMarginMedian, rank: computeRank(targetData.gross_margin, grossMargins) },
        revGrowth: { ticker: targetData.rev_growth_yoy || null, median: revGrowthMedian, rank: computeRank(targetData.rev_growth_yoy, revGrowths) },
        pegScore: { ticker: targetPeg, median: pegMedian, rank: computeRank(targetPeg, pegScores) },
      },
      verdict,
    }
  } catch (e) {
    console.error(`[peers] Error computing positioning for ${t}:`, e instanceof Error ? e.message : e)
    return null
  }
}

function computeMedian(values: number[]): number | null {
  if (values.length === 0) return null
  const sorted = [...values].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}

function computeRank(value: number | null | undefined, peers: number[]): number {
  if (value == null || peers.length === 0) return -1
  const sorted = [...peers].sort((a, b) => a - b)
  let rank = 0
  for (const p of sorted) if (value > p) rank++
  return Math.round((rank / sorted.length) * 100)
}
