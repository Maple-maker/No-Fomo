// ── SEC EDGAR Form 4 Insider Trading Tool ──
// Free, no API key required. Fetches recent insider transactions and detects buying clusters.
// Also scans Form 3 (new insider registrations) and Form 5 (late-disclosed annual transactions).

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

const CIK_JSON_URL = 'https://www.sec.gov/files/company_tickers.json'
const EDGAR_BROWSE = 'https://www.sec.gov/cgi-bin/browse-edgar'

export interface InsiderTransaction {
  insiderName: string
  relationship: string
  transactionType: 'P' | 'S' | 'A' | 'D' | 'M' | 'F' | 'G' | 'OTHER'
  transactionCode: string
  shares: number
  pricePerShare: number | null
  sharesOwnedAfter: number | null
  filingDate: string
  transactionDate: string | null
  isDerivative: boolean
}

export interface InsiderResult {
  ticker: string
  cik: string
  transactions: InsiderTransaction[]
  totalBuys: number
  totalSells: number
  buyVolume: number
  sellVolume: number
  buyingInsiders: string[]
  sellingInsiders: string[]
  clusterScore: number
  netInsiderSentiment: 'bullish' | 'bearish' | 'neutral'
  signal: string
  ceoPersonalBuyingScore?: number
  founderAlignment?: boolean
  plan10b5_1Sales?: number
  form3Insiders?: string[]
  form5UnreportedVolume?: number
}

let cikCache: Map<string, string> | null = null

async function loadCikCache(): Promise<Map<string, string>> {
  if (cikCache) return cikCache
  const res = await fetch(CIK_JSON_URL, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(10000) })
  if (!res.ok) throw new Error(`CIK lookup HTTP ${res.status}`)
  const data = await res.json() as Record<string, any>
  cikCache = new Map()
  for (const key of Object.keys(data)) {
    const entry = data[key]
    const ticker = (entry.ticker as string)?.toUpperCase()
    const cik = String(entry.cik_str ?? entry.cik ?? '').padStart(10, '0')
    if (ticker && cik) cikCache.set(ticker, cik)
  }
  console.log(`[insider] Loaded ${cikCache.size} CIK mappings`)
  return cikCache
}

async function fetchRecentForm4(cik: string): Promise<InsiderTransaction[]> {
  const url = `${EDGAR_BROWSE}?action=getcompany&CIK=${cik}&type=4&dateb=&owner=only&count=40&output=atom`
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/atom+xml' }, signal: AbortSignal.timeout(15000) })
  if (!res.ok) throw new Error(`EDGAR browse HTTP ${res.status}`)
  const xml = await res.text()
  const entries = xml.match(/<entry>[\s\S]*?<\/entry>/g) || []
  const transactions: InsiderTransaction[] = []
  for (const entry of entries) {
    try {
      const titleMatch = entry.match(/<title[^>]*>([\s\S]*?)<\/title>/)
      const summaryMatch = entry.match(/<summary[^>]*>([\s\S]*?)<\/summary>/)
      const dateMatch = entry.match(/<updated[^>]*>([^<]+)<\/updated>/)
      const title = titleMatch?.[1]?.trim() || ''
      const summary = summaryMatch?.[1]?.trim() || ''
      const filingDate = dateMatch?.[1]?.slice(0, 10) || ''
      const nameFromTitle = parseInsiderName(title)
      if (!nameFromTitle) continue
      const { code, price, shares } = parseTransactionMetadata(summary, title)
      transactions.push({
        insiderName: nameFromTitle.name,
        relationship: nameFromTitle.role || 'unknown',
        transactionType: code === 'P' ? 'P' : code === 'S' ? 'S' : 'OTHER',
        transactionCode: code,
        shares,
        pricePerShare: price,
        sharesOwnedAfter: null,
        filingDate,
        transactionDate: null,
        isDerivative: nameFromTitle.isDerivative,
      })
    } catch { /* skip malformed */ }
  }
  return transactions
}

