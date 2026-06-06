import { Router, type Request, type Response } from 'express'
import { getDeepSeekClient, callClaude, callGemini, getDeepSeekModel } from '../agents/client'
import type { CouncilVerdict, CIOArbiter } from '../agents/types'

const router = Router()

const COUNCIL_PROMPT = `You are an independent equity analyst on the NoFomo AI Council. Your job: read a radar research dossier and deliver a verdict.

## Rules
- Verdict is BULL or BEAR only. No neutral. If you are uncertain, pick the side you lean toward and explain why.
- Your reasoning must cite specific facts from the dossier — do not summarize, judge.
- Be willing to dissent. If the dossier is too optimistic, say BEAR with conviction. If it is too pessimistic, say BULL.
- Output ONLY valid JSON — no markdown, no preamble.`

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

export async function runCouncil(dossier: string): Promise<{
  gemini: CouncilVerdict
  deepseek: CouncilVerdict
  cio: CIOArbiter
}> {
  const truncatedDossier = dossier.slice(0, 12000)

  const userPrompt = `Here is the radar research dossier:\n\n${truncatedDossier}\n\nDeliver your verdict as JSON: {"verdict": "BULL" | "BEAR", "reasoning": "..."}`

  // Run Gemini and DeepSeek sequentially (free tier ~1 RPM rate limit)
  const geminiResult = await callGemini(COUNCIL_PROMPT, userPrompt).then(parseVerdict)
  console.log(`[council] Gemini: ${geminiResult.verdict}`)

  // Rate limit gap for free tier (~1 RPM)
  await new Promise(r => setTimeout(r, 2000))

  const deepseekResult = await callDeepSeek(COUNCIL_PROMPT, userPrompt)
  console.log(`[council] DeepSeek: ${deepseekResult.verdict}`)

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

  return {
    gemini: geminiResult,
    deepseek: deepseekResult,
    cio: cioResult,
  }
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