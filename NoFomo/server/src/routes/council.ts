import { Router, type Request, type Response } from 'express'
import { getDeepSeekClient, callClaude, callGemini, getDeepSeekModel } from '../agents/client'
import type { CouncilVerdict, CIOArbiter, WallStreetAnalysis } from '../agents/types'
import type { ValuationSnapshot } from '../lib/opportunity'
import { parseJsonBlock } from '../lib/opportunity'

const router = Router()

const COUNCIL_RULES = `
## Rules
- Verdict is BULL or BEAR only. No neutral. If you are uncertain, pick the side you lean toward and explain why.
- Cite ≥ 3 specific data points from the dossier — actual numbers, filings, contracts, dates. Not "fundamentals look good."
- Be willing to dissent. If the dossier is too optimistic, say BEAR with conviction. If it is too pessimistic, say BULL.
- Output ONLY valid JSON — no markdown, no preamble.`

const BULL_ANALYST_PROMPT = `You are a long-only optimistic analyst. Build the strongest bull case based on the evidence. You are an independent equity analyst on the NoFomo AI Council. Your job: read a radar research dossier and deliver a verdict.${COUNCIL_RULES}
- Before concluding BULL, name the single biggest risk that could break this thesis.
- State the catalyst timeline in weeks (e.g. "8 weeks"), not vague quarters.`

const BEAR_ANALYST_PROMPT = `You are a forensic short-seller. Dismantle this thesis and find what the bulls are missing. You are an independent equity analyst on the NoFomo AI Council. Your job: read a radar research dossier and deliver a verdict.${COUNCIL_RULES}
- Assume the bull thesis is correct — then find exactly where it breaks.
- Distinguish: "structural bear" (thesis is fundamentally wrong) vs "timing bear" (right idea, too early).
- Rate downside severity: contained (-20 to -40%) | severe (-50%+) | wipeout.`

const DIMENSION_SCORING_GUIDE = `
## Dimension Scoring Guide
- asymmetry (1-10): How lopsided is upside vs downside? 10 = 10x+ upside with ≤20% max downside.
- conviction (1-10): How strong and verifiable is the evidence? 10 = confirmed by 3+ independent primary sources.
- catalyst (1-10): How binary, near-term, and high-impact? 10 = definite event within 3 months that reprices the stock.
- management (1-10): How aligned and capable is leadership? 10 = founder-led, heavy insider ownership, proven execution.`

const CIO_PROMPT = `You are the Chief Investment Officer (CIO) of the NoFomo AI Council. Two independent analysts — Gemini and DeepSeek — have each delivered a verdict on a company. Your job: weigh both perspectives, break the tie if they disagree, and produce the final scored opportunity.

## Rules
- Your verdict is BULL or BEAR only. No neutral.
- Synthesize the best insights from BOTH analysts into your reasoning. Weigh which analyst cited harder evidence, not just which side is right.
- Score the opportunity honestly. Tier 1 = exceptional (10x+ potential, asymmetric, near-term catalyst). Tier 2 = high conviction. Tier 3 = watchlist.
- tripleSignal is true ONLY when: 1) evidence of insider buying, 2) catalyst within 6 months, AND 3) score ≥ 80. Cannot be true when consensus_risk is true.
- Consensus bias check: if both analysts reached the same verdict with similar reasoning, the market may already know what they know. Set consensus_risk: true and lower your score by 10.
- Output ONLY valid JSON — no markdown, no preamble.
${DIMENSION_SCORING_GUIDE}`

// Standalone endpoint to run just the council on a dossier
router.post('/', async (req: Request, res: Response) => {
  const dossier = req.body.dossier as string
  if (!dossier) {
    res.status(400).json({ error: 'Dossier text required' })
    return
  }

  try {
    const result = await runCouncil(dossier)
    res.json(result)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[council] Error:', message)
    res.status(500).json({ error: message })
  }
})

function jaccardSimilarity(a: string, b: string): number {
  const tokA = new Set(a.toLowerCase().split(/\W+/).filter(Boolean))
  const tokB = new Set(b.toLowerCase().split(/\W+/).filter(Boolean))
  const intersection = [...tokA].filter(t => tokB.has(t)).length
  const union = new Set([...tokA, ...tokB]).size
  return union === 0 ? 0 : intersection / union
}

