// ── Discovery Pipeline ──
// POST /radar/discover — SEC filings → insider scan → open-universe scout → screen → rank.
// Returns ranked candidates (does NOT persist; the cron route runs /radar on top picks).

import { Router, type Request, type Response } from 'express'
import { scanSECFilings } from '../tools/secFilings'
import { getInsiderData } from '../tools/insider'
import { getStockData, type StockDataResult } from '../lib/stockData'
import { scoutCatalystFilings } from '../lib/edgarScout'

// Seed watchlist (always screened). Open-universe scout adds NEW names on top of this.
const DISCOVERY_WATCHLIST = [
  'PLTR', 'KTOS', 'AVAV', 'LDOS', 'HWM', 'BWXT', 'GD', 'LHX', 'NOC',
  'NVDA', 'AMD', 'AVGO', 'MRVL', 'SMCI', 'MU', 'ANET', 'COHR', 'VRT',
  'CEG', 'VST', 'TLN', 'SMR', 'OKLO', 'GEV', 'ETN',
  'SOUN', 'BBAI', 'AI', 'RDDT', 'DDOG', 'SNOW', 'NET', 'CFLT',
  'RKLB', 'ASTS', 'GSAT', 'LUNR', 'RDW',
  'MSTR', 'COIN', 'HOOD', 'SOFI', 'CLSK',
  'CRVO', 'RXRX', 'ABCL',
  'QTWO', 'ALAB', 'TOST', 'GTLB', 'APP', 'DUOL', 'CELH',
]

const INSIDER_WATCHLIST = [
  'PLTR', 'NVDA', 'AMD', 'MSTR', 'HOOD', 'RKLB', 'SOUN', 'BBAI', 'ASTS',
  'CEG', 'GEV', 'CLSK', 'COIN', 'SMCI', 'VRT', 'ANET', 'APP', 'TOST', 'GTLB',
]

interface DiscoveryTicker {
  ticker: string
  price: number
  changePct: number
  screenScore: number
  signals: string[]
  filingCategory: string | null
  insiderCluster: number | null
  insiderSignal: string | null
  scouted: boolean      // surfaced by open-universe scout (new name, not on watchlist)
}

export interface DiscoveryResult {
  scanId: string
  fetchedAt: string
  pipeline: {
    secFilings: { scanned: number; flagged: number }
    insiderScan: { scanned: number; clustersFound: number }
    openUniverse: { scouted: number }
    screening: { candidates: number }
    fullRadars: number
  }
  topPicks: DiscoveryTicker[]
  allFlagged: DiscoveryTicker[]
}

function prioritizeCategory(cat: string): number {
  if (cat === 'M&A') return 5
  if (cat === 'government contract') return 4
  if (cat === 'financing') return 3
  if (cat === 'partnership/contract') return 2
  if (cat === 'FDA/regulatory') return 2
  return 1
}

async function stageSECFilings(): Promise<Map<string, string>> {
  const result = await scanSECFilings(DISCOVERY_WATCHLIST, 14)
  const flagged = new Map<string, string>()
  for (const f of result.filings) {
    const existing = flagged.get(f.ticker)
    if (!existing || prioritizeCategory(f.category) > prioritizeCategory(existing)) flagged.set(f.ticker, f.category)
  }
  console.log(`[discover] SEC: ${result.scanned} scanned, ${flagged.size} flagged`)
  return flagged
}

async function stageInsiderScan(): Promise<Map<string, number>> {
  const clusters = new Map<string, number>()
  for (const ticker of INSIDER_WATCHLIST) {
    try {
      const insider = await getInsiderData(ticker)
      await new Promise(r => setTimeout(r, 150))
      if (insider.clusterScore >= 4) clusters.set(ticker, insider.clusterScore)
    } catch { /* skip */ }
  }
  console.log(`[discover] Insider: ${INSIDER_WATCHLIST.length} scanned, ${clusters.size} clusters found`)
  return clusters
}

