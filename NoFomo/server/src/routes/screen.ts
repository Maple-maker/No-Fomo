// ── POST /radar/screen — batch ticker screening ──
// Lightweight pre-filter (no LLM): scores tickers on oversold/volume/growth/short-interest
// /52-week-low so the pipeline can rank candidates before running the full radar.
// Body: { tickers?: string[] }  — defaults to the screening watchlist.

import { Router, type Request, type Response } from 'express'
import { getStockData, type StockDataResult } from '../lib/stockData'

const router = Router()

const WATCHLIST = [
  'PLTR', 'KTOS', 'AVAV', 'BWXT', 'NVDA', 'AMD', 'MRVL', 'SMCI', 'MU', 'ANET', 'VRT',
  'CEG', 'VST', 'SMR', 'OKLO', 'GEV', 'SOUN', 'BBAI', 'RKLB', 'ASTS', 'LUNR',
  'MSTR', 'COIN', 'HOOD', 'CLSK', 'ALAB', 'APP',
]

interface ScreenResult {
  ticker: string
  price: number
  score: number
  signals: string[]
}

function scoreTicker(sd: StockDataResult): ScreenResult | null {
  if (!sd || sd.price <= 0) return null
  let score = 0
  const signals: string[] = []
  if (sd.rsi_14 < 40) { score += 20; signals.push(`RSI ${sd.rsi_14} oversold`) }
  if (sd.vol_vs_avg && sd.vol_vs_avg > 1.5) { score += 15; signals.push(`Volume ${sd.vol_vs_avg}x avg`) }
  if (sd.rev_growth_yoy && sd.rev_growth_yoy > 0) { score += 10; signals.push(`Revenue +${sd.rev_growth_yoy}% YoY`) }
  if (sd.short_pct && sd.short_pct > 15) { score += 10; signals.push(`${sd.short_pct}% short`) }
  if (sd.price_history.length > 20) {
    const low = Math.min(...sd.price_history), high = Math.max(...sd.price_history)
    const range = high - low
    if (range > 0 && ((sd.price - low) / range) * 100 < 25) { score += 15; signals.push('Near 52-week low') }
  }
  if ((sd.analyst_count ?? 99) <= 3) { score += 10; signals.push(`Underfollowed (${sd.analyst_count ?? 0} analysts)`) }
  return { ticker: sd.ticker, price: sd.price, score, signals }
}

router.post('/screen', async (req: Request, res: Response) => {
  try {
    const body = req.body || {}
    const tickers: string[] = Array.isArray(body.tickers) && body.tickers.length
      ? body.tickers.map((t: string) => String(t).toUpperCase().trim()).filter(Boolean)
      : WATCHLIST
    console.log(`[screen] Scanning ${tickers.length} tickers...`)

    const results: ScreenResult[] = []
    for (let i = 0; i < tickers.length; i++) {
      try {
        const sd = await getStockData(tickers[i])
        const scored = scoreTicker(sd)
        if (scored && scored.score > 0) results.push(scored)
      } catch { /* skip */ }
      if (i < tickers.length - 1) await new Promise(r => setTimeout(r, 1000))
    }
    results.sort((a, b) => b.score - a.score)
    res.json({
      fetchedAt: new Date().toISOString(),
      scanned: tickers.length,
      candidates: results.length,
      results,
    })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

export default router
