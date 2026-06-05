import type { StructuredOpportunity, CouncilVerdict, CIOArbiter } from '../agents/types'

type RadarRow = {
  ticker: string
  tier: number
  overall_score: number
  thesis: string
  gemini_analysis: string
  data_snapshot: {
    company_name: string
    sector: string
    triple_signal: boolean
    price: number
    upside: number
    market_cap: string
    probability: number
    catalyst: string
    council: { gemini: string; deepseek: string; cio: string }
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
  }
}

export function buildRadarRow(
  structured: StructuredOpportunity,
  geminiVerdict: CouncilVerdict,
  deepseekVerdict: CouncilVerdict,
  cio: CIOArbiter,
): RadarRow {
  return {
    ticker: structured.ticker,
    tier: cio.tier,
    overall_score: cio.score,
    thesis: structured.bluf,
    gemini_analysis: cio.verdict,
    data_snapshot: {
      company_name: structured.companyName,
      sector: structured.sector,
      triple_signal: cio.tripleSignal,
      price: structured.price,
      upside: structured.upside,
      market_cap: structured.marketCap,
      probability: structured.probability,
      catalyst: structured.catalyst,
      council: {
        gemini: geminiVerdict.verdict,
        deepseek: deepseekVerdict.verdict,
        cio: cio.verdict,
      },
      buy_zones: {
        aggressive: structured.buyZones.aggressive,
        base: structured.buyZones.base,
        conservative: structured.buyZones.conservative,
      },
      bull_case: structured.bullCase,
      bear_case: structured.bearCase,
      financials: structured.financials,
      red_flags: structured.redFlags,
      invalidation: structured.invalidation,
      full_report_md: structured.fullReportMd,
      asymmetry_score: Math.round(cio.score * 0.25),
      conviction_score: Math.round(cio.score * 0.25),
      catalyst_score: Math.round(cio.score * 0.25),
      management_score: Math.round(cio.score * 0.25),
    },
  }
}

export function extractJsonBlock(text: string): StructuredOpportunity | null {
  // Find the JSON block in the markdown output
  const jsonMatch = text.match(/```json\s*([\s\S]*?)\s*```/)
  if (!jsonMatch) {
    console.error('No JSON block found in radar output')
    return null
  }

  try {
    const parsed = JSON.parse(jsonMatch[1])
    return {
      ticker: parsed.ticker?.replace('$', '') ?? 'UNKNOWN',
      companyName: parsed.companyName ?? parsed.ticker ?? 'Unknown',
      sector: parsed.sector ?? '',
      tier: parsed.tier ?? 2,
      score: parsed.score ?? 50,
      tripleSignal: parsed.tripleSignal ?? false,
      bluf: parsed.bluf ?? parsed.thesis ?? '',
      price: parsed.price ?? 0,
      upside: parsed.upside ?? 0,
      marketCap: String(parsed.marketCap ?? 'N/A'),
      probability: parsed.probability ?? 50,
      catalyst: parsed.catalyst ?? '',
      council: { gemini: 'BULL', deepseek: 'BULL', cio: 'BULL' },
      buyZones: {
        aggressive: parsed.buyZones?.aggressive ?? 0,
        base: parsed.buyZones?.base ?? 0,
        conservative: parsed.buyZones?.conservative ?? 0,
      },
      bullCase: parsed.bullCase ?? '',
      bearCase: parsed.bearCase ?? '',
      financials: parsed.financials ?? [],
      redFlags: parsed.redFlags ?? [],
      invalidation: parsed.invalidation ?? '',
      fullReportMd: text,
    }
  } catch (err) {
    console.error('Failed to parse JSON block:', err)
    return null
  }
}
