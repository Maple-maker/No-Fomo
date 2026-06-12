import { Router, type Request, type Response } from 'express'
import { getDeepSeekClient, callClaude, callGemini, getDeepSeekModel } from '../agents/client'
import type { CouncilVerdict, CIOArbiter } from '../agents/types'

const router = Router()

const COUNCIL_RULES = `
## Rules
- Verdict is BULL or BEAR only. No neutral. If you are uncertain, pick the side you lean toward and explain why.
- Your reasoning must cite specific facts from the dossier — do not summarize, judge.
- Be willing to dissent. If the dossier is too optimistic, say BEAR with conviction. If it is too pessimistic, say BULL.
- Output ONLY valid JSON — no markdown, no preamble.`

const BULL_ANALYST_PROMPT = `You are a long-only optimistic analyst. Build the strongest bull case based on the evidence. You are an independent equity analyst on the NoFomo AI Council. Your job: read a radar research dossier and deliver a verdict.${COUNCIL_RULES}`

const BEAR_ANALYST_PROMPT = `You are a forensic short-seller. Dismantle this thesis and find what the bulls are missing. You are an independent equity analyst on the NoFomo AI Council. Your job: read a radar research dossier and deliver a verdict.${COUNCIL_RULES}`

const CIO_PROMPT = `You are the Chief Investment Officer (CIO) of the NoFomo AI Council. Two independent analysts — Gemini and DeepSeek — have each delivered a verdict on a company. Your job: weigh both perspectives, break the tie if they disagree, and produce the final scored opportunity.

## Rules
- Your verdict is BULL or BEAR only. No neutral.
- Synthesize the best insights from BOTH analysts into your reasoning.
- Score the opportunity honestly. Tier 1 = exceptional (10x+ potential, asymmetric, near-term catalyst). Tier 2 = high conviction. Tier 3 = watchlist.
- tripleSignal is true ONLY when the opportunity has: 1) evidence of insider buying, 2) a catalyst within 6 months, AND 3) score ≥ 80.
- Output ONLY valid JSON — no markdown, no preamble.`

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
  "tripleSignal": true | false
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

function parseCIO(text: string): CIOArbiter {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0])
      return {
        verdict: parsed.verdict?.toUpperCase() === 'BEAR' ? 'BEAR' : 'BULL',
        synthesis: parsed.synthesis ?? text.slice(0, 500),
        tier: typeof parsed.tier === 'number' && [1, 2, 3].includes(parsed.tier) ? parsed.tier : 2,
        score: typeof parsed.score === 'number' ? Math.min(100, Math.max(0, parsed.score)) : 50,
        tripleSignal: parsed.tripleSignal === true,
      }
    }
  } catch {
    // Fall through
  }

  return { verdict: 'BULL', synthesis: text.slice(0, 500), tier: 2, score: 50, tripleSignal: false }
}

export default router