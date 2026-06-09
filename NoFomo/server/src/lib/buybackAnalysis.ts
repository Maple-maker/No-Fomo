// ── Stock Buyback / Dilution Tracking ──
// Net share reduction = buyback (confidence + undervaluation). Net increase = dilution.
// Source: SEC EDGAR XBRL company-concept API (free, no key). Honest: no repurchase price invented.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const CIK_JSON_URL = 'https://www.sec.gov/files/company_tickers.json'
const XBRL_CONCEPT = 'https://data.sec.gov/api/xbrl/companyconcept/CIK'

export interface BuybackSignal {
  buybackActive: boolean
  sharesChangePct: number | null
  sharesRepurchasedPct: number
  currentShares: number | null
  priorShares: number | null
  signal: string
}

let cikCache: Map<string, string> | null = null
async function loadCikCache(): Promise<Map<string, string>> {
  if (cikCache) return cikCache
  const res = await fetch(CIK_JSON_URL, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(10000) })
  if (!res.ok) throw new Error(`CIK lookup HTTP ${res.status}`)
  const data = (await res.json()) as Record<string, any>
  cikCache = new Map()
  for (const key of Object.keys(data)) {
    const entry = data[key]
    const ticker = (entry.ticker as string)?.toUpperCase()
    const cik = String(entry.cik_str ?? entry.cik ?? '').padStart(10, '0')
    if (ticker && cik) cikCache.set(ticker, cik)
  }
  return cikCache
}

interface XbrlFact { end: string; val: number; form?: string }

async function fetchShareConcept(cik: string, concept: string, ns: string): Promise<XbrlFact[]> {
  const url = `${XBRL_CONCEPT}${cik}/${ns}/${concept}.json`
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(12000) })
  if (!res.ok) return []
  const data = (await res.json()) as { units?: Record<string, XbrlFact[]> }
  const series = data.units?.shares ?? Object.values(data.units ?? {})[0] ?? []
  return series.filter(f => f.end && typeof f.val === 'number' && f.val > 0)
}

const defaultSignal: BuybackSignal = {
  buybackActive: false, sharesChangePct: null, sharesRepurchasedPct: 0,
  currentShares: null, priorShares: null, signal: 'No buyback data available',
}

export async function analyzeBuybacks(ticker: string): Promise<BuybackSignal> {
  try {
    const cikMap = await loadCikCache()
    const cik = cikMap.get(ticker.toUpperCase())
    if (!cik) return defaultSignal

    let facts = await fetchShareConcept(cik, 'EntityCommonStockSharesOutstanding', 'dei')
    if (facts.length < 2) facts = await fetchShareConcept(cik, 'CommonStockSharesOutstanding', 'us-gaap')
    if (facts.length < 2) return defaultSignal

    const sorted = [...facts].sort((a, b) => new Date(a.end).getTime() - new Date(b.end).getTime())
    const current = sorted[sorted.length - 1]
    const currentEnd = new Date(current.end).getTime()
    const oneYear = 365 * 24 * 60 * 60 * 1000
    let prior: XbrlFact | null = null
    let bestDelta = Infinity
    for (const f of sorted.slice(0, -1)) {
      const gap = currentEnd - new Date(f.end).getTime()
      if (gap <= 0) continue
      const delta = Math.abs(gap - oneYear)
      if (delta < bestDelta) { bestDelta = delta; prior = f }
    }
    if (!prior || bestDelta > 120 * 24 * 60 * 60 * 1000) prior = sorted[0]
    if (!prior || prior.val <= 0) return defaultSignal

    const sharesChangePct = Math.round(((current.val - prior.val) / prior.val) * 10000) / 100
    const buybackActive = sharesChangePct < -0.5
    const sharesRepurchasedPct = buybackActive ? Math.abs(sharesChangePct) : 0

    let signal: string
    if (buybackActive && sharesRepurchasedPct >= 5) signal = `💰 Aggressive buyback: shares −${sharesRepurchasedPct}% YoY — high management conviction`
    else if (buybackActive) signal = `Buyback active: shares −${sharesRepurchasedPct}% YoY`
    else if (sharesChangePct > 5) signal = `⚠️ Heavy dilution: shares +${sharesChangePct}% YoY`
    else if (sharesChangePct > 0.5) signal = `Mild dilution: shares +${sharesChangePct}% YoY`
    else signal = 'Share count stable'

    return { buybackActive, sharesChangePct, sharesRepurchasedPct, currentShares: current.val, priorShares: prior.val, signal }
  } catch (e) {
    console.warn(`[buyback] ${ticker} failed:`, e instanceof Error ? e.message : e)
    return defaultSignal
  }
}
