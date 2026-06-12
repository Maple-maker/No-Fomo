// ── Cron Pipeline ──
// GET/POST /radar/cron — discovery → radar top picks → persist → sweep stale/closed.
// GET: Vercel Cron (query param ?secret=...). POST: manual trigger.
// FIX: the scheduled GET now RUNS RADARS by default (previously GET persisted nothing —
// the feed never grew). Pass ?run_radars=false to discover-only.
// On Vercel Hobby the function time limit may truncate multi-radar runs; for full
// automation point cron-job.org at this endpoint (no timeout) — see vercel.json maxDuration.

import { Router, type Request, type Response } from 'express'

const router = Router()

const MAX_RADARS_PER_RUN = parseInt(process.env.CRON_MAX_RADARS || '3', 10)
const CRON_SECRET = process.env.CRON_SECRET || 'nofomo-cron-dev'

function checkAuth(req: Request): boolean {
  if (req.query.secret === CRON_SECRET) return true
  const auth = req.headers.authorization || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : auth
  if (token === CRON_SECRET) return true
  if (req.body?.secret === CRON_SECRET) return true
  return false
}

async function handleCron(req: Request, res: Response) {
  if (!checkAuth(req)) {
    res.status(401).json({ error: 'Unauthorized — invalid CRON_SECRET' })
    return
  }

  // Both scheduled GET and manual POST run radars by default (this is what persists new
  // opportunities). Pass run_radars=false (query or body) to only discover candidates.
  const runRadars = req.method === 'POST'
    ? (req.body?.run_radars !== false)
    : (req.query.run_radars !== 'false')

  try {
    const scanId = `cron-${Date.now()}`
    console.log(`[cron] Starting pipeline ${scanId} (runRadars=${runRadars})`)

    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : `http://localhost:${process.env.PORT || 3001}`

    // Stage 1: Discover candidates (watchlist + SEC + insider + open-universe scout)
    const discoRes = await fetch(`${baseUrl}/radar/discover`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}),
    })
    if (!discoRes.ok) {
      const err = await discoRes.text().catch(() => 'unknown')
      res.status(500).json({ error: 'Discovery stage failed', detail: err.slice(0, 500) })
      return
    }
    const disco = await discoRes.json() as any
    const topPicks: Array<{ ticker: string; screenScore: number; signals: string[] }> = disco.topPicks || []
    const candidates = (disco.allFlagged || []).length
    console.log(`[cron] Discovery: ${candidates} candidates, ${topPicks.length} top picks`)

    // Stage 2: Run radars on top picks (this PERSISTS new opportunities)
    const results: Array<{ ticker: string; tier: number; score: number; persisted: boolean; windowStatus?: string; error?: string }> = []
    if (runRadars && topPicks.length > 0) {
      const toRadar = topPicks.slice(0, MAX_RADARS_PER_RUN)
      for (const pick of toRadar) {
        try {
          console.log(`[cron] Running radar on $${pick.ticker}...`)
          const radarRes = await fetch(`${baseUrl}/radar`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ticker: pick.ticker }),
          })
          if (radarRes.ok) {
            const radar = await radarRes.json() as any
            results.push({ ticker: pick.ticker, tier: radar.tier || 2, score: radar.score || 0, persisted: radar.persisted || false, windowStatus: radar.windowStatus })
            console.log(`[cron] $${pick.ticker}: Tier ${radar.tier} Score ${radar.score} window=${radar.windowStatus}`)
          } else {
            results.push({ ticker: pick.ticker, tier: 0, score: 0, persisted: false, error: `HTTP ${radarRes.status}` })
          }
        } catch (e) {
          results.push({ ticker: pick.ticker, tier: 0, score: 0, persisted: false, error: e instanceof Error ? e.message : String(e) })
        }
        if (toRadar.indexOf(pick) < toRadar.length - 1) await new Promise(r => setTimeout(r, 2000))
      }
    }
    const persisted = results.filter(r => r.persisted).length

    // Stage 3: Sweep — prune opportunities whose asymmetry window has closed (stale/consensus)
    let pruned = 0
    try {
      const sweepRes = await fetch(`${baseUrl}/radar/sweep`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${CRON_SECRET}` }, body: JSON.stringify({ dry_run: false }),
      })
      if (sweepRes.ok) { const sweep = await sweepRes.json() as any; pruned = sweep.deleted ?? 0 }
    } catch (e) {
      console.warn('[cron] Sweep failed:', e instanceof Error ? e.message : e)
    }
    console.log(`[cron] Complete: ${topPicks.length} top picks, ${results.length} radars, ${persisted} persisted, ${pruned} pruned`)

    res.json({
      scanId, ranAt: new Date().toISOString(), candidates,
      topPicks: topPicks.slice(0, 10).map(p => ({ ticker: p.ticker, screenScore: p.screenScore, signals: p.signals, queueForRadar: !runRadars })),
      radarsRun: results.length, persisted, pruned, results,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[cron] Pipeline error:', message)
    res.status(500).json({ error: message })
  }
}

router.get('/cron', (req, res) => handleCron(req, res))
router.post('/cron', (req, res) => handleCron(req, res))

export default router
