import { Router, type Request, type Response } from 'express'
import { getSupabaseAdmin } from '../lib/supabase'
import { sendCustomPush } from './notify'

const router = Router()

// ─────────────────────────────────────────────────────────────────────────────
// Canonical thesis shape — the ONLY shape the matcher functions ever see.
// Inputs arrive in two key styles (snake_case from user_theses rows + the iOS
// encoder, camelCase from ad-hoc API callers) — normalizeThesis accepts both.
// ─────────────────────────────────────────────────────────────────────────────

interface CanonicalThesis {
  id: number | null
  userId: string
  name: string
  isActive: boolean
  detectionLanes: string[]
  sectorFilter: string[]
  tierFilter: number[]
  minScore: number
  minUpside: number | null
  minProbability: number | null
  maxAnalystCount: number | null
  minMarketCapB: number | null
  maxMarketCapB: number | null
  requireInsiderBuying: boolean
  requireGovContract: boolean
  requireFdaCatalyst: boolean
  requireEarningsInflection: boolean
  requireAnalystUpgrade: boolean
  requireBullConsensus: boolean
  requireTripleSignal: boolean
  notifyTier1: boolean
  notifyTier2: boolean
  matchCount: number
}

function pick(obj: Record<string, unknown>, ...keys: string[]): unknown {
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null) return obj[k]
  }
  return undefined
}

