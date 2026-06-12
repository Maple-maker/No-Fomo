// ── Comprehensive ticker enrichment ──
// Calls Python stock_data.py for: analyst consensus, indicators, inst flow, catalysts, price history
// Uses Brave Search for headlines
// Uses Quiver Quant for congress trades, gov contracts
// Uses DeepSeek for AI snapshot summary
// Uses USPTO PatentsView API for patent acceleration signals
import { execSync } from 'child_process'
import { getStockData, type StockDataResult } from './stockData'
import { enrichTicker as quiverEnrich, type EnrichedData as QuiverData } from '../tools/quiver'
import { getDeepSeekClient, DEEPSEEK_MODEL } from '../agents/client'
import { computeBuyLevels, type BuyLevels } from './buyLevels'
import { getPatentAcceleration, type PatentSignal } from './patents'
import { parseEDGARForInflection, type SECSignal } from './secAnalysis'
import { getJobAcceleration, type JobSignal } from './jobPosting'
import { analyzeTranscriptSentiment, type TranscriptSignal } from './transcriptAnalysis'
import { getShortReports, type ShortReport } from './shortReports'
// ── Phase 2 signal expansion ──
import { trackAnalystRevisions, type RevisionSignal } from './analystRevisions'
import { analyzeShortSqueeze, type SqueezeSignal } from './squeezeAnalysis'
import { analyzeBuybacks, type BuybackSignal } from './buybackAnalysis'
import { analyzeDividendSignal, type DividendSignal } from './dividendSignals'
import { getRedditMentionVelocity, type SocialSignal } from './socialSentiment'
import { analyzeOptionsVol, type OptionsSignal } from './optionsSignals'
import { trackPeerEarnings, type PeerEarningsSignal } from './peerEarningsSignals'
import { runDCF, type DCFResult } from './dcfValuation'

// ── Types ──

export interface AnalystConsensus {
  count: number
  consensus: string
  meanRating: number
  targetMean: number
  targetHigh: number
  targetLow: number
  breakdown: {
    strongBuy: number; buy: number; hold: number; sell: number; strongSell: number
  }
}

export interface InstitutionalHolding {
  name: string
  value: number
  pctChange: number
  dateReported: string
}

export interface TradingIndicators {
  rsi: { value: number; signal: string; explainer: string }
  macd: { value: number; signal: number; histogram: number; trend: string; explainer: string }
  bollinger: { upper: number; middle: number; lower: number; explainer: string }
  volume: { average: number; today: number; ratio: number; explainer: string }
}

export interface EnrichedCatalyst {
  date: string
  type: string
  label: string
  detail: string
}

export interface EnrichedHeadline {
  headline: string
  url: string
  date: string
  source: string
}

export interface TickerEnrichment {
  ticker: string
  price: number
  changePct: number
  marketCap: string
  sector?: string
  industry?: string
  fetchedAt: string
  analyst: AnalystConsensus | null
  institutional: InstitutionalHolding[]
  indicators: TradingIndicators | null
  catalysts: EnrichedCatalyst[]
  headlines: EnrichedHeadline[]
  priceHistory: number[]
  quiver: QuiverData | null
  aiSnapshot: string | null
  buyLevels: BuyLevels | null
  // Short interest
  shortInterest: {
    sharesShort: number | null
    shortRatio: number | null
    shortPctOfFloat: number | null
    sharesShortPriorMonth: number | null
    shortPriorMonthDate: string | null
    shortInterestDate: string | null
    shortMoMChange: number | null  // month-over-month % change
  } | null
  // New fundamental quality signals
  revAcceleration?: number | null
  insiderPct?: number | null
  gaapQualityScore?: number | null
  earningsMissCount?: number
  tags?: string[]
  peerPositioning?: any  // Will define PeerPositioning type in peers.ts
  patentAcceleration?: PatentSignal | null
  secAnalysis?: SECSignal | null
  jobAcceleration?: JobSignal | null
  transcriptSentiment?: TranscriptSignal | null
  shortReports?: ShortReport[]
  // ── Phase 2 signal expansion ──
  analystRevisions?: RevisionSignal | null
  squeezeAnalysis?: SqueezeSignal | null
  buybackAnalysis?: BuybackSignal | null
  dividendSignal?: DividendSignal | null
  socialSentiment?: SocialSignal | null
  optionsSignal?: OptionsSignal | null
  peerEarnings?: PeerEarningsSignal | null
  dcfValuation?: DCFResult | null
}

