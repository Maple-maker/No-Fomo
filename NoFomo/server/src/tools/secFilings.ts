// ── SEC EDGAR catalyst filing scanner ──
// Monitors a list of tickers via data.sec.gov/submissions (free, no key) and flags
// recent 8-K / S-1 / 424B filings by catalyst category. Used by the discovery pipeline.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

const CIK_JSON_URL = 'https://www.sec.gov/files/company_tickers.json'
const SUBMISSIONS_BASE = 'https://data.sec.gov/submissions/CIK'

export type FilingCategory =
  | 'M&A' | 'government contract' | 'FDA/regulatory' | 'financing'
  | 'partnership/contract' | 'corporate event'

export interface Filing {
  ticker: string
  form: string
  category: FilingCategory
  date: string
  primaryDoc: string
}

export interface SECFilingScan {
  scanned: number
  filings: Filing[]
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

// Map 8-K item codes / form types to a catalyst category.
function categorize(form: string, items: string): FilingCategory {
  const i = items || ''
  if (/1\.01|2\.01/.test(i)) return 'M&A'                    // entry into material agreement / acquisition
  if (/8\.01/.test(i)) return 'corporate event'
  if (/3\.02|3\.03|1\.01.*note|financing/i.test(i)) return 'financing'
  if (form === 'S-1' || form === '424B5' || form === '424B4') return 'financing'
  if (/5\.02/.test(i)) return 'corporate event'
  return 'partnership/contract'
}

async function scanTicker(ticker: string, cik: string, sinceMs: number): Promise<Filing[]> {
  try {
    const url = `${SUBMISSIONS_BASE}${cik.padStart(10, '0')}.json`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(12000) })
    if (!res.ok) return []
    const data = (await res.json()) as any
    const recent = data?.filings?.recent
    if (!recent) return []
    const forms: string[] = recent.form || []
    const dates: string[] = recent.filingDate || []
    const items: string[] = recent.items || []
    const docs: string[] = recent.primaryDocument || []
    const out: Filing[] = []
    for (let i = 0; i < forms.length; i++) {
      const form = forms[i]
      if (!/^(8-K|S-1|424B)/.test(form)) continue
      const d = new Date(dates[i]).getTime()
      if (!Number.isFinite(d) || d < sinceMs) continue
      out.push({ ticker, form, category: categorize(form, items[i] || ''), date: dates[i], primaryDoc: docs[i] || '' })
    }
    return out
  } catch { return [] }
}

/**
 * Scan a list of tickers for catalyst filings in the last `days` days.
 */
export async function scanSECFilings(tickers: string[], days = 14): Promise<SECFilingScan> {
  const cikMap = await loadCikCache().catch(() => null)
  if (!cikMap) return { scanned: 0, filings: [] }
  const sinceMs = Date.now() - days * 24 * 60 * 60 * 1000
  const filings: Filing[] = []
  let scanned = 0
  for (const t of tickers) {
    const cik = cikMap.get(t.toUpperCase())
    if (!cik) continue
    scanned++
    const f = await scanTicker(t.toUpperCase(), cik, sinceMs)
    filings.push(...f)
    await new Promise(r => setTimeout(r, 120)) // SEC rate limit (~10 req/s)
  }
  return { scanned, filings }
}
