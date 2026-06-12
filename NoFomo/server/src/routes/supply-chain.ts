// ── POST /radar/supply-chain — supply-chain asymmetry scan ──
// Given anchor companies and/or a theme, surface the second-order beneficiaries (suppliers,
// pick-and-shovel plays) that the market hasn't repriced. Screens them; optionally runs the
// full radar on top picks to persist. Body: { anchors?: string[], theme?: string, run_radars?: boolean }.

import { Router, type Request, type Response } from 'express'
import { getStockData } from '../lib/stockData'

const router = Router()

// Anchor company → its supply-chain beneficiaries (pick-and-shovel / suppliers).
const ANCHOR_BENEFICIARIES: Record<string, string[]> = {
  NVDA: ['VRT', 'ANET', 'COHR', 'MU', 'ALAB', 'SMCI', 'CRDO'],
  MSFT: ['VRT', 'ANET', 'CEG', 'GEV'],
  AMZN: ['VRT', 'ETN', 'GEV'],
  AAPL: ['QCOM', 'SWKS', 'QRVO', 'CRUS'],
  TSLA: ['ALB', 'APTV', 'AEVA'],
  PLTR: ['BBAI', 'SOUN'],
  OKLO: ['BWXT', 'CCJ', 'CEG'],
  RKLB: ['RDW', 'LUNR'],
}

// Theme → beneficiary cohort.
const THEME_BENEFICIARIES: Record<string, string[]> = {
  ai: ['VRT', 'ANET', 'COHR', 'ALAB', 'MU', 'SMCI', 'CRDO'],
  'ai infrastructure': ['VRT', 'ANET', 'COHR', 'ALAB', 'MU', 'SMCI', 'CRDO'],
  datacenter: ['VRT', 'ETN', 'GEV', 'CEG', 'ANET'],
  'data center': ['VRT', 'ETN', 'GEV', 'CEG', 'ANET'],
  power: ['CEG', 'VST', 'GEV', 'ETN', 'BWXT'],
  energy: ['CEG', 'VST', 'SMR', 'OKLO', 'GEV'],
  nuclear: ['SMR', 'OKLO', 'BWXT', 'CCJ', 'CEG'],
  defense: ['KTOS', 'AVAV', 'BWXT', 'LHX'],
  space: ['RKLB', 'ASTS', 'LUNR', 'RDW'],
}

function resolveBeneficiaries(anchors: string[], theme?: string): string[] {
  const out = new Set<string>()
  for (const a of anchors) for (const b of ANCHOR_BENEFICIARIES[a.toUpperCase()] ?? []) out.add(b)
  if (theme) for (const b of THEME_BENEFICIARIES[theme.toLowerCase().trim()] ?? []) out.add(b)
  // Don't recommend the anchors themselves.
  for (const a of anchors) out.delete(a.toUpperCase())
  return [...out]
}

router.post('/supply-chain', async (req: Request, res: Response) => {
  try {
    const body = req.body || {}
    const anchors: string[] = Array.isArray(body.anchors) ? body.anchors.map((s: string) => String(s).toUpperCase().trim()) : []
    const theme: string | undefined = typeof body.theme === 'string' ? body.theme : undefined
    const runRadars: boolean = body.run_radars === true

    const beneficiaries = resolveBeneficiaries(anchors, theme)
    if (beneficiaries.length === 0) {
      res.json({ scanId: `sc-${Date.now()}`, anchors, theme: theme ?? null, candidates: [], persisted: 0, note: 'No mapped beneficiaries for those anchors/theme.' })
      return
    }
    console.log(`[supply-chain] anchors=[${anchors.join(',')}] theme=${theme ?? '-'} → ${beneficiaries.length} beneficiaries`)

    // Screen beneficiaries (lightweight).
    const candidates: Array<{ ticker: string; price: number; changePct: number; score: number }> = []
    for (let i = 0; i < beneficiaries.length; i++) {
      try {
        const sd = await getStockData(beneficiaries[i])
        if (sd && sd.price > 0) {
          let score = 0
          if (sd.rsi_14 < 45) score += 20
          if ((sd.analyst_count ?? 99) <= 5) score += 15
          if (sd.rev_growth_yoy && sd.rev_growth_yoy > 10) score += 15
          candidates.push({ ticker: sd.ticker, price: sd.price, changePct: sd.change_pct, score })
        }
      } catch { /* skip */ }
      if (i < beneficiaries.length - 1) await new Promise(r => setTimeout(r, 1000))
    }
    candidates.sort((a, b) => b.score - a.score)

    // Optionally run the full radar on the top picks to persist them.
    let persisted = 0
    if (runRadars && candidates.length > 0) {
      const baseUrl = process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : `http://localhost:${process.env.PORT || 3001}`
      for (const c of candidates.slice(0, 2)) {
        try {
          const r = await fetch(`${baseUrl}/radar`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ticker: c.ticker }) })
          if (r.ok) { const j = await r.json() as any; if (j.persisted) persisted++ }
        } catch { /* skip */ }
        await new Promise(res2 => setTimeout(res2, 2000))
      }
    }

    res.json({
      scanId: `sc-${Date.now()}`,
      fetchedAt: new Date().toISOString(),
      anchors, theme: theme ?? null,
      beneficiariesScanned: beneficiaries.length,
      candidates,
      persisted,
    })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

export default router