// ── Explainer text ──

const EXPLAINERS = {
  rsi: 'RSI (Relative Strength Index) measures momentum 0-100. Above 70 = overbought (may pull back). Below 30 = oversold (may bounce). Best used with other signals — not a timing tool.',
  macd: 'MACD tracks trend strength. When the line crosses above signal = bullish momentum. Divergences (price vs MACD) can signal reversals before they happen.',
  bollinger: 'Bollinger Bands show volatility. Price near upper band = extended upward. Near lower band = compressed. Narrow bands (squeeze) often precede big moves.',
  volume: 'Volume confirms price moves. Heavy volume on up days = buying conviction. Heavy on down days = distribution. Low-volume moves are less reliable.',
}

// ── Unified stock data fetcher: Node.js async (primary) → Python (fallback) ──

async function fetchStockData(ticker: string): Promise<StockDataResult | null> {
  const clean = ticker.toUpperCase().trim()

  // Primary: Node.js Yahoo Finance API (works in serverless)
  let nodeResult: StockDataResult | null = null
  try {
    nodeResult = await getStockData(clean)
    if (nodeResult.price > 0) {
      console.log(`[enrich] Node.js stock data OK for ${clean}: $${nodeResult.price}, RSI=${nodeResult.rsi_14}, history=${nodeResult.price_history.length}`)
    } else {
      console.warn(`[enrich] Node.js stock data returned zero price for ${clean}, trying Python...`)
      nodeResult = null
    }
  } catch (e) {
    console.warn(`[enrich] Node.js stock data failed for ${clean}:`, e instanceof Error ? e.message : e)
    nodeResult = null
  }

  // Fallback: Python stock_data.py (local dev only) - also used when price_history is too short
  const tryPython = (): StockDataResult | null => {
    try {
      const script = require('path').resolve(process.cwd(), '..', 'backend', 'stock_data.py')
      const result = execSync(`python3 "${script}" ${clean} --json`, {
        encoding: 'utf-8',
        timeout: 15000,
        maxBuffer: 1024 * 1024,
      })
      return JSON.parse(result)
    } catch (e) {
      console.error(`[enrich] Python stock_data also failed for ${clean}:`, e instanceof Error ? e.message : e)
      return null
    }
  }

  // If Node.js got data but price_history is short (< 80 for sma50), try Python for richer history
  if (nodeResult && nodeResult.price > 0 && nodeResult.price_history.length < 80) {
    const pyResult = tryPython()
    if (pyResult && pyResult.price > 0 && pyResult.price_history.length > nodeResult.price_history.length) {
      console.log(`[enrich] Python had better history for ${clean}: ${pyResult.price_history.length} vs ${nodeResult.price_history.length} from Node.js`)
      return pyResult
    }
    console.log(`[enrich] Keeping Node.js result for ${clean} (Python not better)`)
    return nodeResult
  }

  // Node.js failed entirely — try Python
  if (!nodeResult || nodeResult.price <= 0) {
    const pyResult = tryPython()
    if (pyResult && pyResult.price > 0) return pyResult
  }

  return nodeResult
}

// ── Headlines + Events from Brave Search ──

