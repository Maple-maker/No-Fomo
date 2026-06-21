import { Router, type Request, type Response } from 'express'
import { getDeepSeekClient, DEEPSEEK_MODEL } from '../agents/client'
import { braveSearch } from '../tools/web'
import { exaSearch } from '../tools/exa'
import { getStockPrice } from '../tools/market'
import { samGovSearch } from '../tools/sam'
import { quiverEnrich, enrichTicker, formatSources } from '../tools/quiver'
import { fullEnrich, type TickerEnrichment } from '../lib/enrich'
import { getInsiderData, type InsiderResult } from '../tools/insider'
import { getSupabaseAdmin } from '../lib/supabase'
import { extractJsonBlock, buildRadarRow } from '../lib/opportunity'
import { selectMode } from '../agents/tiers'
import { runCouncil, runWallStreet } from './council'
import type { CouncilVerdict, CIOArbiter } from '../agents/types'
import type { ValuationSnapshot, WallStreetSnapshot } from '../lib/opportunity'
import { notifyIfQualifying } from '../lib/pushNotify'
import { getSectorPositioning, getMarketPositioning } from '../lib/peers'
import { computeSignals } from '../lib/signals'
import { getMacroContext } from '../lib/macroRegime'
import { tagThemes } from '../lib/themes'
import { getPeerPositioning } from '../lib/peers'
import { getStockData, fetchChartPayload, ensureChartHistory, MIN_CHART_FLOOR } from '../lib/stockData'
import { evaluateAsymmetry } from '../lib/asymmetryDecay'
import { computeConfidence } from '../lib/confidence'
import { runRadarV2Shadow } from '../lib/radarV2Shadow'

const router = Router()

router.get('/chart', async (req: Request, res: Response) => {
  const ticker = String(req.query.ticker || '').toUpperCase().trim()
  if (!ticker) {
    res.status(400).json({ error: 'ticker query param required' })
    return
  }
  try {
    const payload = await fetchChartPayload(ticker)
    res.json(payload)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    res.status(500).json({ error: message })
  }
})

function extractSourcesFromText(text: string): { label: string; url: string }[] {
  const urlRegex = /https?:\/\/[^\s\)\]\"\'<>]+/g
  const urls = text.match(urlRegex) || []
  const unique = [...new Set(urls)].filter(u =>
    !u.includes('example.com') && !u.includes('localhost') && u.length > 25
  )
  return unique.slice(0, 8).map((url) => {
    let label = 'Source'
    if (url.includes('sec.gov')) label = 'SEC Filing'
    else if (url.includes('reuters.com')) label = 'Reuters'
    else if (url.includes('bloomberg.com')) label = 'Bloomberg'
    else if (url.includes('cnbc.com')) label = 'CNBC'
    else if (url.includes('yahoo.com')) label = 'Yahoo Finance'
    else if (url.includes('defense.gov')) label = 'DoD'
    else if (url.includes('sam.gov')) label = 'SAM.gov'
    else if (url.includes('fda.gov')) label = 'FDA'
    else if (url.includes('nasa.gov')) label = 'NASA'
    else if (url.includes('energy.gov')) label = 'DOE'
    else if (url.includes('wikipedia.org')) label = 'Wikipedia'
    return { label, url }
  })
}