async function stageScreening(tickers: string[]): Promise<Map<string, number>> {
  const scores = new Map<string, number>()
  for (let i = 0; i < tickers.length; i++) {
    let sd: StockDataResult | null = null
    try { sd = await getStockData(tickers[i]) } catch { sd = null }
    if (sd && sd.price > 0) {
      let score = 0
      if (sd.rsi_14 < 40) score += 20
      if (sd.vol_vs_avg && sd.vol_vs_avg > 1.5) score += 15
      if (sd.rev_growth_yoy && sd.rev_growth_yoy > 0) score += 10
      if (sd.short_pct && sd.short_pct > 15) score += 10
      if (sd.price_history.length > 20) {
        const low = Math.min(...sd.price_history), high = Math.max(...sd.price_history)
        const range = high - low
        if (range > 0 && ((sd.price - low) / range) * 100 < 25) score += 15
      }
      if (score > 0) scores.set(sd.ticker, score)
    }
    if (i < tickers.length - 1) await new Promise(r => setTimeout(r, 1000))
  }
  console.log(`[discover] Screening: ${tickers.length} attempted, ${scores.size} scored`)
  return scores
}

const router = Router()

router.post('/discover', async (req: Request, res: Response) => {
  try {
    const scanId = `disc-${Date.now()}`
    console.log(`[discover] Starting pipeline ${scanId}`)

    // Stages 1-3 run concurrently: SEC catalyst filings, insider clusters, open-universe scout.
    const [secFlagged, insiderClusters, scouted] = await Promise.all([
      stageSECFilings().catch(() => new Map<string, string>()),
      stageInsiderScan().catch(() => new Map<string, number>()),
      scoutCatalystFilings(10).catch(() => []),
    ])

    // Open-universe scouted categories (new tickers we weren't already watching).
    const scoutedMap = new Map<string, string>()
    for (const s of scouted) scoutedMap.set(s.ticker, s.category)

    const allCandidates = new Set([
      ...DISCOVERY_WATCHLIST,
      ...secFlagged.keys(),
      ...insiderClusters.keys(),
      ...scoutedMap.keys(),
    ])
    const screenScores = await stageScreening([...allCandidates])

    const merged = new Map<string, DiscoveryTicker>()
    for (const ticker of allCandidates) {
      const onWatchlist = DISCOVERY_WATCHLIST.includes(ticker)
      merged.set(ticker, {
        ticker, price: 0, changePct: 0,
        screenScore: screenScores.get(ticker) ?? 0,
        signals: [],
        filingCategory: secFlagged.get(ticker) ?? scoutedMap.get(ticker) ?? null,
        insiderCluster: insiderClusters.get(ticker) ?? null,
        insiderSignal: null,
        scouted: !onWatchlist && scoutedMap.has(ticker),
      })
    }

    const getInsiderLabel = (score: number) => score >= 7 ? `Insider cluster ${score}/10` : score >= 4 ? `Insider activity ${score}/10` : null
    for (const [, entry] of merged) {
      if (entry.scouted) entry.signals.push('🆕 New name (open-universe scout)')
      if (entry.filingCategory) entry.signals.push(`SEC: ${entry.filingCategory}`)
      const insiderLabel = getInsiderLabel(entry.insiderCluster ?? 0)
      if (insiderLabel) entry.signals.push(insiderLabel)
      if (entry.screenScore >= 20) entry.signals.push(`Screen score ${entry.screenScore}`)
    }

    // Rank: scouted-new + SEC filings > insider clusters > screen score.
    const allFlagged = [...merged.values()].sort((a, b) => {
      const pr = (x: DiscoveryTicker) => (x.scouted ? 3 : 0) + (x.filingCategory ? 2 : 0) + (x.insiderCluster ? 1 : 0)
      const d = pr(b) - pr(a)
      if (d !== 0) return d
      return b.screenScore - a.screenScore
    })
    const topPicks = allFlagged.slice(0, 10)

    const result: DiscoveryResult = {
      scanId,
      fetchedAt: new Date().toISOString(),
      pipeline: {
        secFilings: { scanned: DISCOVERY_WATCHLIST.length, flagged: secFlagged.size },
        insiderScan: { scanned: INSIDER_WATCHLIST.length, clustersFound: insiderClusters.size },
        openUniverse: { scouted: scoutedMap.size },
        screening: { candidates: merged.size },
        fullRadars: 0,
      },
      topPicks,
      allFlagged,
    }
    console.log(`[discover] ${scanId}: ${topPicks.length} top picks from ${merged.size} candidates (${scoutedMap.size} scouted new)`)
    res.json(result)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[discover] Error:', message)
    res.status(500).json({ error: message })
  }
})

export default router