function asNum(v: unknown): number | null {
  if (v === undefined || v === null || v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

function asBool(v: unknown): boolean {
  return v === true || v === 'true'
}

function asStrArr(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((s): s is string => typeof s === 'string') : []
}

function asNumArr(v: unknown): number[] {
  if (!Array.isArray(v)) return []
  return v.map(n => Number(n)).filter(n => Number.isFinite(n))
}

export function normalizeThesis(input: Record<string, unknown>): CanonicalThesis {
  const tiers = asNumArr(pick(input, 'tier_filter', 'tierFilter'))
  return {
    id: asNum(pick(input, 'id')),
    userId: String(pick(input, 'user_id', 'userId') ?? ''),
    name: String(pick(input, 'name') ?? ''),
    isActive: pick(input, 'is_active', 'isActive') !== false,
    detectionLanes: asStrArr(pick(input, 'detection_lanes', 'detectionLanes')),
    sectorFilter: asStrArr(pick(input, 'sector_filter', 'sectorFilter')),
    tierFilter: tiers.length ? tiers : [1, 2],
    minScore: asNum(pick(input, 'min_score', 'minScore')) ?? 75,
    minUpside: asNum(pick(input, 'min_upside', 'minUpside')),
    minProbability: asNum(pick(input, 'min_probability', 'minProbability')),
    maxAnalystCount: asNum(pick(input, 'max_analyst_count', 'maxAnalystCount')),
    minMarketCapB: asNum(pick(input, 'min_market_cap_b', 'minMarketCapB')),
    maxMarketCapB: asNum(pick(input, 'max_market_cap_b', 'maxMarketCapB')),
    requireInsiderBuying: asBool(pick(input, 'require_insider_buying', 'requireInsiderBuying')),
    requireGovContract: asBool(pick(input, 'require_gov_contract', 'requireGovContract')),
    requireFdaCatalyst: asBool(pick(input, 'require_fda_catalyst', 'requireFdaCatalyst')),
    requireEarningsInflection: asBool(pick(input, 'require_earnings_inflection', 'requireEarningsInflection')),
    requireAnalystUpgrade: asBool(pick(input, 'require_analyst_upgrade', 'requireAnalystUpgrade')),
    requireBullConsensus: asBool(pick(input, 'require_bull_consensus', 'requireBullConsensus')),
    requireTripleSignal: asBool(pick(input, 'require_triple_signal', 'requireTripleSignal')),
    notifyTier1: pick(input, 'notify_tier1', 'notifyTier1') !== false,
    notifyTier2: pick(input, 'notify_tier2', 'notifyTier2') !== false,
    matchCount: asNum(pick(input, 'match_count', 'matchCount')) ?? 0,
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Matchers — all operate on a radar_opportunities data_snapshot (snake_case)
// ─────────────────────────────────────────────────────────────────────────────

// market_cap is a display string like "$3.2B" / "$840M" — returns billions, or
// null when unparseable (callers skip the filter rather than silently fail it).
export function parseMarketCapB(raw: unknown): number | null {
  if (typeof raw === 'number') return Number.isFinite(raw) ? raw : null
  if (typeof raw !== 'string') return null
  const m = raw.replace(/[$,\s]/g, '').match(/^([\d.]+)([TBM])?/i)
  if (!m || !m[1]) return null
  const n = Number(m[1])
  if (!Number.isFinite(n) || n === 0) return null
  const unit = (m[2] ?? 'B').toUpperCase()
  if (unit === 'T') return n * 1000
  if (unit === 'M') return n / 1000
  return n
}

// Sector entries match loosely: each entry is tokenized on "/" and matched
// case-insensitively with word boundaries against sector + tags text, so
// "AI & Data Infrastructure" matches tags like "AI/ML" or "Data Center".
function matchesSector(thesis: CanonicalThesis, snap: any): boolean {
  if (!thesis.sectorFilter.length) return true
  const haystack = `${snap?.sector ?? ''} ${(snap?.tags ?? []).join(' ')}`
  return thesis.sectorFilter.some(entry =>
    entry.split('/').some(part => {
      const token = part.trim()
      if (!token) return false
      const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      return new RegExp(`\\b${escaped}`, 'i').test(haystack)
    })
  )
}

function matchesLane(thesis: CanonicalThesis, snap: any): boolean {
  if (!thesis.detectionLanes.length) return true
  const lane = String(snap?.detection_lane ?? '').toLowerCase()
  return thesis.detectionLanes.some(l => l.toLowerCase() === lane)
}

type SignalKey =
  | 'requireInsiderBuying' | 'requireGovContract' | 'requireFdaCatalyst'
  | 'requireEarningsInflection' | 'requireAnalystUpgrade' | 'requireBullConsensus'
  | 'requireTripleSignal'

const SIGNAL_KEYS: SignalKey[] = [
  'requireInsiderBuying', 'requireGovContract', 'requireFdaCatalyst',
  'requireEarningsInflection', 'requireAnalystUpgrade', 'requireBullConsensus',
  'requireTripleSignal',
]

function signalPasses(key: SignalKey, snap: any): boolean {
  switch (key) {
    case 'requireInsiderBuying':
      return Number(snap?.insider_cluster_score ?? 0) >= 4
    case 'requireGovContract':
      return /contract/i.test(`${snap?.government_signal ?? ''} ${snap?.government_support ?? ''}`)
    case 'requireFdaCatalyst':
      return /fda|pdufa|approval/i.test(
        `${snap?.catalyst ?? ''} ${((snap?.upcoming_events ?? []) as any[]).flat().join(' ')}`
      )
    case 'requireEarningsInflection':
      return Number(snap?.rev_acceleration ?? 0) > 0
    case 'requireAnalystUpgrade':
      return ((snap?.recent_analyst_actions ?? []) as any[]).some(
        a => Array.isArray(a) && /upgrade/i.test(a.join(' '))
      )
    case 'requireBullConsensus':
      return snap?.council?.gemini === 'BULL' && snap?.council?.deepseek === 'BULL' && snap?.council?.cio === 'BULL'
    case 'requireTripleSignal':
      return snap?.triple_signal === true
  }
}

function matchesSignals(thesis: CanonicalThesis, snap: any): boolean {
  return SIGNAL_KEYS.every(key => !thesis[key] || signalPasses(key, snap))
}

interface MatchableRow {
  tier: number
  overall_score: number
  data_snapshot: any
}

export function matchesThesisRow(thesis: CanonicalThesis, row: MatchableRow): boolean {
  const snap = row.data_snapshot ?? {}
  if (!thesis.tierFilter.includes(row.tier)) return false
  if ((row.overall_score ?? 0) < thesis.minScore) return false
  if (thesis.minUpside != null && Number(snap.upside ?? 0) < thesis.minUpside) return false
  if (thesis.minProbability != null && Number(snap.probability ?? 0) < thesis.minProbability) return false
  if (thesis.maxAnalystCount != null && Number(snap.analyst_count ?? 99) > thesis.maxAnalystCount) return false
  if (thesis.minMarketCapB != null || thesis.maxMarketCapB != null) {
    const capB = parseMarketCapB(snap.market_cap)
    if (capB != null) {
      if (thesis.minMarketCapB != null && capB < thesis.minMarketCapB) return false
      if (thesis.maxMarketCapB != null && capB > thesis.maxMarketCapB) return false
    }
  }
  return matchesSector(thesis, snap) && matchesLane(thesis, snap) && matchesSignals(thesis, snap)
}

// Fit = fraction of the thesis's enabled signal requirements the row satisfies.
// Only called on rows that already matched; no requirements set → flat 75.
export function computeFitScore(thesis: CanonicalThesis, row: MatchableRow): number {
  const snap = row.data_snapshot ?? {}
  const enabled = SIGNAL_KEYS.filter(k => thesis[k])
  if (!enabled.length) return 75
  const passed = enabled.filter(k => signalPasses(k, snap))
  return Math.round((passed.length / enabled.length) * 100)
}

// ─────────────────────────────────────────────────────────────────────────────
// Templates — kept manually in sync with ThesisTemplate.all in the iOS app
// (NoFomo/Models/CustomThesis.swift). Lane strings must be canonical lanes
// from the radar prompt (radar.ts).
// ─────────────────────────────────────────────────────────────────────────────

const TEMPLATES = [
  { id: 'underfollowed-gem', name: 'The Underfollowed Gem', description: 'Tiny analyst coverage, insiders buying, huge upside', tierFilter: [1, 2], maxAnalystCount: 3, requireInsiderBuying: true, minUpside: 150 },
  { id: 'gov-contract-play', name: 'Government Contract Play', description: 'Small caps catching government & regulatory tailwinds', tierFilter: [1, 2], detectionLanes: ['Government & Regulatory Support'], maxMarketCapB: 5 },
  { id: 'earnings-turnaround', name: 'Earnings Turnaround', description: 'Revenue inflecting positive with a strong score', tierFilter: [2], requireEarningsInflection: true, minScore: 78 },
  { id: 'deep-value-activist', name: 'Deep Value Activist', description: 'Under-covered names with 3x+ upside potential', maxAnalystCount: 5, minUpside: 200 },
  { id: 'ai-infrastructure', name: 'AI Infrastructure Pick', description: 'Picks-and-shovels for the AI buildout', tierFilter: [2], sectorFilter: ['AI & Data Infrastructure', 'Semiconductors'], minUpside: 150 },
  { id: 'biotech-catalyst', name: 'Biotech Binary Catalyst', description: 'FDA events with full AI council conviction', sectorFilter: ['Biotech'], requireFdaCatalyst: true, requireBullConsensus: true },
  { id: 'insider-cluster', name: 'Insider Accumulation Cluster', description: 'Multiple insiders buying in the open market', tierFilter: [1, 2], requireInsiderBuying: true },
  { id: 'defense-ai', name: 'Defense × AI Convergence', description: 'Autonomy and defense tech with government backing', detectionLanes: ['Government & Regulatory Support'], sectorFilter: ['Defense Tech', 'AI & Data Infrastructure'], tierFilter: [1, 2] },
  { id: 'renaissance-rebrand', name: 'Renaissance Company', description: 'Legacy businesses the market still prices as the old company', detectionLanes: ['Renaissance / Rebrand'], maxAnalystCount: 6, minUpside: 200 },
  { id: 'short-squeeze', name: 'Short Squeeze Setup', description: 'Insider conviction on under-covered, shorted names', requireInsiderBuying: true, maxAnalystCount: 4 },
]

// ─────────────────────────────────────────────────────────────────────────────
// Core check — called fire-and-forget from the radar persist path.
// NEVER throws; one bad thesis (e.g. a non-uuid user_id 400ing the
// push_tokens lookup) must not kill the loop.
// ─────────────────────────────────────────────────────────────────────────────

export async function checkThesisMatches(opts: {
  ticker: string
  tier: number
  score: number
  bluf: string
  snapshot: Record<string, unknown>
}): Promise<{ checked: number; matched: number; pushed: number }> {
  const result = { checked: 0, matched: 0, pushed: 0 }
  try {
    const supabase = getSupabaseAdmin()
    const { data: theses, error } = await supabase
      .from('user_theses')
      .select('*')
      .eq('is_active', true)
    if (error || !theses?.length) return result

    const row: MatchableRow = { tier: opts.tier, overall_score: opts.score, data_snapshot: opts.snapshot ?? {} }
    result.checked = theses.length

    for (const raw of theses as Record<string, unknown>[]) {
      try {
        const thesis = normalizeThesis(raw)
        if (thesis.id == null) continue
        if (!matchesThesisRow(thesis, row)) continue
        result.matched++
        const fit = computeFitScore(thesis, row)

        // Radar rescans delete + reinsert the same ticker daily — an existing
        // match means "already alerted": refresh the snapshot, skip the push.
        const { data: existing } = await supabase
          .from('thesis_matches')
          .select('id')
          .eq('thesis_id', thesis.id)
          .eq('ticker', opts.ticker)
          .limit(1)
        const existingRows = (existing ?? []) as { id: number }[]
        if (existingRows.length) {
          await (supabase.from('thesis_matches') as any)
            .update({ tier: opts.tier, score: Math.round(opts.score), bluf: opts.bluf, thesis_fit_score: fit, matched_at: new Date().toISOString() })
            .eq('id', existingRows[0].id)
          continue
        }

        await supabase.from('thesis_matches').insert({
          thesis_id: thesis.id,
          ticker: opts.ticker,
          tier: opts.tier,
          score: Math.round(opts.score),
          bluf: opts.bluf,
          thesis_fit_score: fit,
        } as any)
        await (supabase.from('user_theses') as any)
          .update({ match_count: thesis.matchCount + 1, last_matched_at: new Date().toISOString(), updated_at: new Date().toISOString() })
          .eq('id', thesis.id)

        const wantsPush = (opts.tier === 1 && thesis.notifyTier1) || (opts.tier === 2 && thesis.notifyTier2)
        if (!wantsPush) continue

        const { data: tokens } = await supabase
          .from('push_tokens')
          .select('apns_token')
          .eq('user_id', thesis.userId)
        const tokenRows = (tokens ?? []) as { apns_token: string }[]
        if (!tokenRows.length) continue

        const sends = await Promise.allSettled(
          tokenRows.map(t => sendCustomPush(
            t.apns_token,
            `🎯 ${thesis.name} matched`,
            `$${opts.ticker} — Score ${Math.round(opts.score)}/100: ${(opts.bluf ?? '').slice(0, 100)}`,
            { ticker: opts.ticker, thesis_id: String(thesis.id) },
          ))
        )
        if (sends.some(s => s.status === 'fulfilled' && s.value)) result.pushed++
      } catch (e) {
        console.warn(`[thesis] check failed for thesis ${raw?.id}:`, e instanceof Error ? e.message : e)
      }
    }

    console.log(`[thesis] ${opts.ticker} — checked ${result.checked}, matched ${result.matched}, pushed ${result.pushed}`)
  } catch (e) {
    console.warn('[thesis] checkThesisMatches failed:', e instanceof Error ? e.message : e)
  }
  return result
}

// ─────────────────────────────────────────────────────────────────────────────
// Routes
// ─────────────────────────────────────────────────────────────────────────────

// GET /thesis/templates — prebuilt thesis presets
router.get('/templates', (_req: Request, res: Response) => {
  res.json({ templates: TEMPLATES })
})

// POST /thesis/match — run a thesis against the live radar_opportunities table
router.post('/match', async (req: Request, res: Response) => {
  try {
    const { thesis: input } = req.body as { thesis?: Record<string, unknown> }
    if (!input) {
      res.status(400).json({ error: 'thesis required' })
      return
    }
    const thesis = normalizeThesis(input)

    const supabase = getSupabaseAdmin()
    const { data: rows, error } = await supabase
      .from('radar_opportunities')
      .select('*')
      .gte('overall_score', thesis.minScore)
      .in('tier', thesis.tierFilter)
      .order('overall_score', { ascending: false })
      .limit(50)
    if (error) {
      res.status(500).json({ error: error.message })
      return
    }

    const matches = ((rows ?? []) as any[])
      .filter(r => matchesThesisRow(thesis, { tier: r.tier, overall_score: Number(r.overall_score ?? 0), data_snapshot: r.data_snapshot }))
      .map(r => ({ ...r, thesis_fit_score: computeFitScore(thesis, { tier: r.tier, overall_score: Number(r.overall_score ?? 0), data_snapshot: r.data_snapshot }) }))
      .sort((a, b) => b.thesis_fit_score - a.thesis_fit_score)

    res.json({ matches, totalCount: matches.length })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[thesis] match error:', message)
    res.status(500).json({ error: message })
  }
})

// POST /thesis/notify-check — manual trigger for testing; the radar persist
// path calls checkThesisMatches() directly (no HTTP round-trip).
router.post('/notify-check', async (req: Request, res: Response) => {
  const { ticker, tier, score, bluf, snapshot } = req.body as {
    ticker?: string; tier?: number; score?: number; bluf?: string; snapshot?: Record<string, unknown>
  }
  if (!ticker || tier == null || score == null) {
    res.status(400).json({ error: 'ticker, tier, and score are required' })
    return
  }
  const result = await checkThesisMatches({ ticker, tier, score, bluf: bluf ?? '', snapshot: snapshot ?? {} })
  res.json(result)
})

export default router
