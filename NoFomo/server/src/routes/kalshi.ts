// ── GET /radar/kalshi — browse Kalshi prediction-market signals (Jelly Signals) ──
import { Router, type Request, type Response } from 'express'
import { getKalshiMarkets } from '../tools/kalshi'

const router = Router()

router.get('/kalshi', async (req: Request, res: Response) => {
  try {
    const query = typeof req.query.q === 'string' ? req.query.q : undefined
    const markets = await getKalshiMarkets(query, 300)
    res.json({
      fetchedAt: new Date().toISOString(),
      query: query ?? null,
      count: markets.length,
      markets,
    })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

export default router