export async function runCouncil(dossier: string): Promise<{
  gemini: CouncilVerdict
  deepseek: CouncilVerdict
  cio: CIOArbiter
  low_diversity?: true
}> {
  const truncatedDossier = dossier.slice(0, 12000)

  const userPrompt = `Here is the radar research dossier:\n\n${truncatedDossier}\n\nDeliver your verdict as JSON: {"verdict": "BULL" | "BEAR", "reasoning": "..."}`

  // Gemini is the BEAR analyst; DeepSeek is the BULL analyst
  const geminiResult = await callGemini(BEAR_ANALYST_PROMPT, userPrompt).then(parseVerdict)
  console.log(`[council] Gemini (bear lens): ${geminiResult.verdict}`)

  // 3-second stagger between AnyAPI calls to avoid rate limits
  const staggerMs = process.env.ANYAPI_API_KEY ? 3000 : 2000
  await new Promise(r => setTimeout(r, staggerMs))

  const deepseekResult = await callDeepSeek(BULL_ANALYST_PROMPT, userPrompt)
  console.log(`[council] DeepSeek (bull lens): ${deepseekResult.verdict}`)

  // CIO arbiter — Claude reads both verdicts
  const cioUserPrompt = `## Radar Dossier
${truncatedDossier}

## Analyst Verdicts

**Gemini**: ${geminiResult.verdict}
> ${geminiResult.reasoning}

**DeepSeek**: ${deepseekResult.verdict}
> ${deepseekResult.reasoning}

Deliver your final CIO verdict as JSON:
{
  "verdict": "BULL" | "BEAR",
  "synthesis": "Weigh both analysts and give your final reasoning...",
  "tier": 1 | 2 | 3,
  "score": 0-100,
  "tripleSignal": true | false,
  "consensus_risk": true | false,
  "asymmetry": 1-10,
  "conviction": 1-10,
  "catalyst": 1-10,
  "management": 1-10,
  "asymmetryRationale": "one-line reason for the asymmetry score",
  "convictionRationale": "one-line reason for the conviction score",
  "catalystRationale": "one-line reason for the catalyst score",
  "managementRationale": "one-line reason for the management score"
}`

  const cioText = await callClaude(CIO_PROMPT, cioUserPrompt)
  const cioResult = parseCIO(cioText)
  console.log(`[council] CIO: ${cioResult.verdict}, Tier ${cioResult.tier}, Score ${cioResult.score}`)

  const result: { gemini: CouncilVerdict; deepseek: CouncilVerdict; cio: CIOArbiter; low_diversity?: true } = {
    gemini: geminiResult,
    deepseek: deepseekResult,
    cio: cioResult,
  }

  if (
    geminiResult.verdict === deepseekResult.verdict &&
    jaccardSimilarity(geminiResult.reasoning, deepseekResult.reasoning) > 0.4
  ) {
    result.low_diversity = true
    console.log('[council] Low diversity detected — both analysts agreed with similar reasoning')
  }

  return result
}

async function callDeepSeek(systemPrompt: string, userPrompt: string): Promise<CouncilVerdict> {
  // Retry with backoff for rate limits (free tier ~1 RPM)
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      const wait = 5000 * Math.pow(2, attempt - 1)
      console.log(`[council] DeepSeek retry ${attempt + 1} after ${wait}ms`)
      await new Promise(r => setTimeout(r, wait))
    }
    try {
      const client = getDeepSeekClient()
      const response = await client.chat.completions.create({
        model: getDeepSeekModel(),
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.3,
        max_tokens: 1024,
      })
      const text = response.choices[0]?.message.content || ''
      return parseVerdict(text)
    } catch (err: any) {
      const isRateLimit = err?.status === 429 || err?.message?.includes('429')
      if (isRateLimit && attempt < 2) {
        console.error(`[council] DeepSeek rate limited (attempt ${attempt + 1})`)
        continue
      }
      console.error('[council] DeepSeek error:', err)
      return { verdict: 'BEAR', reasoning: 'DeepSeek API error — defaulting to BEAR.' }
    }
  }
  return { verdict: 'BEAR', reasoning: 'DeepSeek exhausted retries.' }
}

