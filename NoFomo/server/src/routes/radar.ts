import { Router, type Request, type Response } from 'express'
import { runAgent } from '../agents/runner'
import { createToolRegistry } from '../agents/tools'
import { radarAgent } from '../agents/radar'
import { braveSearch } from '../tools/web'
import { getStockPrice } from '../tools/market'
import { getSupabaseAdmin } from '../lib/supabase'
import { extractJsonBlock, buildRadarRow } from '../lib/opportunity'
import { runCouncil } from './council'

const router = Router()

router.post('/', async (req: Request, res: Response) => {
  const ticker = (req.body.ticker as string)?.trim()?.toUpperCase()?.replace(/^\$/, '')
  if (!ticker) {
    res.status(400).json({ error: 'Ticker required' })
    return
  }

  const skipCouncil = req.body.skip_council === true
  const skipPersist = req.body.skip_persist === true

  try {
    const supabase = skipPersist ? null : getSupabaseAdmin()
    const userId = req.body.user_id || 'radar-server'

    // Phase 1 — Research
    console.log(`[radar] Researching $${ticker}...`)

    const registry = createToolRegistry()
    registry.register(braveSearch)
    registry.register(getStockPrice)

    const prompt = `Research $${ticker} across all four lanes. Use web_search to find:
1. Business model, products, customers, competitive position, industry context
2. Financial health: revenue, margins, debt, FCF, valuation multiples
3. Sentiment: recent news, earnings call tone, analyst actions, catalysts
4. Macro & industry linkage: key drivers, risks, tailwinds

Use get_stock_price for the current price.

Search at least 6 times across all four areas, then synthesize the full dossier with the JSON scoring block.`

    const result = await runAgent(
      radarAgent,
      { userId, supabase },
      prompt,
      registry,
    )

    console.log(`[radar] Research complete — ${result.toolCalls} tool calls, ${result.text.length} chars`)

    // Phase 2 — Extract structured data from JSON block
    const structured = extractJsonBlock(result.text)
    if (!structured) {
      res.status(500).json({
        error: 'Failed to extract structured data from radar output',
        rawText: result.text.slice(0, 2000),
        toolCalls: result.toolCalls,
      })
      return
    }

    structured.ticker = ticker
    structured.fullReportMd = result.text
    structured.price = structured.price || 0

    // Phase 3 — AI Council
    let councilResult
    if (!skipCouncil) {
      console.log(`[radar] Running AI council for $${ticker}...`)
      councilResult = await runCouncil(result.text)
    } else {
      councilResult = null
    }

    // Phase 4 — Assemble and persist
    const row = buildRadarRow(
      structured,
      councilResult?.gemini ?? { verdict: 'BULL', reasoning: '' },
      councilResult?.deepseek ?? { verdict: 'BULL', reasoning: '' },
      councilResult?.cio ?? {
        verdict: 'BULL',
        synthesis: '',
        tier: structured.tier,
        score: structured.score,
        tripleSignal: structured.tripleSignal,
      },
    )

    let persisted = false
    if (!skipPersist) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { error } = await supabase.from('radar_opportunities').insert(row as any)
      if (error) {
        console.error('[radar] Supabase insert error:', error)
        res.status(500).json({
          error: 'Failed to persist to Supabase',
          detail: error.message,
          row,
        })
        return
      }
      persisted = true
      console.log(`[radar] $${ticker} persisted to radar_opportunities`)
    }

    res.json({
      ticker,
      tier: row.tier,
      score: row.overall_score,
      tripleSignal: row.data_snapshot.triple_signal,
      council: row.data_snapshot.council,
      bluf: row.thesis,
      persisted,
      toolCalls: result.toolCalls,
      dossierLength: result.text.length,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[radar] Error:', message)
    res.status(500).json({ error: message })
  }
})

export default router
