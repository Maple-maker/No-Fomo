// ── Budget Council — cheap pre-filter debate ──
// POST /council/budget
// Two DeepSeek calls argue opposite sides INDEPENDENTLY, then a quick synthesis
// decides whether the idea deserves the full expensive council + radar pipeline.
//
// Independence rule (non-negotiable): bull and bear NEVER see each other's output
// before forming their own view. This prevents anchoring.

import { Router, type Request, type Response } from 'express'
import { getDeepSeekClient, getDeepSeekModel } from '../agents/client'

const router = Router()

// Budget mode — uses 3 sequential DeepSeek calls (parallel bull/bear isn't safe
// on free-tier rate limits).
// Target: < 30s total for the full debate + synthesis.

const BULL_PROMPT = `You are an optimistic, long-only equity analyst. Your job: build the strongest possible bull case for a company based on the provided dossier. Assume every signal is real, every catalyst fires on time, and management executes flawlessly. Be specific — cite numbers and events from the dossier.

Output valid JSON only:
{
  "bullThesis": "2-3 sentence bullish investment thesis citing specific facts",
  "asymmetry": 1-10,
  "conviction": 1-10,
  "catalyst": 1-10,
  "management": 1-10
}

Scoring guide for dimensions:
- asymmetry (1-10): How lopsided is upside vs downside? 10 = 10x+ upside with 20% max downside.
- conviction (1-10): How strong and verifiable is the evidence? 10 = confirmed by 3+ independent sources.
- catalyst (1-10): How binary, near-term, and high-impact is the catalyst? 10 = definite event within 3 months that reprices the stock.
- management (1-10): How aligned and capable is leadership? 10 = founder-led, heavy insider ownership, track record of execution.`

const BEAR_PROMPT = `You are a forensic short-seller. Your job: dismantle the bull case for a company based on the provided dossier. Assume every risk materializes, every competitive threat succeeds, and management is overpromising. Be specific — cite numbers and events from the dossier.

Output valid JSON only:
{
  "topRedFlags": ["Red flag 1 — most severe", "Red flag 2", "Red flag 3"],
  "invalidationTrigger": "The single event or data point that would definitively prove the bull case wrong. Be specific and measurable.",
  "asymmetry": 1-10,
  "conviction": 1-10,
  "catalyst": 1-10,
  "management": 1-10
}

Scoring guide for dimensions:
- asymmetry (1-10): How poor is the risk/reward? 1 = 20%+ downside with capped 20% upside.
- conviction (1-10): How strong is the evidence AGAINST the thesis? 1 = all available evidence points to overvaluation.
- catalyst (1-10): How weak or absent are catalysts? 1 = no identifiable catalyst within 12 months.
- management (1-10): How concerning is leadership? 1 = history of dilution, missed guidance, or self-dealing.`

const SYNTH_PROMPT = `You are a pragmatic portfolio manager synthesizing a bull/bear debate. Two analysts have independently argued opposite sides of a stock. The bull sees opportunity; the bear sees danger. Your job: weigh both, assign a score, and decide.

Rules:
- Do NOT average the scores. If bull and bear sharply disagree, discount both and reason it out.
- Weigh evidence quality over quantity. One hard, verifiable fact beats three optimistic assumptions.
- The invalidation trigger from the bear is the most important line — if that trigger fires, the thesis is dead.

Output valid JSON only:
{
  "score": 0-100,
  "verdict": "advance" | "kill",
  "rationale": "One paragraph explaining your reasoning: what convinced you, what worried you, and why you chose advance or kill.",
  "keyRisk": "The single biggest risk the bull must be right about"
}

Score ≥ 70 is "advance" (deserves full council + radar research). Below 70 is "kill" (add to watchlist at most).

Only output "advance" if the opportunity is genuinely asymmetric with a clear catalyst. Be conservative — it's cheaper to miss a 5x than to waste cycles on 20 ideas that go nowhere.`

interface BudgetCouncilRequest {
  ticker: string
  dossier: string
}

function parseBullJson(text: string): {
  bullThesis: string
  asymmetry: number; conviction: number; catalyst: number; management: number
} {
  try {
    const match = text.match(/\{[\s\S]*\}/)
    if (match) {
      const p = JSON.parse(match[0])
      return {
        bullThesis: p.bullThesis || text.slice(0, 300),
        asymmetry: clamp(p.asymmetry, 1, 10),
        conviction: clamp(p.conviction, 1, 10),
        catalyst: clamp(p.catalyst, 1, 10),
        management: clamp(p.management, 1, 10),
      }
    }
  } catch { /* fall through */ }
  return {
    bullThesis: text.slice(0, 300),
    asymmetry: 5, conviction: 5, catalyst: 5, management: 5,
  }
}

function parseBearJson(text: string): {
  topRedFlags: string[]
  invalidationTrigger: string
  asymmetry: number; conviction: number; catalyst: number; management: number
} {
  try {
    const match = text.match(/\{[\s\S]*\}/)
    if (match) {
      const p = JSON.parse(match[0])
      return {
        topRedFlags: Array.isArray(p.topRedFlags) ? p.topRedFlags.slice(0, 5) : [p.topRedFlags || 'No red flags provided'],
        invalidationTrigger: p.invalidationTrigger || 'No invalidation trigger specified',
        asymmetry: clamp(p.asymmetry, 1, 10),
        conviction: clamp(p.conviction, 1, 10),
        catalyst: clamp(p.catalyst, 1, 10),
        management: clamp(p.management, 1, 10),
      }
    }
  } catch { /* fall through */ }
  return {
    topRedFlags: [text.slice(0, 200)],
    invalidationTrigger: 'Could not parse invalidation trigger',
    asymmetry: 5, conviction: 5, catalyst: 5, management: 5,
  }
}

