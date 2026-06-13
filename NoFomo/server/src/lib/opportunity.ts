import type { StructuredOpportunity, CouncilVerdict, GrokVerdict, CIOArbiter } from '../agents/types'

const RATIO_LABEL_PATTERNS = [
  /gross\s*margin/i,
  /operating\s*margin/i,
  /\bp\/?e\b/i,
  /ev\/?ebitda/i,
  /dividend/i,
  /^beta$/i,
  /net\s*debt/i,
]

export function dedupeFinancials(financials: string[][]): string[][] {
  return (financials ?? []).filter(row => {
    const label = String(row?.[0] ?? '')
    return label.length > 0 && !RATIO_LABEL_PATTERNS.some(rx => rx.test(label))
  })
}

type RadarRow = {
  ticker: string
  tier: number
  overall_score: number
  thesis: string
  gemini_analysis: string
  score_breakdown?: unknown
  reprice_gap?: unknown
  council_explanation?: unknown
  regime_flags?: string[]
  data_snapshot: {
    company_name: string
    sector: string
    triple_signal: boolean
    price: number
    upside: number
    market_cap: string
    probability: number
    catalyst: string
    detection_lane: string
    council: { gemini: string; deepseek: string; grok: string; cio: string }
    narrative_velocity: number
    buy_zones: { aggressive: number; base: number; conservative: number }
    bull_case: string
    bear_case: string
    financials: string[][]
    red_flags: string[]
    invalidation: string
    full_report_md: string
    asymmetry_score: number
    conviction_score: number
    catalyst_score: number
    management_score: number
    analyst_ai_divergence: boolean
    // Qualtrim-style competitive analysis
    competitive_advantages?: string
    investment_risks?: string
    key_metrics?: {
      revenue?: string; net_income?: string; eps?: string
      pe_trailing?: string; pe_forward?: string; ev_ebitda?: string
      gross_margin?: string; operating_margin?: string; dividend_yield?: string; beta?: string
    }
    // Insider activity
    insider_total_buys?: number; insider_total_sells?: number
    insider_buy_volume?: number; insider_sell_volume?: number
    insider_buying_names?: string[]; insider_selling_names?: string[]
    insider_cluster_score?: number; insider_net_sentiment?: string
    insider_signal?: string; insider_transactions?: string[][]
    // Existing enrichment
    price_history?: number[]
    rsi_value?: number
    rsi_signal?: string
    macd_trend?: string
    volume_vs_avg?: number
    support_level?: number
    resistance_level?: number
    recent_headlines?: string[][]
    upcoming_events?: string[][]
    analyst_consensus?: string
    analyst_count?: number
    avg_price_target?: number
    recent_analyst_actions?: string[][]
    council_summary?: string
    // New fundamental quality signals
    rev_acceleration?: number | null
    insider_pct?: number | null
    gaap_quality_score?: number | null
    earnings_miss_count?: number
    tags?: string[]
    peer_percentile_rank?: number
    peer_verdict?: string
    contrarian_score?: number
    smart_money_score?: number
    government_score?: number
    smart_money_signal?: string
    government_signal?: string
    // SEC analysis
    sec_management_changes?: string[]
    sec_material_contracts?: string[]
    sec_risk_removals?: string[]
    // Job posting signals
    job_acceleration?: number | null
    job_posting_count?: number
    // Transcript sentiment
    transcript_sentiment_score?: number | null
    transcript_confidence?: number
    // Short reports
    short_report_found?: boolean
    short_thesis_contradicted?: boolean
    // ── Phase 2 signal expansion ──
    analyst_revisions_momentum?: number | null
    analyst_revisions_up?: number
    analyst_revisions_down?: number
    short_squeeze_pct?: number | null
    days_to_cover?: number | null
    float_pct?: number | null
    buyback_active?: boolean
    shares_change_pct?: number | null
    shares_repurchased_pct?: number
    dividend_initiated?: boolean
    dividend_yield_pct?: number | null
    payout_ratio?: number | null
    reddit_mention_velocity?: number | null
    reddit_sentiment?: string
    implied_vol?: number | null
    iv_expansion_pct?: number | null
    put_call_ratio?: number | null
    form3_new_insiders?: string[]
    form5_unreported_volume?: number
    peer_beats_count?: number
    peer_misses_count?: number
    sector_momentum?: number | null
    board_changes?: number
    debt_maturities_next_12m?: number | null
    refinancing_risk?: string
    // ── Asymmetry decay / window status ──
    window_status?: string              // 'open' | 'closing' | 'closed'
    asymmetry_open_score?: number       // 0-100; higher = more asymmetry remaining
    asymmetry_decay_reasons?: string[]
    expires_at?: string                 // ISO; auto-prune deadline if not refreshed
    radar_v2_shadow?: unknown
  }
}