function parseVerdict(text: string): CouncilVerdict {
  try {
    // Try to extract JSON from the response
    const jsonMatch = text.match(/\{[\s\S]*"verdict"[\s\S]*\}/)
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0])
      return {
        verdict: parsed.verdict?.toUpperCase() === 'BEAR' ? 'BEAR' : 'BULL',
        reasoning: parsed.reasoning ?? text.slice(0, 500),
      }
    }
  } catch {
    // Fall through
  }

  // Heuristic fallback
  const upper = text.toUpperCase()
  const verdict: 'BULL' | 'BEAR' = upper.includes('BEAR') && !upper.includes('BULL') ? 'BEAR' : 'BULL'
  return { verdict, reasoning: text.slice(0, 500) }
}

function clampDimension(v: unknown): number | undefined {
  if (typeof v !== 'number') return undefined
  return Math.min(10, Math.max(1, Math.round(v)))
}

export function parseCIO(text: string): CIOArbiter {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0])
      const consensusRisk = parsed.consensus_risk === true
      return {
        verdict: parsed.verdict?.toUpperCase() === 'BEAR' ? 'BEAR' : 'BULL',
        synthesis: parsed.synthesis ?? text.slice(0, 500),
        tier: typeof parsed.tier === 'number' && [1, 2, 3].includes(parsed.tier) ? parsed.tier : 2,
        score: typeof parsed.score === 'number' ? Math.min(100, Math.max(0, parsed.score)) : 0,
        tripleSignal: parsed.tripleSignal === true && !consensusRisk,
        consensus_risk: consensusRisk,
        asymmetry: clampDimension(parsed.asymmetry),
        conviction: clampDimension(parsed.conviction),
        catalyst: clampDimension(parsed.catalyst),
        management: clampDimension(parsed.management),
        asymmetryRationale: typeof parsed.asymmetryRationale === 'string' ? parsed.asymmetryRationale : undefined,
        convictionRationale: typeof parsed.convictionRationale === 'string' ? parsed.convictionRationale : undefined,
        catalystRationale: typeof parsed.catalystRationale === 'string' ? parsed.catalystRationale : undefined,
        managementRationale: typeof parsed.managementRationale === 'string' ? parsed.managementRationale : undefined,
      }
    }
  } catch {
    // Fall through
  }

  return { verdict: 'BULL', synthesis: text.slice(0, 500), tier: 2, score: 0, tripleSignal: false }
}

// ── Wall Street Analyst ──────────────────────────────────────────────────────
// Reads the same dossier as the CIO (independence — no anchoring on CIO output).
// Scores MOAT, UPSIDE, MARKET CONDITIONS, COMP ADVANTAGE each 1-10.
// Inherits CIO_MODEL override → no new model cost.

const WALL_STREET_PROMPT = `You are a sharp sell-side equity analyst producing institutional-grade research. Your job: read a radar dossier and score the opportunity on four dimensions, then write a one-paragraph investment thesis.

## Scoring Dimensions (each 1-10, integer, grounded in the provided valuation numbers)
- **moatScore**: Durability of competitive moat. 10 = sole-source contracts, proprietary data flywheel, or switching costs rivals cannot replicate in 3-5y. 1 = fully commoditized with no differentiation.
- **upsideScore**: Conviction on upside potential, calibrated to the valuation. 10 = DCF intrinsic >50% above price with multiple confirming signals. 1 = fully priced or negative FCF.
- **marketConditionScore**: Favorability of the current macro/sector backdrop. 10 = strong tailwinds, expanding multiples, sector in discovery phase. 1 = severe headwinds, multiple compression.
- **compAdvScore**: Competitive advantage vs. direct peers. 10 = dominant market share, best-in-class margins, pricing power. 1 = losing share, margin below peers.

## Rules
- Ground every score in the specific numbers in the dossier and valuation block — cite actual figures (P/S, DCF upside %, peer percentile) in your rationales.
- Each rationale is one crisp sentence. No hedge words. Call it as you see it.
- thesis: one paragraph synthesizing the investment case — lead with the valuation anchor, name the catalyst, acknowledge the bear case.
- Output ONLY valid JSON. No markdown, no preamble, no trailing text.
- Output keys exactly: moatScore, upsideScore, marketConditionScore, compAdvScore, moatRationale, upsideRationale, marketConditionRationale, compAdvRationale, thesis.`

