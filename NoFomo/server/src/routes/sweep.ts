// ── Radar Sweep — prune opportunities whose asymmetry window has closed ──
// Re-evaluates every row in radar_opportunities against the decay model and removes the
// ones no longer asymmetric (consensus / fully-valued / stale). Makes opportunities come
// AND go instead of living forever.
//
// POST /radar/sweep { dry_run?: boolean }  — default TRUE (report only).
//   Deletes require the cron secret (Authorization: Bearer <CRON_SECRET> or body.secret).
// GET /radar/sweep — always a dry-run report (read-only, safe).

import { Router, type Request, type Response } from 'express'
import { getSupabaseAdmin } from '../lib/supabase'
import { evaluateAsymmetry, isExpired, type AsymmetryInput } from '../lib/asymmetryDecay'

const router = Router()
const CRON_SECRET = process.env.CRON_SECRET || 'nofomo-cron-dev'

function hasSecret(req: Request): boolean {
  if (req.query.secret === CRON_SECRET) return true
  const auth = req.headers.authorization || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : auth
  if (token === CRON_SECRET) return true
  if (req.body?.secret === CRON_SECRET) return true
  return false
}

function inputFromRow(row: any): AsymmetryInput {
  const ds = row?.data_snapshot ?? {}
  return {
    marketCap: ds.market_cap ?? null,
    analystCount: ds.analyst_count ?? null,
    price: ds.price ?? null,
    analystTargetMean: ds.avg_price_target ?? null,
    structuredUpsidePct: ds.upside ?? null,
    peerPercentileRank: ds.peer_percentile_rank ?? null,
    rsi: ds.rsi_value ?? null,
    priceHistory: Array.isArray(ds.price_history) ? ds.price_history : null,
    compositeScore: row?.overall_score ?? null,
    contrarianScore: ds.contrarian_score ?? null,
    hasUpcomingCatalyst: Array.isArray(ds.upcoming_events) && ds.upcoming_events.length > 0 ? true : undefined,
    researchedAt: row?.created_at ?? ds.researched_at ?? null,
  }
}

async function handleSweep(req: Request, res: Response) {
  const dryRun = req.method === 'GET' ? true : (req.body?.dry_run !== false)
  const wantsApply = !dryRun
  if (wantsApply && !hasSecret(req)) {
    res.status(401).json({ error: 'Deletes require the cron secret. Use dry_run:true to preview, or pass secret.' })
    return
  }
  try {
    const supabase = getSupabaseAdmin()
    const { data, error } = await supabase
      .from('radar_opportunities')
      .select('ticker, tier, overall_score, created_at, data_snapshot')
    if (error) { res.status(500).json({ error: 'Supabase read failed', detail: error.message }); return }

    const rows = (data ?? []) as any[]
    const keep: Array<{ ticker: string; status: string; openScore: number }> = []
    const prune: Array<{ ticker: string; status: string; openScore: number; reasons: string[] }> = []
    for (const row of rows) {
      const verdict = evaluateAsymmetry(inputFromRow(row))
      if (isExpired(verdict)) prune.push({ ticker: row.ticker, status: verdict.status, openScore: verdict.openScore, reasons: verdict.reasons })
      else keep.push({ ticker: row.ticker, status: verdict.status, openScore: verdict.openScore })
    }

    let deleted = 0
    if (wantsApply && prune.length > 0) {
      const tickers = prune.map(p => p.ticker)
      const { error: delErr } = await supabase.from('radar_opportunities').delete().in('ticker', tickers)
      if (delErr) { res.status(500).json({ error: 'Supabase delete failed', detail: delErr.message }); return }
      deleted = tickers.length
      console.log(`[sweep] Pruned ${deleted} closed/stale opportunities: ${tickers.join(', ')}`)
    }

    res.json({
      sweptAt: new Date().toISOString(), dryRun, total: rows.length,
      kept: keep.length, prunedCount: prune.length, deleted,
      prune: prune.sort((a, b) => a.openScore - b.openScore),
      keep: keep.sort((a, b) => b.openScore - a.openScore),
      note: dryRun ? 'Dry run — nothing deleted. POST { dry_run:false, secret } to apply.' : `Pruned ${deleted} opportunities whose asymmetry window has closed.`,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[sweep] Error:', message)
    res.status(500).json({ error: message })
  }
}

router.get('/sweep', (req, res) => handleSweep(req, res))
router.post('/sweep', (req, res) => handleSweep(req, res))

export default router