async function fetchHeadlines(ticker: string): Promise<EnrichedHeadline[]> {
  try {
    const braveKey = process.env.BRAVE_API_KEY
    if (!braveKey) return []

    const res = await fetch(
      `https://api.search.brave.com/res/v1/news/search?q=${ticker}+stock&count=8&freshness=pw`,
      {
        headers: {
          'Accept': 'application/json',
          'X-Subscription-Token': braveKey,
        },
      },
    )
    if (!res.ok) return []

    const data = (await res.json()) as any
    const results = data?.results || []
    return results.slice(0, 8).map((r: any) => ({
      headline: r.title || '',
      url: r.url || '',
      date: r.age || r.page_age?.slice(0, 10) || '',
      source: r.profile?.name || r.meta_url?.hostname || '',
    }))
  } catch (e) {
    console.error('[enrich] Brave headlines failed:', e instanceof Error ? e.message : e)
    return []
  }
}

async function fetchCatalysts(ticker: string): Promise<EnrichedCatalyst[]> {
  try {
    const braveKey = process.env.BRAVE_API_KEY
    if (!braveKey) return []

    const catalysts: EnrichedCatalyst[] = []

    // Search for upcoming events
    const queries = [
      `${ticker} earnings date 2026`,
      `${ticker} earnings call transcript`,
      `${ticker} investor conference presentation`,
    ]

    for (const q of queries) {
      const res = await fetch(
        `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(q)}&count=3&freshness=pm`,
        {
          headers: {
            'Accept': 'application/json',
            'X-Subscription-Token': braveKey,
          },
        },
      )
      if (!res.ok) continue

      const data = (await res.json()) as any
      const results = data?.web?.results || []

      for (const r of results) {
        const title = (r.title || '').toLowerCase()
        const desc = (r.description || '').toLowerCase()

        let type = 'event'
        if (title.includes('earnings') || desc.includes('earnings')) {
          type = 'earnings'
        } else if (title.includes('conference') || desc.includes('conference')) {
          type = 'conference'
        } else if (title.includes('investor day') || desc.includes('investor day')) {
          type = 'investor_day'
        }

        catalysts.push({
          date: r.age || r.page_age?.slice(0, 10) || '',
          type,
          label: type === 'earnings' ? 'Earnings' : type === 'conference' ? 'Conference' : 'Event',
          detail: r.description?.slice(0, 200) || title,
        })
      }
    }

    // Deduplicate by date+label
    const seen = new Set<string>()
    return catalysts.filter(c => {
      const key = `${c.date}|${c.label}`
      if (seen.has(key)) return false
      seen.add(key)
      return true
    }).slice(0, 6)
  } catch (e) {
    console.error('[enrich] Brave catalysts failed:', e instanceof Error ? e.message : e)
    return []
  }
}

// ── AI Snapshot (DeepSeek) ──

async function generateAISnapshot(
  ticker: string, price: number, changePct: number, sectors: string,
  analyst: any, indicators: any, catalysts: any[],
): Promise<string | null> {
  try {
    const client = getDeepSeekClient()
    let context = `$${ticker} — $${price} (${changePct >= 0 ? '+' : ''}${changePct}%)\nSectors: ${sectors}\n`

    if (analyst) {
      context += `\nAnalysts: ${analyst.count || '?'} covering. Consensus: ${analyst.consensus || 'N/A'} (${analyst.meanRating || '?'}/5, where 1=strong buy). `
      context += `Target range: $${analyst.targetLow || '?'}-$${analyst.targetHigh || '?'}, mean $${analyst.targetMean || '?'}.`
    }
    if (indicators?.rsi) {
      const r = indicators.rsi
      context += `\nRSI: ${r.value} (${r.signal}). `
    }
    if (indicators?.macd) {
      context += `MACD: ${indicators.macd.trend}. `
    }
    if (catalysts?.length) {
      context += `\nUpcoming: ${catalysts.map((c: any) => `${c.label}${c.date ? ' ' + c.date : ''}`).join(', ')}.`
    }

    const resp = await client.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        {
          role: 'system',
          content: 'You write concise stock analysis for a mobile app. Write exactly 2-3 sentences in plain English (no jargon) explaining what the data means. Cover: (1) whether analysts are bullish/bearish and if they agree, (2) any notable signal from RSI or MACD, (3) what to watch for. Be balanced — include downside if the data shows it. Never exceed 160 words. No markdown, no ticker symbol needed.',
        },
        { role: 'user', content: context },
      ],
      temperature: 0.3,
      max_tokens: 250,
    })
    return resp.choices[0]?.message.content?.trim() || null
  } catch (e) {
    console.error(`[enrich] AI snapshot failed:`, e instanceof Error ? e.message : e)
    return null
  }
}