/** Clamp a score to integer 1-10; return 0 (fallback sentinel) if value is not a valid number. */
function clampWsScore(v: unknown): number {
  if (typeof v !== 'number' || !isFinite(v)) return 0
  return Math.min(10, Math.max(1, Math.round(v)))
}

/** Parse the Wall Street analyst's JSON output, clamping scores and falling back on parse failure. */
export function parseWallStreet(text: string): WallStreetAnalysis {
  const fallback: WallStreetAnalysis = {
    moatScore: 0, upsideScore: 0, marketConditionScore: 0, compAdvScore: 0,
    moatRationale: '', upsideRationale: '', marketConditionRationale: '', compAdvRationale: '',
    thesis: '',
  }

  try {
    const parsed = parseJsonBlock(text)
    if (!parsed) return fallback
    return {
      moatScore:             clampWsScore(parsed.moatScore),
      upsideScore:           clampWsScore(parsed.upsideScore),
      marketConditionScore:  clampWsScore(parsed.marketConditionScore),
      compAdvScore:          clampWsScore(parsed.compAdvScore),
      moatRationale:         typeof parsed.moatRationale === 'string'            ? parsed.moatRationale            : '',
      upsideRationale:       typeof parsed.upsideRationale === 'string'          ? parsed.upsideRationale          : '',
      marketConditionRationale: typeof parsed.marketConditionRationale === 'string' ? parsed.marketConditionRationale : '',
      compAdvRationale:      typeof parsed.compAdvRationale === 'string'          ? parsed.compAdvRationale          : '',
      thesis:                typeof parsed.thesis === 'string'                   ? parsed.thesis                   : '',
    }
  } catch {
    return fallback
  }
}

/**
 * Run the Wall Street analyst on the same dossier the CIO reads.
 * Optionally appends a compact valuation block so the analyst can ground scores in real numbers.
 * Independence: reads the dossier DIRECTLY — does NOT see the CIO's output.
 */
export async function runWallStreet(
  dossier: string,
  valuation: ValuationSnapshot | null,
): Promise<WallStreetAnalysis> {
  const truncatedDossier = dossier.slice(0, 12000)

  // Compact valuation summary — gives the analyst numbers to anchor scores to
  const valuationBlock = valuation ? `

## Valuation Summary (for score grounding)
DCF: ${valuation.dcf ? `intrinsic $${valuation.dcf.intrinsic.toFixed(2)}, upside ${valuation.dcf.upsidePct.toFixed(1)}%, verdict ${valuation.dcf.verdict}, buyBelow $${valuation.dcf.buyBelow.toFixed(2)}` : 'N/A (negative FCF or missing data)'}
vs Peers: ${valuation.relative.vs_peers ? `${valuation.relative.vs_peers.percentile}th percentile, verdict: ${valuation.relative.vs_peers.verdict}` : 'N/A'}
vs Sector: ${valuation.relative.vs_sector ? `${valuation.relative.vs_sector.percentile}th percentile, sector median P/S ${valuation.relative.vs_sector.medianPs.toFixed(1)}x, EV/EBITDA ${valuation.relative.vs_sector.medianEvEbitda.toFixed(1)}x` : 'N/A'}
vs Market: ${valuation.relative.vs_market ? `${valuation.relative.vs_market.percentile}th percentile, broad market median P/E ${valuation.relative.vs_market.medianPe.toFixed(1)}x` : 'N/A'}
Composite: ${valuation.composite_verdict}` : ''

  const userPrompt = `Here is the radar research dossier:

${truncatedDossier}${valuationBlock}

Deliver your Wall Street analyst verdict as JSON with keys: moatScore, upsideScore, marketConditionScore, compAdvScore, moatRationale, upsideRationale, marketConditionRationale, compAdvRationale, thesis.`

  try {
    const raw = await callClaude(WALL_STREET_PROMPT, userPrompt)
    return parseWallStreet(raw)
  } catch (e) {
    console.error('[council] runWallStreet error:', e instanceof Error ? e.message : e)
    return {
      moatScore: 0, upsideScore: 0, marketConditionScore: 0, compAdvScore: 0,
      moatRationale: '', upsideRationale: '', marketConditionRationale: '', compAdvRationale: '',
      thesis: '',
    }
  }
}

export default router