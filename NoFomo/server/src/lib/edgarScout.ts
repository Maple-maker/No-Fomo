// ── EDGAR Full-Text Open-Universe Scout ──
// Scouts genuinely NEW tickers market-wide (not from a fixed watchlist) by searching the
// SEC EDGAR full-text index for recent 8-K filings matching high-signal catalyst phrases.
// Free, no key. This is what lets discovery surface names we weren't already watching.

const USER_AGENT = 'NoFomo/1.0 (radar research; research@nofomo.app)'
const EFTS = 'https://efts.sec.gov/LATEST/search-index'

export interface ScoutedTicker {
  ticker: string
  category: string
  title: string
  date: string
}

// High-signal catalyst phrases → category. Each is one EDGAR full-text query.
const CATALYST_QUERIES: Array<{ phrase: string; category: string }> = [
  { phrase: '"awarded a contract"', category: 'government contract' },
  { phrase: '"received FDA approval"', category: 'FDA/regulatory' },
  { phrase: '"definitive merger agreement"', category: 'M&A' },
  { phrase: '"strategic partnership"', category: 'partnership/contract' },
  { phrase: '"record quarterly revenue"', category: 'revenue inflection' },
]

function isoDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
}

// Extract a ticker from an EDGAR display_names entry: "ACME CORP  (ACME)  (CIK 0001234567)".
function extractTicker(displayName: string): string | null {
  const m = displayName.match(/\(([A-Z][A-Z.\-]{0,5})(?:,[^)]*)?\)\s*\(CIK/)
  if (!m) return null
  const t = m[1].split('-')[0] // strip warrant/unit suffixes (VAL-WT → VAL)
  if (t.length < 1 || t.length > 5 || t === 'CIK') return null
  return t
}

async function runQuery(phrase: string, category: string, startdt: string, enddt: string): Promise<ScoutedTicker[]> {
  try {
    const url = `${EFTS}?q=${encodeURIComponent(phrase)}&forms=8-K&startdt=${startdt}&enddt=${enddt}`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' }, signal: AbortSignal.timeout(12000) })
    if (!res.ok) return []
    const data = (await res.json()) as any
    const hits = data?.hits?.hits ?? []
    const out: ScoutedTicker[] = []
    for (const h of hits.slice(0, 30)) {
      const src = h?._source ?? {}
      const names: string[] = src.display_names ?? []
      const date: string = src.file_date ?? ''
      for (const name of names) {
        const ticker = extractTicker(name)
        if (ticker) { out.push({ ticker, category, title: name, date }); break }
      }
    }
    return out
  } catch (e) {
    console.warn(`[edgarScout] query "${phrase}" failed:`, e instanceof Error ? e.message : e)
    return []
  }
}

/**
 * Scout new catalyst-flagged tickers from the whole SEC filing universe over the last N days.
 * Returns a deduped list (best category per ticker). Empty on total failure.
 */
export async function scoutCatalystFilings(daysBack = 10): Promise<ScoutedTicker[]> {
  const startdt = isoDaysAgo(daysBack)
  const enddt = isoDaysAgo(0)

  const byTicker = new Map<string, ScoutedTicker>()
  for (const q of CATALYST_QUERIES) {
    const results = await runQuery(q.phrase, q.category, startdt, enddt)
    for (const r of results) {
      if (!byTicker.has(r.ticker)) byTicker.set(r.ticker, r)
    }
    await new Promise(res => setTimeout(res, 150)) // SEC rate-limit courtesy
  }
  const scouted = [...byTicker.values()]
  console.log(`[edgarScout] ${scouted.length} catalyst-flagged tickers scouted market-wide (${startdt}→${enddt})`)
  return scouted
}