const SYSTEM_PROMPT = `You are an elite equity research analyst producing institutional-quality writeups. Use web_search (Brave — for real-time news), exa_search (for semantic discovery), and get_stock_price, then synthesize a dossier ending with a JSON scoring block.

## DISCOVERY MANDATE
Scan across ALL industries. No sector is excluded. The edge comes from finding mispricing, not from staying inside a predefined list. Look for:
- New government contracts (DoD, DARPA, NASA, DOE, DHS) — use sam_gov_search to find recent awards
- Revenue inflections (first profitable quarter, accelerating ARR, contract backlog growth)
- Regulatory approvals (FDA, FAA, FCC, NRC, export licenses)
- Major partnerships (prime contractors, hyperscalers, sovereign governments)
- Insider buying (Form 4 filings, open-market purchases, concentrated buying clusters)
- Founder-led companies (CEO/founder owns >5%, skin in the game)
- Spin-offs and corporate separations (forced selling, misunderstood valuation)
- Underfollowed stocks (0–3 analyst coverage, no ETF inclusion, low institutional ownership)
- Rebrands and renaissance companies — legacy businesses that have quietly transformed
- Patent filing velocity (R&D pipeline acceleration = innovation signal)
- Revenue inflection inflection points (growth reaccelerating after stagnation)
- Founder alignment (CEO/founder ownership >5% = highest conviction on capital allocation)
- Peer valuation discount (bottom-quartile multiples vs. comparable peers + equivalent growth)
- GAAP quality signals (operating cash flow > net income = high-quality earnings, not accruals)

## RESEARCH LANES
Research across FOUR lanes:
1. Business Model & Operations — products, customers, competitive position, moat
2. Financial Health — revenue, margins, balance sheet, valuation vs peers
3. Sentiment & Catalysts — news, analyst actions, insider trading, upcoming events
4. Macro & Industry Context — macro drivers, industry tailwinds, regulatory exposure

## DETECTION LANE
Classify the primary discovery signal: "Government & Regulatory Support" | "Insider Activity & Smart Money" | "Overlooked / Underfollowed" | "Indirect Beneficiary" | "Sector Dislocation" | "Renaissance / Rebrand" | "Technology Breakthrough"

DOSSIER FORMAT:
## $TICKER Research
**Price**: $X.XX | **Sector**: Industry | **Detection Lane**: [lane]

### Competitive Advantages
3-4 specific moat pillars. Each must cite numbers, market share, or structural advantages competitors cannot replicate in 3-5 years. Format like: "Exceptional revenue growth with industry-leading margins: FY2025 revenue grew 45% to $65.2B with gross margin of 83.2%, driven by..."

### Investment Risks
3-4 specific risks ranked by severity. Each must name a concrete vulnerability with data: "Pricing pressure: Management guided low-to-mid teens negative price impact from Medicare/Medicaid access agreements..."

### Bull Case
- Point 1
- Point 2
- Point 3

### Bear Case
- Risk 1
- Risk 2
- Risk 3

### Verdict
One paragraph investment thesis.

\`\`\`json
{"ticker":"$TICKER","companyName":"Full Company Name","sector":"Industry","detectionLane":"lane","tier":2,"score":70,"tripleSignal":false,"bluf":"One sentence thesis","price":0,"upside":50,"marketCap":"$XB","probability":60,"catalyst":"catalyst description","buyZones":{"aggressive":0,"base":0,"conservative":0},"bullCase":"bull thesis","bearCase":"bear thesis","financials":[["Revenue (TTM)","$X"],["Net Income","$X"],["EPS","$X.XX"],["FCF","$X"],["Cash","$X"],["Total Debt","$X"]],"redFlags":["Risk 1","Risk 2"],"invalidation":"What breaks the thesis","competitiveAdvantages":"Full competitive advantages analysis text (3-4 moat pillars with specific numbers)","investmentRisks":"Full investment risks analysis text (3-4 risks ranked by severity with data)","keyMetrics":{"peTrailing":"Xx","peForward":"Xx","evEbitda":"Xx","grossMargin":"X%","operatingMargin":"X%","dividendYield":"X%","beta":"X.X"}}
\`\`\``