// ── Tag themes from sector/industry ──

function tagThemes(sector?: string, industry?: string): string[] {
  const tags = new Set<string>()
  const input = [sector, industry].filter(Boolean).join(' / ')

  // Split on common delimiters
  const parts = input
    .split(/[/—,·&]+/)
    .map(s => s.trim())
    .filter(s => s.length > 1)

  // Normalize common sector names to canonical tags
  const canonical: Record<string, string> = {
    'technology': 'Technology',
    'tech': 'Technology',
    'software': 'Software',
    'data center infrastructure': 'Data Center',
    'data center': 'Data Center',
    'data & ai analytics': 'AI/ML',
    'ai': 'AI/ML',
    'artificial intelligence': 'AI/ML',
    'defense': 'Defense',
    'defense & aerospace': 'Defense',
    'aerospace': 'Aerospace',
    'aerospace & defense': 'Defense',
    'automotive': 'Automotive',
    'consumer cyclical': 'Consumer',
    'bitcoin treasury': 'Crypto',
    'bitcoin': 'Crypto',
    'crypto': 'Crypto',
    'telecommunications': 'Telecom',
    'telecom': 'Telecom',
    'satellite broadband': 'Space',
    'satellite': 'Space',
    'space': 'Space',
    'nuclear energy': 'Energy',
    'nuclear': 'Energy',
    'energy': 'Energy',
    'utilities': 'Utilities',
    'healthcare': 'Healthcare',
    'health': 'Healthcare',
    'biotech': 'Biotech',
    'pharma': 'Pharma',
    'financial': 'Financials',
    'financials': 'Financials',
    'fintech': 'Fintech',
    'banking': 'Financials',
    'real estate': 'Real Estate',
    'manufacturing': 'Industrial',
    'industrial': 'Industrial',
    'hardware': 'Hardware',
    'semiconductor': 'Semiconductors',
    'semiconductors': 'Semiconductors',
    'government': 'Government',
    'retail': 'Retail',
    'media': 'Media',
    'gaming': 'Gaming',
  }

  for (const part of parts) {
    const lower = part.toLowerCase().trim()
    const mapped = canonical[lower] || part
    if (mapped.length > 1 && mapped.length < 30) {
      tags.add(mapped)
    }
  }

  // Always add a few standard categories based on content
  const full = input.toLowerCase()
  if (full.includes('pre-revenue') || full.includes('pre revenue')) tags.add('Pre-Revenue')
  if (full.includes('space')) tags.add('Space')
  if (full.includes('defense') || full.includes('military') || full.includes('dod')) tags.add('Defense')
  if (full.includes('ai') || full.includes('machine learning') || full.includes('artificial')) tags.add('AI/ML')
  if (full.includes('data')) tags.add('Data')
  if (full.includes('cloud') || full.includes('saas')) tags.add('SaaS')

  return Array.from(tags).sort()
}

// ── Main entry point ──