function parseSynthJson(text: string): {
  score: number; verdict: 'advance' | 'kill'; rationale: string; keyRisk: string
} {
  try {
    const match = text.match(/\{[\s\S]*\}/)
    if (match) {
      const p = JSON.parse(match[0])
      return {
        score: clamp(p.score, 0, 100),
        verdict: p.verdict === 'advance' ? 'advance' : 'kill',
        rationale: p.rationale || text.slice(0, 400),
        keyRisk: p.keyRisk || 'Not specified',
      }
    }
  } catch { /* fall through */ }
  // Fallback: be conservative — kill if unparseable
  return {
    score: 0, verdict: 'kill',
    rationale: 'Synthesis model returned unparseable output. Defaulting to kill for safety.',
    keyRisk: 'Unknown — synthesis failed',
  }
}

function clamp(val: number, min: number, max: number): number {
  const n = typeof val === 'number' ? val : Math.floor((min + max) / 2)
  return Math.max(min, Math.min(max, Math.round(n)))
}

async function runBudgetDebate(client: any, model: string, dossier: string) {
  const truncated = dossier.slice(0, 6000)
  const bullUser = `Here is a dossier on a company:\n\n${truncated}\n\nBuild the strongest possible bull case.`

  // Call 1 — Bull (DeepSeek)
  const bullStart = Date.now()
  const bullResp = await client.chat.completions.create({
    model,
    messages: [
      { role: 'system', content: BULL_PROMPT },
      { role: 'user', content: bullUser },
    ],
    temperature: 0.4,
    max_tokens: 800,
  })
  const bullText = bullResp.choices[0]?.message.content || ''
  const bull = parseBullJson(bullText)
  console.log(`[budgetCouncil] Bull: ${bull.bullThesis.slice(0, 80)}... (${Date.now() - bullStart}ms)`)

  // Rate-limit gap for free tier
  await new Promise(r => setTimeout(r, 1500))

  // Call 2 — Bear (DeepSeek) — sees NOTHING from bull
  const bearStart = Date.now()
  const bearResp = await client.chat.completions.create({
    model,
    messages: [
      { role: 'system', content: BEAR_PROMPT },
      { role: 'user', content: bullUser }, // Same dossier, opposite prompt — INDEPENDENT
    ],
    temperature: 0.4,
    max_tokens: 800,
  })
  const bearText = bearResp.choices[0]?.message.content || ''
  const bear = parseBearJson(bearText)
  console.log(`[budgetCouncil] Bear: ${bear.topRedFlags[0]?.slice(0, 80)}... (${Date.now() - bearStart}ms)`)

  // Rate-limit gap
  await new Promise(r => setTimeout(r, 1500))

  // Call 3 — Synthesis (DeepSeek again, sees BOTH)
  const synthStart = Date.now()
  const synthUser = `## Bull Analyst\n**Thesis:** ${bull.bullThesis}\n**Scores:** asymmetry=${bull.asymmetry} conviction=${bull.conviction} catalyst=${bull.catalyst} management=${bull.management}\n\n## Bear Analyst\n**Red Flags:**\n- ${bear.topRedFlags.join('\n- ')}\n**Invalidation Trigger:** ${bear.invalidationTrigger}\n**Scores:** asymmetry=${bear.asymmetry} conviction=${bear.conviction} catalyst=${bear.catalyst} management=${bear.management}\n\nWeigh both analysts and decide: advance to full research, or kill?`

  const synthResp = await client.chat.completions.create({
    model,
    messages: [
      { role: 'system', content: SYNTH_PROMPT },
      { role: 'user', content: synthUser },
    ],
    temperature: 0.2,
    max_tokens: 600,
  })
  const synthText = synthResp.choices[0]?.message.content || ''
  const synth = parseSynthJson(synthText)
  console.log(`[budgetCouncil] Synthesis: ${synth.verdict} (${synth.score}/100) — ${synth.rationale.slice(0, 80)}... (${Date.now() - synthStart}ms)`)

  return {
    score: synth.score,
    verdict: synth.verdict,
    bullSummary: bull.bullThesis,
    bearSummary: bear.topRedFlags.slice(0, 3).join(' | '),
    invalidationTrigger: bear.invalidationTrigger,
    bullScores: { asymmetry: bull.asymmetry, conviction: bull.conviction, catalyst: bull.catalyst, management: bull.management },
    bearScores: { asymmetry: bear.asymmetry, conviction: bear.conviction, catalyst: bear.catalyst, management: bear.management },
    rationale: synth.rationale,
    keyRisk: synth.keyRisk,
  }
}

router.post('/budget', async (req: Request, res: Response) => {
  const { ticker, dossier } = req.body as BudgetCouncilRequest
  if (!ticker || !dossier) {
    res.status(400).json({ error: 'ticker and dossier are required' })
    return
  }

  try {
    const client = getDeepSeekClient()
    const model = getDeepSeekModel()
    const totalStart = Date.now()

    let result = await runBudgetDebate(client, model, dossier)

    const elapsed = Date.now() - totalStart
    console.log(`[budgetCouncil] ${ticker}: ${result.verdict} (${result.score}/100) in ${elapsed}ms`)
    res.json({ ticker, ...result, elapsedMs: elapsed })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[budgetCouncil] Error:', message)
    // Fail open — if the budget council errors, let the caller decide
    res.status(500).json({
      ticker,
      score: 0,
      verdict: 'kill',
      bullSummary: '',
      bearSummary: '',
      invalidationTrigger: '',
      error: message,
    })
  }
})

export default router
