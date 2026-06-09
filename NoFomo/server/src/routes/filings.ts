// ── GET /radar/filings — recent SEC catalyst filings ──
// Wraps the EDGAR submissions scanner. ?tickers=PLTR,NVDA&days=30 (defaults to a
// small defaults set / 30 days). Returns 8-K / S-1 / 424B filings by catalyst category.

import { Router, type Request, type Response } from 'express'
import { scanSECFilings } from '../tools/secFilings'

const router = Router()

const DEFAULT_TICKERS = ['PLTR', 'NVDA', 'KTOS', 'RKLB', 'ASTS', 'OKLO', 'MSTR', 'VRT', 'SMR', 'CEG']

router.get('/filings', async (req: Request, res: Response) => {
  try {
    const tickersParam = typeof req.query.tickers === 'string' ? req.query.tickers : ''
    const tickers = tickersParam
      ? tickersParam.split(',').map(t => t.trim().toUpperCase()).filter(Boolean)
      : DEFAULT_TICKERS
    const days = Math.min(90, Math.max(1, parseInt(String(req.query.days ?? '30'), 10) || 30))

    const scan = await scanSECFilings(tickers, days)
    res.json({
      fetchedAt: new Date().toISOString(),
      days,
      tickersScanned: scan.scanned,
      count: scan.filings.length,
      filings: scan.filings.sort((a, b) => b.date.localeCompare(a.date)),
    })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

export default router
