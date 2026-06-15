// ── POST /radar/screen — batch ticker screening ──
// Lightweight pre-filter (no LLM): scores tickers on oversold/volume/growth/short-interest
// /52-week-low so the pipeline can rank candidates before running the full radar.
// Body: { tickers?: string[] }  — defaults to the screening watchlist.
//
// ── POST /radar/dcf-screen — InvestingPro-style DCF + multiples screener ──
// Shells out to backend/screener.py with user-supplied filter thresholds.
// Body: { tickers?, dcf_upside_min?, rev_growth_min?, max_pe?, require_insider_cluster? }
//
// ── POST /radar/backtest — event-study backtest ──
// Shells out to backend/backtest.py.
// Body: { tickers, start, end, horizon_days?, benchmark? }

import { Router, type Request, type Response } from 'express'
import { spawn } from 'child_process'
import path from 'path'
import { getStockData, type StockDataResult } from '../lib/stockData'

// Resolve path to backend dir relative to this file (server/src/routes/ → backend/)
const BACKEND_DIR = path.resolve(__dirname, '..', '..', '..', '..', 'backend')

// ---------------------------------------------------------------------------
// Shared helper — spawn a Python script and collect stdout / stderr.
// Rejects on non-zero exit or if stdout is empty / not valid JSON.
// ---------------------------------------------------------------------------
function spawnPython(scriptPath: string, args: string[]): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const child = spawn('python3', [scriptPath, ...args], {
      cwd: BACKEND_DIR,
      env: { ...process.env },
    })

    let stdout = ''
    let stderr = ''

    child.stdout.on('data', (chunk: Buffer) => { stdout += chunk.toString() })
    child.stderr.on('data', (chunk: Buffer) => { stderr += chunk.toString() })

    child.on('close', (code) => {
      // Always log stderr (Python progress output) at debug level
      if (stderr.trim()) {
        const lines = stderr.trim().split('\n')
        lines.forEach(l => console.log(`  [py] ${l}`))
      }
      if (code !== 0) {
        reject(new Error(`Python exited ${code}: ${stderr.slice(-500)}`))
        return
      }
      if (!stdout.trim()) {
        reject(new Error('Python produced no output'))
        return
      }
      try {
        resolve(JSON.parse(stdout))
      } catch {
        reject(new Error(`JSON parse failed: ${stdout.slice(0, 200)}`))
      }
    })

    child.on('error', (err) => reject(err))
  })
}

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

// ---------------------------------------------------------------------------
// POST /radar/dcf-screen
// InvestingPro-style screener: DCF upside + multiples + insider cluster.
//
// Request body:
//   {
//     tickers?:               string[]   // default: built-in watchlist
//     dcf_upside_min?:        number     // default: 20  (%)
//     rev_growth_min?:        number     // optional filter
//     max_pe?:                number     // optional filter
//     require_insider_cluster?: boolean  // default: false
//   }
// ---------------------------------------------------------------------------
router.post('/dcf-screen', async (req: Request, res: Response) => {
  try {
    const body = req.body || {}

    // Build CLI args for screener.py
    const pyArgs: string[] = ['--json']

    if (Array.isArray(body.tickers) && body.tickers.length > 0) {
      pyArgs.push('--tickers', ...body.tickers.map((t: string) => String(t).toUpperCase().trim()))
    }

    const dcfMin = body.dcf_upside_min != null ? Number(body.dcf_upside_min) : 20
    pyArgs.push('--dcf-upside-min', String(dcfMin))

    if (body.rev_growth_min != null) {
      pyArgs.push('--rev-growth-min', String(Number(body.rev_growth_min)))
    }
    if (body.max_pe != null) {
      pyArgs.push('--max-pe', String(Number(body.max_pe)))
    }
    if (body.require_insider_cluster === true) {
      pyArgs.push('--require-insider-cluster')
    }

    console.log(`[dcf-screen] Running screener.py ${pyArgs.join(' ')}`)
    const scriptPath = path.join(BACKEND_DIR, 'screener.py')
    const results = await spawnPython(scriptPath, pyArgs)

    res.json({
      fetchedAt: new Date().toISOString(),
      filters: {
        dcf_upside_min: dcfMin,
        rev_growth_min: body.rev_growth_min ?? null,
        max_pe: body.max_pe ?? null,
        require_insider_cluster: body.require_insider_cluster === true,
      },
      results,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[dcf-screen] Error:', message)
    res.status(500).json({ error: message })
  }
})

// ---------------------------------------------------------------------------
// POST /radar/backtest
// Event-study backtest via backend/backtest.py.
//
// Request body:
//   {
//     tickers:        string[]   // required
//     start:          string     // required, YYYY-MM-DD
//     end:            string     // required, YYYY-MM-DD
//     horizon_days?:  number     // default: 20
//     benchmark?:     string     // default: "SPY"
//   }
// ---------------------------------------------------------------------------
router.post('/backtest', async (req: Request, res: Response) => {
  try {
    const body = req.body || {}

    if (!Array.isArray(body.tickers) || body.tickers.length === 0) {
      res.status(400).json({ error: 'tickers array is required' })
      return
    }
    if (!body.start || !body.end) {
      res.status(400).json({ error: 'start and end (YYYY-MM-DD) are required' })
      return
    }

    const pyArgs: string[] = [
      '--json',
      '--tickers', ...body.tickers.map((t: string) => String(t).toUpperCase().trim()),
      '--start', String(body.start),
      '--end',   String(body.end),
    ]

    if (body.horizon_days != null) {
      pyArgs.push('--horizon-days', String(Number(body.horizon_days)))
    }
    if (body.benchmark) {
      pyArgs.push('--benchmark', String(body.benchmark).toUpperCase())
    }

    console.log(`[backtest] Running backtest.py ${pyArgs.join(' ')}`)
    const scriptPath = path.join(BACKEND_DIR, 'backtest.py')
    const result = await spawnPython(scriptPath, pyArgs)

    res.json(result)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[backtest] Error:', message)
    res.status(500).json({ error: message })
  }
})

export default router