export function buildRadarRow(
  structured: StructuredOpportunity,
  bull: CouncilVerdict,
  bear: CouncilVerdict,
  neutral: CIOArbiter,
  enrichment?: {
    priceHistory?: number[]
    rsiValue?: number; rsiSignal?: string; macdTrend?: string
    volumeRatio?: number; supportLevel?: number; resistanceLevel?: number
    recentHeadlines?: string[][]; upcomingEvents?: string[][]
    analystConsensusString?: string; analystCount?: number; avgPriceTarget?: number
    recentAnalystActions?: string[][]
    councilSummary?: string
    // Insider data
    insiderTotalBuys?: number; insiderTotalSells?: number
    insiderBuyVolume?: number; insiderSellVolume?: number
    insiderBuyingNames?: string[]; insiderSellingNames?: string[]
    insiderClusterScore?: number; insiderNetSentiment?: string
    insiderSignal?: string; insiderTransactions?: string[][]
    // New fundamental quality signals
    revAcceleration?: number | null
    insiderPct?: number | null
    gaapQualityScore?: number | null
    earningsMissCount?: number
    tags?: string[]
    peerPercentileRank?: number
    peerVerdict?: string
    contrarian?: number
    smartMoneyScore?: number
    governmentScore?: number
    smartMoneySignal?: string
    governmentSignal?: string
    // SEC analysis
    secManagementChanges?: string[]
    secMaterialContracts?: string[]
    secRiskRemovals?: string[]
    // Job posting signals
    jobAcceleration?: number | null
    jobPostingCount?: number
    // Transcript sentiment
    transcriptSentimentScore?: number | null
    transcriptConfidence?: number
    // Short reports
    shortReportFound?: boolean
    shortThesisContradicted?: boolean
    // ── Phase 2 signal expansion ──
    analystRevisionsMomentum?: number | null
    analystRevisionsUp?: number
    analystRevisionsDown?: number
    shortSqueezePct?: number | null
    daysToCover?: number | null
    floatPct?: number | null
    buybackActive?: boolean
    sharesChangePct?: number | null
    sharesRepurchasedPct?: number
    dividendInitiated?: boolean
    dividendYieldPct?: number | null
    payoutRatio?: number | null
    redditMentionVelocity?: number | null
    redditSentiment?: string
    impliedVol?: number | null
    ivExpansionPct?: number | null
    putCallRatio?: number | null
    form3NewInsiders?: string[]
    form5UnreportedVolume?: number
    peerBeatsCount?: number
    peerMissesCount?: number
    sectorMomentum?: number | null
    boardChanges?: number
    debtMaturitiesNext12M?: number | null
    refinancingRisk?: string
    // ── Asymmetry decay / window status ──
    windowStatus?: string
    asymmetryOpenScore?: number
    asymmetryDecayReasons?: string[]
    expiresAt?: string
    radarV2Shadow?: unknown
    scoreBreakdown?: unknown
    repriceGap?: unknown
    councilExplanation?: unknown
    regimeFlags?: string[]
  },
): RadarRow {
  return {
    ticker: structured.ticker,
    tier: neutral.tier,
    overall_score: neutral.score,
    thesis: structured.bluf,
    gemini_analysis: neutral.verdict,
    score_breakdown: enrichment?.scoreBreakdown,
    reprice_gap: enrichment?.repriceGap,
    council_explanation: enrichment?.councilExplanation,
    regime_flags: enrichment?.regimeFlags,
    data_snapshot: {
      company_name: structured.companyName,
      sector: structured.sector,
      triple_signal: neutral.tripleSignal,
      price: structured.price,
      upside: structured.upside,
      market_cap: structured.marketCap,
      probability: structured.probability,
      catalyst: structured.catalyst,
      detection_lane: structured.detectionLane || 'General Research',
      council: {
        gemini: bull.verdict,
        deepseek: bear.verdict,
        grok: 'N/A',
        cio: neutral.verdict,
      },
      narrative_velocity: 0,
      buy_zones: {
        aggressive: structured.buyZones.aggressive,
        base: structured.buyZones.base,
        conservative: structured.buyZones.conservative,
      },
      bull_case: structured.bullCase,
      bear_case: structured.bearCase,
      financials: dedupeFinancials(structured.financials),
      red_flags: structured.redFlags,
      invalidation: structured.invalidation,
      full_report_md: structured.fullReportMd,
      asymmetry_score: neutral.asymmetry ?? 5,
      conviction_score: neutral.conviction ?? 5,
      catalyst_score: neutral.catalyst ?? 5,
      management_score: neutral.management ?? 5,
      analyst_ai_divergence: false,
      // Qualtrim-style competitive analysis
      competitive_advantages: structured.competitiveAdvantages || '',
      investment_risks: structured.investmentRisks || '',
      key_metrics: {
        pe_trailing: structured.keyMetrics?.peTrailing || '',
        pe_forward: structured.keyMetrics?.peForward || '',
        ev_ebitda: structured.keyMetrics?.evEbitda || '',
        gross_margin: structured.keyMetrics?.grossMargin || '',
        operating_margin: structured.keyMetrics?.operatingMargin || '',
        dividend_yield: structured.keyMetrics?.dividendYield || '',
        beta: structured.keyMetrics?.beta || '',
      },
      price_history: enrichment?.priceHistory ?? [],
      rsi_value: enrichment?.rsiValue,
      rsi_signal: enrichment?.rsiSignal,
      macd_trend: enrichment?.macdTrend,
      volume_vs_avg: enrichment?.volumeRatio,
      support_level: enrichment?.supportLevel,
      resistance_level: enrichment?.resistanceLevel,
      recent_headlines: enrichment?.recentHeadlines ?? [],
      upcoming_events: enrichment?.upcomingEvents ?? [],
      analyst_consensus: enrichment?.analystConsensusString ?? '',
      analyst_count: enrichment?.analystCount ?? 0,
      avg_price_target: enrichment?.avgPriceTarget ?? 0,
      recent_analyst_actions: enrichment?.recentAnalystActions ?? [],
      council_summary: enrichment?.councilSummary ?? '',
      // Insider activity
      insider_total_buys: enrichment?.insiderTotalBuys ?? 0,
      insider_total_sells: enrichment?.insiderTotalSells ?? 0,
      insider_buy_volume: enrichment?.insiderBuyVolume ?? 0,
      insider_sell_volume: enrichment?.insiderSellVolume ?? 0,
      insider_buying_names: enrichment?.insiderBuyingNames ?? [],
      insider_selling_names: enrichment?.insiderSellingNames ?? [],
      insider_cluster_score: enrichment?.insiderClusterScore ?? 0,
      insider_net_sentiment: enrichment?.insiderNetSentiment ?? '',
      insider_signal: enrichment?.insiderSignal ?? '',
      insider_transactions: enrichment?.insiderTransactions ?? [],
      // New fundamental quality signals
      rev_acceleration: enrichment?.revAcceleration ?? null,
      insider_pct: enrichment?.insiderPct ?? null,
      gaap_quality_score: enrichment?.gaapQualityScore ?? null,
      earnings_miss_count: enrichment?.earningsMissCount ?? 0,
      tags: enrichment?.tags ?? [],
      peer_percentile_rank: enrichment?.peerPercentileRank,
      peer_verdict: enrichment?.peerVerdict,
      contrarian_score: enrichment?.contrarian,
      smart_money_score: enrichment?.smartMoneyScore,
      government_score: enrichment?.governmentScore,
      smart_money_signal: enrichment?.smartMoneySignal,
      government_signal: enrichment?.governmentSignal,
      sec_management_changes: enrichment?.secManagementChanges,
      sec_material_contracts: enrichment?.secMaterialContracts,
      sec_risk_removals: enrichment?.secRiskRemovals,
      job_acceleration: enrichment?.jobAcceleration,
      job_posting_count: enrichment?.jobPostingCount,
      transcript_sentiment_score: enrichment?.transcriptSentimentScore,
      transcript_confidence: enrichment?.transcriptConfidence,
      short_report_found: enrichment?.shortReportFound,
      short_thesis_contradicted: enrichment?.shortThesisContradicted,
      // ── Phase 2 signal expansion ──
      analyst_revisions_momentum: enrichment?.analystRevisionsMomentum ?? null,
      analyst_revisions_up: enrichment?.analystRevisionsUp,
      analyst_revisions_down: enrichment?.analystRevisionsDown,
      short_squeeze_pct: enrichment?.shortSqueezePct ?? null,
      days_to_cover: enrichment?.daysToCover ?? null,
      float_pct: enrichment?.floatPct ?? null,
      buyback_active: enrichment?.buybackActive,
      shares_change_pct: enrichment?.sharesChangePct ?? null,
      shares_repurchased_pct: enrichment?.sharesRepurchasedPct,
      dividend_initiated: enrichment?.dividendInitiated,
      dividend_yield_pct: enrichment?.dividendYieldPct ?? null,
      payout_ratio: enrichment?.payoutRatio ?? null,
      reddit_mention_velocity: enrichment?.redditMentionVelocity ?? null,
      reddit_sentiment: enrichment?.redditSentiment,
      implied_vol: enrichment?.impliedVol ?? null,
      iv_expansion_pct: enrichment?.ivExpansionPct ?? null,
      put_call_ratio: enrichment?.putCallRatio ?? null,
      form3_new_insiders: enrichment?.form3NewInsiders,
      form5_unreported_volume: enrichment?.form5UnreportedVolume,
      peer_beats_count: enrichment?.peerBeatsCount,
      peer_misses_count: enrichment?.peerMissesCount,
      sector_momentum: enrichment?.sectorMomentum ?? null,
      board_changes: enrichment?.boardChanges,
      debt_maturities_next_12m: enrichment?.debtMaturitiesNext12M ?? null,
      refinancing_risk: enrichment?.refinancingRisk,
      // ── Asymmetry decay / window status ──
      window_status: enrichment?.windowStatus,
      asymmetry_open_score: enrichment?.asymmetryOpenScore,
      asymmetry_decay_reasons: enrichment?.asymmetryDecayReasons,
      expires_at: enrichment?.expiresAt,
      radar_v2_shadow: enrichment?.radarV2Shadow,
    },
  }
}