function parseInsiderName(title: string): { name: string; role: string; isDerivative: boolean } | null {
  const match = title.match(/^([^(]+)\s*\(([^)]*)\)/)
  if (!match) return null
  const name = match[1].trim()
  const role = match[2].trim().toLowerCase()
  const isDerivative = role.includes('option') || role.includes('derivative')
  return { name, role, isDerivative }
}

function parseTransactionMetadata(summary: string, title: string): { code: string; price: number | null; shares: number } {
  let code = 'OTHER'
  let price: number | null = null
  let shares = 0
  const codeMatch = summary.match(/transaction\s+code[:\s]+([A-Z])/i) || title.match(/\(([A-Z])\)\s*$/)
  if (codeMatch) code = codeMatch[1].toUpperCase()
  const sharesMatch = summary.match(/(\d[\d,]*)\s*shares/i)
  if (sharesMatch) shares = parseInt(sharesMatch[1].replace(/,/g, ''), 10)
  const priceMatch = summary.match(/\$\s*([\d.]+)/)
  if (priceMatch) price = parseFloat(priceMatch[1])
  return { code, price, shares }
}

// ── Form 3 (initial statement of ownership) — new insider registrations ──
async function fetchRecentForm3(cik: string): Promise<string[]> {
  try {
    const url = `${EDGAR_BROWSE}?action=getcompany&CIK=${cik}&type=3&dateb=&owner=only&count=20&output=atom`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/atom+xml' }, signal: AbortSignal.timeout(15000) })
    if (!res.ok) return []
    const xml = await res.text()
    const entries = xml.match(/<entry>[\s\S]*?<\/entry>/g) || []
    const now = Date.now()
    const ninetyDays = 90 * 24 * 60 * 60 * 1000
    const insiders: string[] = []
    for (const entry of entries) {
      const titleMatch = entry.match(/<title[^>]*>([\s\S]*?)<\/title>/)
      const dateMatch = entry.match(/<updated[^>]*>([^<]+)<\/updated>/)
      const filingDate = dateMatch?.[1]?.slice(0, 10) || ''
      if (filingDate) {
        const filingMs = new Date(filingDate).getTime()
        if (Number.isFinite(filingMs) && now - filingMs > ninetyDays) continue
      }
      const parsed = parseInsiderName(titleMatch?.[1]?.trim() || '')
      if (parsed) insiders.push(`${parsed.name} (${parsed.role})`)
    }
    return [...new Set(insiders)]
  } catch { return [] }
}

// ── Form 5 (annual statement) — late-disclosed transactions ──
async function fetchRecentForm5Volume(cik: string): Promise<number> {
  try {
    const url = `${EDGAR_BROWSE}?action=getcompany&CIK=${cik}&type=5&dateb=&owner=only&count=20&output=atom`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/atom+xml' }, signal: AbortSignal.timeout(15000) })
    if (!res.ok) return 0
    const xml = await res.text()
    const entries = xml.match(/<entry>[\s\S]*?<\/entry>/g) || []
    const now = Date.now()
    const oneYear = 365 * 24 * 60 * 60 * 1000
    let volume = 0
    for (const entry of entries) {
      const summaryMatch = entry.match(/<summary[^>]*>([\s\S]*?)<\/summary>/)
      const titleMatch = entry.match(/<title[^>]*>([\s\S]*?)<\/title>/)
      const dateMatch = entry.match(/<updated[^>]*>([^<]+)<\/updated>/)
      const filingDate = dateMatch?.[1]?.slice(0, 10) || ''
      if (filingDate) {
        const filingMs = new Date(filingDate).getTime()
        if (Number.isFinite(filingMs) && now - filingMs > oneYear) continue
      }
      const { shares } = parseTransactionMetadata(summaryMatch?.[1]?.trim() || '', titleMatch?.[1]?.trim() || '')
      volume += shares
    }
    return volume
  } catch { return 0 }
}