router.post('/', async (req: Request, res: Response) => {
  const ticker = (req.body.ticker as string)?.trim()?.toUpperCase()?.replace(/^\$/, '')
  if (!ticker) { res.status(400).json({ error: 'Ticker required' }); return }

  const skipCouncil = req.body.skip_council === true
  const skipPersist = req.body.skip_persist === true

  try {
    const supabase = skipPersist ? null : getSupabaseAdmin()
    const client = getDeepSeekClient()

    // Build tools — always include Brave, add Exa if key is set, always include price
    const tools: any[] = [
      { type: 'function' as const, function: { name: 'web_search', description: 'Search the web for real-time news and information', parameters: { type: 'object', properties: { query: { type: 'string' } }, required: ['query'] } } },
      { type: 'function' as const, function: { name: 'get_stock_price', description: 'Get current stock price and daily change', parameters: { type: 'object', properties: { ticker: { type: 'string' } }, required: ['ticker'] } } },
    ]

    if (process.env.EXA_API_KEY) {
      tools.push({ type: 'function' as const, function: { name: 'exa_search', description: 'Neural semantic search — find companies, contracts, and themes conceptually. Use for discovery queries.', parameters: { type: 'object', properties: { query: { type: 'string' }, numResults: { type: 'number' } }, required: ['query'] } } })
    }

    if (process.env.QUIVER_API_KEY) {
      tools.push({ type: 'function' as const, function: { name: 'quiver_enrich', description: 'Get real news headlines (with clickable URLs), upcoming events/catalysts, insider trades (SEC Form 4), government contracts, and congressional trading activity for a ticker. All sources are verifiable.', parameters: { type: 'object', properties: { ticker: { type: 'string' } }, required: ['ticker'] } } })
    }

    if (process.env.SAM_API_KEY) {
      tools.push({ type: 'function' as const, function: { name: samGovSearch.name, description: samGovSearch.description, parameters: samGovSearch.parameters as Record<string, unknown> } })
    }

    console.log(`[radar] Researching $${ticker}... (tools: ${tools.map((t: any) => t.function.name).join(', ')})`)

    // PHASE 1 — Gather data with tools
    const msgs: any[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: `Research $${ticker}. Use web_search at least 3 times and get_stock_price once.${process.env.EXA_API_KEY ? ' Use exa_search at least once for semantic discovery.' : ''} Gather all data before writing.` },
    ]
    let toolCalls = 0
    const allSourceUrls: string[] = []

    for (let turn = 0; turn < 6; turn++) {
      const resp = await client.chat.completions.create({ model: DEEPSEEK_MODEL, messages: msgs, tools, temperature: 0.3, max_tokens: 1024 })
      const msg = resp.choices[0]?.message
      if (!msg || !msg.tool_calls || msg.tool_calls.length === 0) break

      msgs.push({ role: 'assistant', content: msg.content || '', tool_calls: msg.tool_calls.map((tc: any) => ({ id: tc.id, type: 'function', function: { name: tc.function.name, arguments: tc.function.arguments } })) })

      for (const tc of msg.tool_calls) {
        toolCalls++
        let result = 'Error'
        try {
          const args = JSON.parse(tc.function.arguments)
          if (tc.function.name === 'web_search') {
            result = await braveSearch.execute(args as any, { userId: 'radar', supabase: supabase as any })
          } else if (tc.function.name === 'exa_search') {
            result = await exaSearch.execute(args as any, { userId: 'radar', supabase: supabase as any })
          } else if (tc.function.name === 'get_stock_price') {
            result = await getStockPrice.execute(args as any, { userId: 'radar', supabase: supabase as any })
          } else if (tc.function.name === 'quiver_enrich') {
            result = await quiverEnrich.execute(args as any, { userId: 'radar', supabase: supabase as any })
          } else if (tc.function.name === 'sam_gov_search') {
            result = await samGovSearch.execute(args as any, { userId: 'radar', supabase: supabase as any })
          }
          // Collect URLs from search results
          if (tc.function.name === 'web_search' || tc.function.name === 'exa_search') {
            try {
              const parsed = JSON.parse(result)
              if (Array.isArray(parsed)) {
                parsed.forEach((r: any) => { if (r.url) allSourceUrls.push(r.url) })
              }
            } catch {}
          }
        } catch (e) { result = `Error: ${e instanceof Error ? e.message : String(e)}` }
        msgs.push({ role: 'tool', tool_call_id: tc.id, content: result.slice(0, 5000) })
      }
    }

    // PHASE 2 — Synthesize
    msgs.push({ role: 'user', content: 'Write the complete dossier NOW. Include price, detection lane, bull case (3 bullets), bear case (3 bullets), verdict paragraph, and JSON scoring block. Do NOT call tools.' })
    const synth = await client.chat.completions.create({ model: DEEPSEEK_MODEL, messages: msgs, temperature: 0.3, max_tokens: 4096 })
    let finalText = synth.choices[0]?.message.content || ''

    console.log(`[radar] ${toolCalls} tool calls, ${finalText.length} chars`)

    const structured = extractJsonBlock(finalText)
    if (!structured) {
      res.status(500).json({ error: 'Failed to extract JSON block', rawText: finalText.slice(0, 3000), toolCalls })
      return
    }

    structured.ticker = ticker; structured.fullReportMd = finalText; structured.price = structured.price || 0

    // ── Fetch enrichment + insider data + themes + peers (before council, so council sees real data) ──
    let enrichment: TickerEnrichment | null = null
    let insiderResult: InsiderResult | null = null
    let peerPositioning: any = null
    let stockDataForValuation: any = null   // reuse getStockData result for valuation assembly
    try {
      ;[enrichment, insiderResult] = await Promise.all([
        fullEnrich(ticker),
        getInsiderData(ticker).catch(() => null),
      ])

      // Add themes after enrichment
      if (enrichment) {
        enrichment.tags = tagThemes(enrichment.ticker)
      }

      // Compute peer positioning using stock data — also keep a reference for valuation assembly
      if (enrichment) {
        try {
          const sd = await getStockData(ticker)
          if (sd) {
            stockDataForValuation = sd
            peerPositioning = await getPeerPositioning(ticker, sd)
          }
          if (peerPositioning) console.log(`[radar] Peer positioning: ${peerPositioning.verdict} (${peerPositioning.percentileRank}th percentile)`)
        } catch (e) {
          console.error('[radar] Peer positioning failed:', e instanceof Error ? e.message : e)
        }
      }

      console.log(`[radar] Enriched: analyst=${!!enrichment.analyst} indicators=${!!enrichment.indicators} inst=${!!enrichment.institutional} catalysts=${enrichment.catalysts.length} headlines=${enrichment.headlines.length} aiSnapshot=${!!enrichment.aiSnapshot} tags=${enrichment?.tags?.length || 0}`)
      if (insiderResult) console.log(`[radar] Insider: ${insiderResult.signal}`)
    } catch (e) {
      console.error(`[radar] Enrichment failed for ${ticker}:`, e instanceof Error ? e.message : e)
    }

    if (enrichment && (enrichment.priceHistory?.length ?? 0) < MIN_CHART_FLOOR) {
      const chart = await ensureChartHistory(ticker)
      if (chart.closes.length >= MIN_CHART_FLOOR) {
        enrichment.priceHistory = chart.closes.map(c => Math.round(c * 100) / 100)
        console.log(`[radar] ${ticker}: patched chart history (${enrichment.priceHistory.length} points)`)
      }
    }

    // Auto-select council mode based on signal strength
    const modeConfig = selectMode(undefined, { score: structured.score, tier: structured.tier, tripleSignal: structured.tripleSignal })
    // council.ts exposes runCouncil(dossier) → { gemini, deepseek, cio }. Map it onto the
    // bull/bear/neutral/summary shape the rest of this route + buildRadarRow expect.
    let councilResult: { bull: CouncilVerdict; bear: CouncilVerdict; neutral: CIOArbiter; summary: string } | null = null
    if (!skipCouncil) {
      try {
        const raw = await runCouncil(finalText)
        councilResult = {
          bull: raw.gemini,
          bear: raw.deepseek,
          neutral: raw.cio,
          summary: raw.cio.synthesis,
        }
        console.log(`[radar] Council: mode=${modeConfig.mode} bull=${councilResult.bull.verdict} bear=${councilResult.bear.verdict} neutral=${councilResult.neutral.verdict} score=${councilResult.neutral.score}`)
      } catch (e) {
        console.error('[radar] Council failed:', e instanceof Error ? e.message : e)
      }
    }

    // ── Fetch macro regime context (cached 24h, non-blocking) ──
    let macroContext = null
    try {
      macroContext = await getMacroContext()
      if (macroContext) {
        console.log(`[radar] macro: regime=${macroContext.macro_regime} defense=${macroContext.defense_spend_trend} flags=${macroContext.regime_flags.join(',') || 'none'}`)
      }
    } catch {}

    // ── Compute composite signal score ──
    const signals = computeSignals(
      enrichment || {},
      insiderResult || {},
      councilResult?.neutral.verdict === 'BULL',
      peerPositioning,
      macroContext,
    )

    let radarV2Shadow = null
    try {
      radarV2Shadow = await runRadarV2Shadow(ticker)
      const first = radarV2Shadow?.results?.[0]
      if (first) {
        console.log(`[radar-v2] shadow ${ticker}: score=${first.radar_score} gate=${first.gate_pass} signals=${first.signals.length}`)
      }
    } catch (e) {
      console.warn('[radar-v2] shadow failed:', e instanceof Error ? e.message : e)
    }

    // ── Asymmetry decay: is the window still open, or has this become consensus? ──
    const asymmetry = evaluateAsymmetry({
      marketCap: enrichment?.marketCap ?? structured.marketCap,
      analystCount: enrichment?.analyst?.count ?? null,
      price: enrichment?.price || structured.price,
      analystTargetMean: enrichment?.analyst?.targetMean ?? null,
      structuredUpsidePct: structured.upside,
      peerPercentileRank: peerPositioning?.percentileRank ?? null,
      rsi: enrichment?.indicators?.rsi.value ?? null,
      priceHistory: enrichment?.priceHistory ?? null,
      compositeScore: signals.composite,
      contrarianScore: signals.contrarian,
      hasUpcomingCatalyst: (enrichment?.catalysts?.length ?? 0) > 0 ? true : undefined,
      researchedAt: new Date().toISOString(),
    })
    console.log(`[radar] ${ticker} asymmetry: ${asymmetry.status} (open=${asymmetry.openScore}/100) — ${asymmetry.reasons[0]}`)

    // ── Confidence scoring ──
    const confidence = computeConfidence(finalText, {
      ...(enrichment ?? {}),
      insider: insiderResult ? {
        totalBuys: insiderResult.totalBuys,
        totalSells: insiderResult.totalSells,
        transactions: insiderResult.transactions,
      } : null,
    })
    const dataFreshness = new Date().toISOString()
    console.log(`[radar] Confidence: ${confidence.score} (${confidence.label}) — ${confidence.factors.join(', ')}`)

    // ── Valuation assembly (DCF + relative: vs peers, sector, market) ────────
    let valuationSnapshot: ValuationSnapshot | null = null
    let wallStreetSnapshot: WallStreetSnapshot | null = null
    try {
      const dcfResult = enrichment?.dcfValuation ?? null
      const dcfBlock: ValuationSnapshot['dcf'] = dcfResult
        ? {
            intrinsic: dcfResult.intrinsicPerShare,
            upsidePct: dcfResult.upsidePct,
            verdict: dcfResult.verdict,
            buyBelow: dcfResult.buyBelow,
            bear: dcfResult.bearValue,
            base: dcfResult.baseValue,
            bull: dcfResult.bullValue,
            growthUsed: dcfResult.growthUsed,
          }
        : null

      // Sector + market positioning — parallel fetches
      const sectorStr = enrichment?.sector ?? structured.sector ?? ''
      const [sectorPos, marketPos] = await Promise.all([
        sectorStr && stockDataForValuation
          ? getSectorPositioning(sectorStr, stockDataForValuation).catch(() => null)
          : Promise.resolve(null),
        stockDataForValuation
          ? getMarketPositioning(stockDataForValuation).catch(() => null)
          : Promise.resolve(null),
      ])

      if (sectorPos) console.log(`[radar] Sector positioning (${sectorStr}): ${sectorPos.percentile}th pct, medianPs=${sectorPos.medianPs.toFixed(1)}x`)
      if (marketPos) console.log(`[radar] Market positioning: ${marketPos.percentile}th pct, medianPe=${marketPos.medianPe.toFixed(1)}x`)

      // Composite verdict rule
      const peerVerdict = peerPositioning?.verdict ?? null
      let composite: ValuationSnapshot['composite_verdict'] = 'fair'
      if (
        dcfBlock?.verdict === 'undervalued' ||
        (peerVerdict === 'cheap_growth' && sectorPos && sectorPos.percentile < 40)
      ) {
        composite = 'undervalued'
      } else if (
        dcfBlock?.verdict === 'overvalued' ||
        ((peerVerdict === 'expensive' || peerVerdict === 'value_trap') && sectorPos && sectorPos.percentile > 70)
      ) {
        composite = 'overvalued'
      }

      valuationSnapshot = {
        dcf: dcfBlock,
        relative: {
          vs_peers: peerPositioning
            ? { percentile: peerPositioning.percentileRank, verdict: peerPositioning.verdict }
            : null,
          vs_sector: sectorPos
            ? { percentile: sectorPos.percentile, medianPs: sectorPos.medianPs, medianEvEbitda: sectorPos.medianEvEbitda }
            : null,
          vs_market: marketPos
            ? { percentile: marketPos.percentile, medianPe: marketPos.medianPe }
            : null,
        },
        composite_verdict: composite,
      }
      console.log(`[radar] Valuation snapshot: composite=${composite} dcf=${dcfBlock?.verdict ?? 'n/a'}`)
    } catch (e) {
      console.error('[radar] Valuation assembly failed:', e instanceof Error ? e.message : e)
    }

    // ── Wall Street analyst — independent of CIO, reads dossier directly ─────
    // Rate-limit stagger (matches the existing 2-3s pattern between council calls)
    await new Promise(r => setTimeout(r, 3000))
    try {
      const wsAnalysis = await runWallStreet(finalText, valuationSnapshot)
      wallStreetSnapshot = {
        moat_score: wsAnalysis.moatScore,
        upside_score: wsAnalysis.upsideScore,
        market_condition_score: wsAnalysis.marketConditionScore,
        comp_adv_score: wsAnalysis.compAdvScore,
        moat_rationale: wsAnalysis.moatRationale,
        upside_rationale: wsAnalysis.upsideRationale,
        market_condition_rationale: wsAnalysis.marketConditionRationale,
        comp_adv_rationale: wsAnalysis.compAdvRationale,
        thesis: wsAnalysis.thesis,
      }
      console.log(`[radar] Wall Street: moat=${wsAnalysis.moatScore} upside=${wsAnalysis.upsideScore} mktCond=${wsAnalysis.marketConditionScore} compAdv=${wsAnalysis.compAdvScore}`)
    } catch (e) {
      console.error('[radar] Wall Street analyst failed:', e instanceof Error ? e.message : e)
    }

    // Build the thesis-level source list BEFORE persisting so it lands in data_snapshot.
    // (Previously this ran AFTER the insert and was only returned in the HTTP response —
    //  so data_snapshot.sources was empty on every row. "A signal needs a link.")
    const webSources = extractSourcesFromText(finalText + ' ' + allSourceUrls.join(' '))
    const quiverSourceUrls = enrichment?.quiver ? formatSources(enrichment.quiver).map(s => ({ label: s.label, url: s.url })) : []
    const headlineUrls = (enrichment?.headlines || []).map(h => ({ label: h.headline.slice(0, 80), url: h.url }))
    const seenUrls = new Set(webSources.map(s => s.url))
    const allSources = [
      ...webSources,
      ...quiverSourceUrls.filter(s => !seenUrls.has(s.url)),
      ...headlineUrls.filter(s => !seenUrls.has(s.url)),
    ]
    const sourcePairs: string[][] = allSources.map(s => [s.label, s.url])

    const row = buildRadarRow(
      structured,
      councilResult?.bull ?? { verdict: 'BULL', reasoning: '' },
      councilResult?.bear ?? { verdict: 'BEAR', reasoning: '' },
      councilResult?.neutral ?? { verdict: 'BULL', synthesis: '', tier: structured.tier, score: structured.score, tripleSignal: structured.tripleSignal, asymmetry: 0, conviction: 0, catalyst: 0, management: 0, asymmetryRationale: '', convictionRationale: '', catalystRationale: '', managementRationale: '', consensus_risk: false },
      enrichment ? {
        priceHistory: enrichment.priceHistory,
        rsiValue: enrichment.indicators?.rsi.value,
        rsiSignal: enrichment.indicators?.rsi.signal,
        macdTrend: enrichment.indicators?.macd.trend,
        volumeRatio: enrichment.indicators?.volume.ratio,
        supportLevel: enrichment.indicators?.bollinger.lower,
        resistanceLevel: enrichment.indicators?.bollinger.upper,
        recentHeadlines: (enrichment.headlines || []).map(h => [h.headline, h.url, h.date, h.source]),
        upcomingEvents: (enrichment.catalysts || []).map(c => [c.date || '', c.label, c.detail, c.type]),
        analystConsensusString: enrichment.analyst?.consensus || '',
        analystCount: enrichment.analyst?.count || 0,
        avgPriceTarget: enrichment.analyst?.targetMean || 0,
        recentAnalystActions: [],
        councilSummary: councilResult?.summary || '',
        sources: sourcePairs,
        // Real key-metrics from Yahoo (stockDataForValuation) — populates P/S, P/FCF, rev growth, short %
        keyMetricsPsTtm: stockDataForValuation?.ps_ttm != null ? `${stockDataForValuation.ps_ttm.toFixed(1)}x` : '',
        keyMetricsPfcf: stockDataForValuation?.pfcf != null ? `${stockDataForValuation.pfcf.toFixed(1)}x` : '',
        keyMetricsRevGrowth: stockDataForValuation?.rev_growth_yoy != null ? `${stockDataForValuation.rev_growth_yoy.toFixed(1)}%` : '',
        keyMetricsShortPct: stockDataForValuation?.short_pct != null ? `${stockDataForValuation.short_pct.toFixed(1)}%` : '',
        // Insider data
        insiderTotalBuys: insiderResult?.totalBuys ?? 0,
        insiderTotalSells: insiderResult?.totalSells ?? 0,
        insiderBuyVolume: insiderResult?.buyVolume ?? 0,
        insiderSellVolume: insiderResult?.sellVolume ?? 0,
        insiderBuyingNames: insiderResult?.buyingInsiders ?? [],
        insiderSellingNames: insiderResult?.sellingInsiders ?? [],
        insiderClusterScore: insiderResult?.clusterScore ?? 0,
        insiderNetSentiment: insiderResult?.netInsiderSentiment ?? '',
        insiderSignal: insiderResult?.signal ?? '',
        insiderTransactions: (insiderResult?.transactions ?? []).slice(0, 10).map(t => [
          t.insiderName, t.relationship, t.transactionType,
          String(t.shares), t.pricePerShare ? `$${t.pricePerShare.toFixed(2)}` : '',
          t.filingDate, t.transactionDate || '',
        ]),
        // New fundamental quality signals
        revAcceleration: enrichment.revAcceleration,
        insiderPct: enrichment.insiderPct,
        gaapQualityScore: enrichment.gaapQualityScore,
        earningsMissCount: enrichment.earningsMissCount,
        tags: enrichment.tags,
        peerPercentileRank: peerPositioning?.percentileRank,
        peerVerdict: peerPositioning?.verdict,
        peerComparison: peerPositioning?.table,
        valuation: valuationSnapshot ?? undefined,
        wallStreet: wallStreetSnapshot ?? undefined,
        contrarian: signals.contrarian,
        smartMoneyScore: Math.round(signals.smartMoney / 10),        // 0–100 → 1–10
        governmentScore: Math.round(signals.government / 10),        // 0–100 → 1–10
        smartMoneySignal: signals.signals.filter(s => s.includes('Insider') || s.includes('insider') || s.includes('Institution') || s.includes('Congress')).slice(0, 3).join(' | ') || '',
        governmentSignal: signals.signals.filter(s => s.includes('contract') || s.includes('government') || s.includes('regulatory') || s.includes('Sector') || s.includes('Regulatory')).slice(0, 3).join(' | ') || '',
        // SEC analysis
        secManagementChanges: enrichment.secAnalysis?.managementChanges?.map(m => `${m.name} as ${m.role}`) ?? [],
        secMaterialContracts: enrichment.secAnalysis?.materialContracts?.map(c => c.description) ?? [],
        secRiskRemovals: enrichment.secAnalysis?.riskFactorDeltas ?? [],
        // Job postings
        jobAcceleration: enrichment.jobAcceleration?.acceleration ?? null,
        jobPostingCount: enrichment.jobAcceleration?.postingCount ?? 0,
        // Transcript sentiment
        transcriptSentimentScore: enrichment.transcriptSentiment?.sentimentScore ?? null,
        transcriptConfidence: enrichment.transcriptSentiment?.confidenceLevel ?? 0,
        // Short reports
        shortReportFound: (enrichment.shortReports ?? []).length > 0,
        shortThesisContradicted: (enrichment.shortReports ?? []).length > 0 && (insiderResult?.clusterScore ?? 0) >= 7 && (enrichment.patentAcceleration?.acceleration ?? 0) > 0,
        // ── Phase 2 signal expansion ──
        analystRevisionsMomentum: enrichment.analystRevisions?.revisionMomentum ?? null,
        analystRevisionsUp: enrichment.analystRevisions?.revisionsUp,
        analystRevisionsDown: enrichment.analystRevisions?.revisionsDown,
        shortSqueezePct: enrichment.squeezeAnalysis?.shortSqueezePct ?? null,
        daysToCover: enrichment.squeezeAnalysis?.daysToCover ?? null,
        floatPct: enrichment.squeezeAnalysis?.floatPct ?? null,
        buybackActive: enrichment.buybackAnalysis?.buybackActive,
        sharesChangePct: enrichment.buybackAnalysis?.sharesChangePct ?? null,
        sharesRepurchasedPct: enrichment.buybackAnalysis?.sharesRepurchasedPct,
        dividendInitiated: enrichment.dividendSignal?.dividendInitiated,
        dividendYieldPct: enrichment.dividendSignal?.yieldPct ?? null,
        payoutRatio: enrichment.dividendSignal?.payoutRatio ?? null,
        redditMentionVelocity: enrichment.socialSentiment?.mentionVelocity ?? null,
        redditSentiment: enrichment.socialSentiment?.sentiment,
        impliedVol: enrichment.optionsSignal?.impliedVol ?? null,
        ivExpansionPct: enrichment.optionsSignal?.ivExpansion ?? null,
        putCallRatio: enrichment.optionsSignal?.putCallRatio ?? null,
        form3NewInsiders: insiderResult?.form3Insiders ?? [],
        form5UnreportedVolume: insiderResult?.form5UnreportedVolume ?? 0,
        peerBeatsCount: enrichment.peerEarnings?.peerBeatsCount,
        peerMissesCount: enrichment.peerEarnings?.peerMissesCount,
        sectorMomentum: enrichment.peerEarnings?.sectorMomentum ?? null,
        boardChanges: enrichment.secAnalysis?.boardChanges,
        debtMaturitiesNext12M: enrichment.secAnalysis?.debtMaturitiesNext12M ?? null,
        refinancingRisk: enrichment.secAnalysis?.refinancingRisk,
        // ── Asymmetry decay / window status ──
        windowStatus: asymmetry.status,
        asymmetryOpenScore: asymmetry.openScore,
        asymmetryDecayReasons: asymmetry.reasons,
        expiresAt: asymmetry.expiresAt,
        radarV2Shadow,
      } : {
        // Even without enrichment, record the window status + sources.
        sources: sourcePairs,
        windowStatus: asymmetry.status,
        asymmetryOpenScore: asymmetry.openScore,
        asymmetryDecayReasons: asymmetry.reasons,
        expiresAt: asymmetry.expiresAt,
        radarV2Shadow,
      },
    )

    // Persist confidence into the data_snapshot jsonb — these are NOT top-level
    // columns on radar_opportunities, so writing them at the top level makes the
    // entire insert fail ("Could not find the 'confidence_label' column").
    ;(row.data_snapshot as any).confidence_score = confidence.score
    ;(row.data_snapshot as any).confidence_label = confidence.label
    ;(row.data_snapshot as any).data_freshness = dataFreshness

    let persisted = false
    const chartLen = enrichment?.priceHistory?.length ?? 0
    const chartGateFailed = chartLen < MIN_CHART_FLOOR
    if (!skipPersist && supabase) {
      // Delete existing entries for this ticker (prevents duplicates + prunes if now closed)
      await supabase.from('radar_opportunities').delete().eq('ticker', ticker)
      if (chartGateFailed) {
        console.warn(`[radar] ${ticker}: skipping persist — chart history too short (${chartLen} points)`)
      } else if (asymmetry.status === 'closed') {
        // Window has closed — do NOT keep a consensus / fully-valued name on the active radar.
        console.log(`[radar] ${ticker} window CLOSED — pruned from active radar: ${asymmetry.reasons.join('; ')}`)
      } else {
        // Insert fresh
        const { error } = await supabase.from('radar_opportunities').insert(row as any)
        if (error) { res.status(500).json({ error: 'Supabase write failed', detail: error.message }); return }
        persisted = true
        // APNs device push for qualifying Tier 1/2 discoveries (non-blocking; no-ops if APNs env unset).
        // notifyIfQualifying applies the full notify policy internally (Tier 1 always; Tier 2 if catalyst>=8 or all dims>=7).
        notifyIfQualifying(row).catch(e => console.warn('[radar] APNs push failed:', e))
        // Existing ntfy channel — Fire push notifications for Tier 1/2 discoveries (non-blocking)
        if (row.tier <= 2) {
          import('./notify').then(m => m.dispatchNotifications({
            ticker,
            score: row.overall_score ?? 0,
            tier: row.tier,
          })).catch(e => console.warn('[radar] notify dispatch failed:', e))
        }
        // Match against user theses — all tiers; per-thesis notify prefs gate pushes (non-blocking)
        import('./thesis').then(m => m.checkThesisMatches({
          ticker,
          tier: row.tier,
          score: row.overall_score ?? 0,
          bluf: row.thesis ?? '',
          snapshot: row.data_snapshot as unknown as Record<string, unknown>,
        })).catch(e => console.warn('[radar] thesis check failed:', e))
      }
    }

    res.json({
      ticker, tier: row.tier, score: row.overall_score,
      confidenceScore: confidence.score,
      confidenceLabel: confidence.label,
      dataFreshness,
      tripleSignal: row.data_snapshot.triple_signal,
      // ── Asymmetry window status ──
      windowStatus: asymmetry.status,
      asymmetry: {
        status: asymmetry.status,
        openScore: asymmetry.openScore,
        reasons: asymmetry.reasons,
        expiresAt: asymmetry.expiresAt,
        prunedFromRadar: asymmetry.status === 'closed',
      },
      council: councilResult ? {
        bull: councilResult.bull.verdict,
        bear: councilResult.bear.verdict,
        neutral: councilResult.neutral.verdict,
        summary: councilResult.summary?.slice(0, 600) || '',
      } : row.data_snapshot.council,
      bluf: row.thesis,
      persisted, toolCalls, dossierLength: finalText.length,
      dossierMd: finalText.slice(0, 8000),
      sources: allSources,
      // Price data from enrichment (or fallback to structured)
      price: enrichment?.price || structured.price,
      changePct: enrichment?.changePct || 0,
      marketCap: enrichment?.marketCap || structured.marketCap,

      // ── Composite signal score ──
      signals,
      radarV2Shadow,

      // ── Comprehensive enrichment ──
      analyst: enrichment?.analyst || null,
      indicators: enrichment?.indicators || null,
      institutional: enrichment?.institutional || [],
      catalysts: enrichment?.catalysts || [],
      headlines: enrichment?.headlines || [],
      priceHistory: enrichment?.priceHistory || [],
      aiSnapshot: enrichment?.aiSnapshot || null,
      buyLevels: enrichment?.buyLevels || null,
      insider: insiderResult ? {
        totalBuys: insiderResult.totalBuys,
        totalSells: insiderResult.totalSells,
        buyVolume: insiderResult.buyVolume,
        sellVolume: insiderResult.sellVolume,
        buyingInsiders: insiderResult.buyingInsiders,
        sellingInsiders: insiderResult.sellingInsiders,
        clusterScore: insiderResult.clusterScore,
        netInsiderSentiment: insiderResult.netInsiderSentiment,
        signal: insiderResult.signal,
        transactions: insiderResult.transactions.slice(0, 10),
      } : null,

      quiver: enrichment?.quiver ? {
        congressTrades: enrichment.quiver.congressTrades?.slice(0, 8).map(t => ({
          date: t.TransactionDate || '', transaction: t.Transaction || '',
          representative: t.Representative || '', party: t.Party || '',
          range: t.Range || '', house: t.House || '',
        })) || [],
        govContracts: enrichment.quiver.govContracts?.slice(0, 5).map(c => ({
          date: c.Date || '', description: c.Description?.slice(0, 200) || '',
          agency: c.Agency || '', amount: c.Amount || 0,
        })) || [],
        sentiment: enrichment.quiver.tickerData ? {
          wsbMentions: enrichment.quiver.tickerData.wsbMentionsWeekly,
          congressBought: enrichment.quiver.tickerData.congressBought,
          congressSold: enrichment.quiver.tickerData.congressSold,
        } : null,
      } : null,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[radar] Error:', message)
    res.status(500).json({ error: message })
  }
})

export default router