/**
 * Generic brace-counting JSON extractor — safe for LLM markdown output.
 * Finds the first top-level JSON object in any text, even with nested braces
 * and surrounding markdown/code fences. Not regex-based.
 */
export function parseJsonBlock(text: string): Record<string, any> | null {
  const start = text.indexOf('{')
  if (start === -1) return null
  let depth = 0
  for (let i = start; i < text.length; i++) {
    if (text[i] === '{') depth++
    else if (text[i] === '}') {
      depth--
      if (depth === 0) {
        try { return JSON.parse(text.slice(start, i + 1)) } catch { return null }
      }
    }
  }
  return null
}

export function extractJsonBlock(text: string): StructuredOpportunity | null {
  const parsed = parseJsonBlock(text)
  if (!parsed) {
    console.error('No JSON block found in radar output')
    return null
  }

  try {
    return {
      ticker: parsed.ticker?.replace('$', '') ?? 'UNKNOWN',
      companyName: parsed.companyName ?? parsed.ticker ?? 'Unknown',
      sector: parsed.sector ?? '',
      detectionLane: parsed.detectionLane ?? parsed.detection_lane ?? 'General Research',
      tier: parsed.tier ?? 2,
      score: parsed.score ?? 50,
      tripleSignal: parsed.tripleSignal ?? false,
      bluf: parsed.bluf ?? parsed.thesis ?? '',
      price: parsed.price ?? 0,
      upside: parsed.upside ?? 0,
      marketCap: String(parsed.marketCap ?? 'N/A'),
      probability: parsed.probability ?? 50,
      catalyst: parsed.catalyst ?? '',
      council: { gemini: 'BULL', deepseek: 'BULL', grok: 'BULL', cio: 'BULL' },
      buyZones: {
        aggressive: parsed.buyZones?.aggressive ?? 0,
        base: parsed.buyZones?.base ?? 0,
        conservative: parsed.buyZones?.conservative ?? 0,
      },
      bullCase: parsed.bullCase ?? '',
      bearCase: parsed.bearCase ?? '',
      financials: dedupeFinancials(parsed.financials ?? []),
      redFlags: parsed.redFlags ?? [],
      invalidation: parsed.invalidation ?? '',
      fullReportMd: text,
      narrativeVelocity: parsed.narrativeVelocity,
      competitiveAdvantages: parsed.competitiveAdvantages ?? parsed.competitive_advantages ?? '',
      investmentRisks: parsed.investmentRisks ?? parsed.investment_risks ?? '',
      keyMetrics: parsed.keyMetrics ?? parsed.key_metrics ?? undefined,
    }
  } catch (err) {
    console.error('Failed to parse JSON block:', err)
    return null
  }
}