function analyzeInsider(ticker: string, cik: string, transactions: InsiderTransaction[]): InsiderResult {
  const buys = transactions.filter(t => t.transactionCode === 'P' && !t.isDerivative)
  const sells = transactions.filter(t => t.transactionCode === 'S' && !t.isDerivative)
  const derivativeBuys = transactions.filter(t => t.transactionCode === 'A' && t.isDerivative)
  const buyingInsiders = [...new Set(buys.map(t => t.insiderName))]
  const sellingInsiders = [...new Set(sells.map(t => t.insiderName))]

  const now = Date.now()
  const sixtyDays = 60 * 24 * 60 * 60 * 1000
  const recentBuys = buys.filter(t => now - new Date(t.filingDate).getTime() < sixtyDays)
  const uniqueRecentBuyers = [...new Set(recentBuys.map(t => t.insiderName))]
  const clusterScore = Math.min(10, Math.round(uniqueRecentBuyers.length * 3.33))

  let netInsiderSentiment: 'bullish' | 'bearish' | 'neutral' = 'neutral'
  const buyVol = buys.reduce((s, t) => s + t.shares, 0)
  const sellVol = sells.reduce((s, t) => s + t.shares, 0)
  if (buyingInsiders.length > sellingInsiders.length && buyVol > 0) netInsiderSentiment = 'bullish'
  else if (sellingInsiders.length > buyingInsiders.length && sellVol > buyVol * 2) netInsiderSentiment = 'bearish'

  let ceoPersonalBuyingScore = 0
  const ceoPatterns = ['ceo', 'chief executive', 'cfo', 'chief financial', 'cto', 'chief technology']
  const ceoBuyers = recentBuys.filter(t => ceoPatterns.some(p => t.relationship.toLowerCase().includes(p)))
  if (ceoBuyers.length > 0) ceoPersonalBuyingScore = 95
  else if (buyingInsiders.length > 0) ceoPersonalBuyingScore = 70

  const founderBuyCount = recentBuys.filter(t =>
    t.relationship.toLowerCase().includes('director') ||
    t.relationship.toLowerCase().includes('founder') ||
    t.relationship.toLowerCase().includes('10% owner')).length
  const founderAlignment = founderBuyCount >= 2
  const plan10b5_1Sales = sells.length

  let signal = ''
  if (ceoPersonalBuyingScore === 95) signal = `🚨 CEO buying! ${ceoBuyers.length} C-suite purchase(s) detected`
  else if (clusterScore >= 7) signal = `${uniqueRecentBuyers.length} insiders bought recently (cluster score ${clusterScore}/10)`
  else if (buyingInsiders.length > 0) signal = `${buyingInsiders.length} insider(s) buying, ${sellingInsiders.length} selling`
  else if (sellingInsiders.length > 0) signal = `${sellingInsiders.length} insider(s) selling${sellVol > 0 ? ` (${sellVol.toLocaleString()} shares)` : ''}`
  else signal = 'No recent insider activity detected'

  return {
    ticker, cik, transactions,
    totalBuys: buys.length + derivativeBuys.length,
    totalSells: sells.length,
    buyVolume: buyVol, sellVolume: sellVol,
    buyingInsiders, sellingInsiders,
    clusterScore, netInsiderSentiment, signal,
    ceoPersonalBuyingScore, founderAlignment, plan10b5_1Sales,
  }
}

export async function getInsiderData(ticker: string): Promise<InsiderResult> {
  const clean = ticker.toUpperCase().trim()
  const cache = await loadCikCache()
  const cik = cache.get(clean)
  if (!cik) {
    return {
      ticker: clean, cik: '', transactions: [], totalBuys: 0, totalSells: 0,
      buyVolume: 0, sellVolume: 0, buyingInsiders: [], sellingInsiders: [],
      clusterScore: 0, netInsiderSentiment: 'neutral',
      signal: 'CIK not found — ticker may not be registered with SEC',
    }
  }
  const [transactions, form3Insiders, form5UnreportedVolume] = await Promise.all([
    fetchRecentForm4(cik),
    fetchRecentForm3(cik).catch(() => [] as string[]),
    fetchRecentForm5Volume(cik).catch(() => 0),
  ])
  console.log(`[insider] ${clean}: ${transactions.length} Form 4, ${form3Insiders.length} new Form 3 insiders, ${form5UnreportedVolume} Form 5 shares`)
  const result = analyzeInsider(clean, cik, transactions)
  result.form3Insiders = form3Insiders
  result.form5UnreportedVolume = form5UnreportedVolume
  return result
}