export async function fullEnrich(ticker: string, webSourceUrls: string[] = []): Promise<TickerEnrichment> {
  const clean = ticker.toUpperCase().trim()

  // Fetch all data sources in parallel
  const [stockData, headlines, braveCatalysts, quiver, patentSignal, secSignal] = await Promise.all([
    fetchStockData(clean),  // Node.js async primary, Python fallback
    fetchHeadlines(clean),
    fetchCatalysts(clean),
    (process.env.QUIVER_API_KEY ? quiverEnrich(clean).catch(() => null) : Promise.resolve(null)),
    getPatentAcceleration(clean).catch(() => null),
    parseEDGARForInflection(clean).catch(() => null),
  ])

  // Get company name for job/transcript lookups
  const companyName = (stockData as any)?.company_name || clean

  // Fetch job, transcript, short report + Phase 2 expansion signals (all in parallel)
  const [
    jobSignal, transcriptSignal, shortReportSignal,
    buybackSignal, dividendSignal, socialSignal, optionsSignal, peerEarnings,
  ] = await Promise.all([
    getJobAcceleration(clean, companyName).catch(() => null),
    analyzeTranscriptSentiment(clean).catch(() => null),
    getShortReports(clean).catch(() => []),
    analyzeBuybacks(clean).catch(() => null),
    analyzeDividendSignal(clean, stockData).catch(() => null),
    getRedditMentionVelocity(clean).catch(() => null),
    analyzeOptionsVol(clean).catch(() => null),
    trackPeerEarnings(clean).catch(() => null),
  ])

  // ── Parse stock data into enrichment types ──
  const sd: Partial<StockDataResult> = stockData || {}

  // ── Phase 2: synchronous signals derived from stock data (no extra fetch) ──
  const analystRevisions = trackAnalystRevisions(clean, stockData)
  const squeezeAnalysis = analyzeShortSqueeze(clean, stockData, sd.insider_pct ?? null)

  const analyst: AnalystConsensus | null = sd.analyst_count ? {
    count: sd.analyst_count || 0,
    consensus: sd.analyst_consensus || 'N/A',
    meanRating: sd.analyst_mean_rating || 0,
    targetMean: sd.analyst_target_mean || 0,
    targetHigh: sd.analyst_target_high || 0,
    targetLow: sd.analyst_target_low || 0,
    breakdown: sd.recommendation_breakdown || { strongBuy: 0, buy: 0, hold: 0, sell: 0, strongSell: 0 },
  } : null

  const institutional: InstitutionalHolding[] = (sd.institutional_holders || []).map((h: any) => ({
    name: h.name || '',
    value: h.value || 0,
    pctChange: h.pct_change || 0,
    dateReported: h.date_reported || '',
  }))

  const indicators: TradingIndicators | null = sd.rsi_14 != null ? {
    rsi: {
      value: sd.rsi_14 || 50,
      signal: sd.rsi_signal || 'neutral',
      explainer: EXPLAINERS.rsi,
    },
    macd: {
      value: sd.macd?.macd || 0,
      signal: sd.macd?.signal || 0,
      histogram: sd.macd?.histogram || 0,
      trend: sd.macd?.bullish ? 'bullish' : 'bearish',
      explainer: EXPLAINERS.macd,
    },
    bollinger: {
      upper: sd.bollinger?.upper || 0,
      middle: sd.bollinger?.middle || 0,
      lower: sd.bollinger?.lower || 0,
      explainer: EXPLAINERS.bollinger,
    },
    volume: {
      average: sd.avg_volume || 0,
      today: Math.round((sd.avg_volume || 0) * (sd.vol_vs_avg || 1)),
      ratio: sd.vol_vs_avg || 1,
      explainer: EXPLAINERS.volume,
    },
  } : null

  // Merge yfinance catalysts with Brave catalysts
  const yfCatalysts: EnrichedCatalyst[] = (sd.catalysts || []).map((c: any) => ({
    date: c.date || '',
    type: c.type || 'event',
    label: c.label || '',
    detail: c.detail || '',
  }))
  const catalysts = [...yfCatalysts, ...braveCatalysts.filter(bc =>
    !yfCatalysts.some(yc => yc.date === bc.date && yc.label === bc.label)
  )].slice(0, 8)

  // ── AI Snapshot ──
  const aiSnapshot = await generateAISnapshot(
    clean, sd.price || 0, sd.change_pct || 0,
    `${sd.sector || ''} · ${sd.industry || ''}`,
    analyst, indicators, catalysts,
  )

  // ── Short Interest ──
  const shortInterest = sd.shares_short != null ? {
    sharesShort: sd.shares_short ?? null,
    shortRatio: sd.short_ratio ?? null,
    shortPctOfFloat: sd.short_pct_of_float ?? null,
    sharesShortPriorMonth: sd.shares_short_prior_month ?? null,
    shortPriorMonthDate: sd.short_prior_month_date ?? null,
    shortInterestDate: sd.short_interest_date ?? null,
    shortMoMChange: (sd.shares_short != null && sd.shares_short_prior_month != null && sd.shares_short_prior_month > 0)
      ? Math.round(((sd.shares_short - sd.shares_short_prior_month) / sd.shares_short_prior_month) * 10000) / 100
      : null,
  } : null

  console.log(`[enrich] ${clean}: analyst=${!!analyst} indicators=${!!indicators} inst=${institutional.length} catalysts=${catalysts.length} headlines=${headlines.length} quiver=${!!quiver} ai=${!!aiSnapshot} short=${!!shortInterest} sec=${!!secSignal} jobs=${!!jobSignal} transcript=${!!transcriptSignal} shortReports=${shortReportSignal?.length || 0}`)
  console.log(`[enrich] ${clean} Phase2: revisions=${analystRevisions?.signal ? 'Y' : 'n'} squeeze=${squeezeAnalysis?.shortSqueezePct ?? 'n'}% buyback=${buybackSignal?.buybackActive ?? 'n'} div=${dividendSignal?.paysDividend ?? 'n'} reddit=${socialSignal?.mentionVelocity ?? 'n'}x iv=${optionsSignal?.impliedVol ?? 'n'} peers=${peerEarnings ? peerEarnings.sectorMomentum : 'n'}`)

  // ── DCF valuation ──
  const growthRate = sd.rev_growth_yoy != null
    ? Math.max(0, Math.min(0.30, sd.rev_growth_yoy / 100))
    : 0.08
  const dcf = (sd.fcf != null && sd.fcf > 0 && sd.cash_and_equiv != null && sd.debt_total != null && sd.shares_outstanding != null && sd.price != null && sd.price > 0)
    ? runDCF({ fcf: sd.fcf, cash: sd.cash_and_equiv, debt: sd.debt_total, shares: sd.shares_outstanding, price: sd.price, growth: growthRate })
    : null

  // ── Buy levels ──
  const buyLevels = computeBuyLevels(
    sd.price || 0,
    sd.price_history || [],
    sd.beta ?? null,
  )

  return {
    ticker: clean,
    price: sd.price || 0,
    changePct: sd.change_pct || 0,
    marketCap: sd.market_cap || 'N/A',
    sector: sd.sector || '',
    industry: sd.industry || '',
    fetchedAt: new Date().toISOString(),
    analyst,
    institutional,
    indicators,
    catalysts,
    headlines,
    priceHistory: sd.price_history || [],
    quiver,
    aiSnapshot,
    buyLevels,
    shortInterest,
    // New fundamental quality signals
    revAcceleration: sd.rev_acceleration ?? null,
    insiderPct: sd.insider_pct ?? null,
    gaapQualityScore: sd.gaap_quality_score ?? null,
    earningsMissCount: sd.earnings_miss_count ?? 0,
    tags: tagThemes(stockData?.sector, stockData?.industry),
    peerPositioning: null,  // Will be populated by getPeerPositioning()
    patentAcceleration: patentSignal ?? null,
    secAnalysis: secSignal ?? null,
    jobAcceleration: jobSignal ?? null,
    transcriptSentiment: transcriptSignal ?? null,
    shortReports: shortReportSignal ?? [],
    // ── Phase 2 signal expansion ──
    analystRevisions: analystRevisions ?? null,
    squeezeAnalysis: squeezeAnalysis ?? null,
    buybackAnalysis: buybackSignal ?? null,
    dividendSignal: dividendSignal ?? null,
    socialSentiment: socialSignal ?? null,
    optionsSignal: optionsSignal ?? null,
    peerEarnings: peerEarnings ?? null,
    dcfValuation: dcf,
  }
}
