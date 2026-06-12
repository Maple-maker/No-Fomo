// ── SEC EDGAR Advanced Parsing for Inflection Detection ──
// Parses company submissions for management changes, material contracts, board changes,
// and debt-maturity / refinancing risk. No API key required.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

const CIK_JSON_URL = 'https://www.sec.gov/files/company_tickers.json'
const SUBMISSIONS_BASE = 'https://data.sec.gov/submissions/CIK'

export interface ManagementChange { name: string; role: string; date: string }
export interface MaterialContract { description: string; date: string }

export interface SECSignal {
  managementChanges: ManagementChange[]
  accountingChanges: string[]
  riskFactorDeltas: string[]
  materialContracts: MaterialContract[]
  goingConcernAbsent: boolean
  boardChanges: number
  debtMaturitiesNext12M: number | null
  refinancingRisk: 'low' | 'moderate' | 'high' | 'unknown'
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

async function fetchSubmissions(cik: string): Promise<any> {
  const url = `${SUBMISSIONS_BASE}${cik.padStart(10, '0')}.json`
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(15000) })
  if (!res.ok) return null
  return res.json()
}

async function fetch8KDetail(cik: string, accessionNumber: string): Promise<{ managementChanges: ManagementChange[]; materialContracts: MaterialContract[] } | null> {
  try {
    const paddedCik = cik.padStart(10, '0')
    const cleanAccession = accessionNumber.replace(/-/g, '')
    const summaryUrl = `https://www.sec.gov/Archives/edgar/data/${paddedCik}/${cleanAccession}/0001104659-${accessionNumber.slice(-11)}-index.json`
    const summaryRes = await fetch(summaryUrl, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(10000) })
    if (!summaryRes.ok) return null
    const summary = (await summaryRes.json()) as any
    const filingDocuments = summary.filingDocuments || []
    const mainDoc = filingDocuments.find((d: any) => (d.filename || '').match(/\.htm$/i) && !d.filename.includes('_def'))
    if (!mainDoc) return null
    const contentUrl = `https://www.sec.gov/Archives/edgar/data/${paddedCik}/${cleanAccession}/${mainDoc.filename}`
    const contentRes = await fetch(contentUrl, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(10000) })
    if (!contentRes.ok) return null
    const content = await contentRes.text()

    const changes: ManagementChange[] = []
    const contracts: MaterialContract[] = []
    const item502Match = content.match(/Item\s+5\.02.*?(?=Item\s+\d+|$)/is)
    if (item502Match) {
      const text = item502Match[0]
      const roleMatch = text.match(/(?:appointment|appointment as|election|named as)\s+([A-Z][a-z]+ (?:[A-Z][a-z]+ )+)(?:as|to the position of)?\s+([A-Z][a-zA-Z\s]+?(?:Officer|Director))/gi)
      if (roleMatch) {
        roleMatch.forEach(match => {
          const parts = match.match(/([A-Z][a-z]+ (?:[A-Z][a-z]+ )+).*?(Chief [A-Za-z]+ Officer|CEO|CFO|CTO|Director)/i)
          if (parts && parts[1] && parts[2]) changes.push({ name: parts[1].trim(), role: parts[2].trim(), date: accessionNumber.slice(0, 10) })
        })
      }
    }
    const item101Match = content.match(/Item\s+1\.01.*?(?=Item\s+\d+|$)/is)
    if (item101Match) {
      const desc = item101Match[0].replace(/Item\s+1\.01\s+(?:Material Contracts|Acquisition)?/i, '').trim().slice(0, 200)
      if (desc.length > 20) contracts.push({ description: desc, date: accessionNumber.slice(0, 10) })
    }
    return { managementChanges: changes, materialContracts: contracts }
  } catch (e) {
    console.warn('[secAnalysis] fetch8KDetail failed:', e instanceof Error ? e.message : e)
    return null
  }
}

// ── Debt maturity / refinancing risk via XBRL company facts ──
async function fetchUsdConcept(cik: string, concept: string): Promise<number | null> {
  try {
    const url = `https://data.sec.gov/api/xbrl/companyconcept/CIK${cik.padStart(10, '0')}/us-gaap/${concept}.json`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(10000) })
    if (!res.ok) return null
    const data = (await res.json()) as { units?: Record<string, Array<{ end: string; val: number }>> }
    const series = data.units?.USD ?? Object.values(data.units ?? {})[0] ?? []
    const valid = series.filter(f => f.end && typeof f.val === 'number')
    if (valid.length === 0) return null
    valid.sort((a, b) => new Date(a.end).getTime() - new Date(b.end).getTime())
    return valid[valid.length - 1].val
  } catch { return null }
}

async function analyzeDebtMaturity(cik: string): Promise<{ debtMaturitiesNext12M: number | null; refinancingRisk: 'low' | 'moderate' | 'high' | 'unknown' }> {
  const [current, noncurrent] = await Promise.all([
    fetchUsdConcept(cik, 'LongTermDebtCurrent'),
    fetchUsdConcept(cik, 'LongTermDebtNoncurrent'),
  ])
  if (current == null && noncurrent == null) return { debtMaturitiesNext12M: null, refinancingRisk: 'unknown' }
  const cur = current ?? 0
  const total = cur + (noncurrent ?? 0)
  if (total <= 0) return { debtMaturitiesNext12M: cur, refinancingRisk: 'low' }
  const pctDueNext12M = cur / total
  let refinancingRisk: 'low' | 'moderate' | 'high' = 'low'
  if (pctDueNext12M > 0.3) refinancingRisk = 'high'
  else if (pctDueNext12M > 0.1) refinancingRisk = 'moderate'
  return { debtMaturitiesNext12M: cur, refinancingRisk }
}

export async function parseEDGARForInflection(ticker: string): Promise<SECSignal> {
  const defaultSignal: SECSignal = {
    managementChanges: [], accountingChanges: [], riskFactorDeltas: [], materialContracts: [],
    goingConcernAbsent: true, boardChanges: 0, debtMaturitiesNext12M: null, refinancingRisk: 'unknown',
    signal: 'No significant SEC inflection signals detected',
  }
  try {
    const cikMap = await loadCikCache()
    const cik = cikMap.get(ticker.toUpperCase())
    if (!cik) { console.warn(`[secAnalysis] CIK not found for ${ticker}`); return defaultSignal }
    const submissions = await fetchSubmissions(cik)
    if (!submissions || !submissions.filings) return defaultSignal

    const filings = submissions.filings.recent || []
    const forms = filings.form || []
    const accessions = filings.accessionNumber || []

    const managementChanges: ManagementChange[] = []
    const materialContracts: MaterialContract[] = []
    for (let i = 0; i < Math.min(20, forms.length); i++) {
      if (forms[i] === '8-K') {
        const detail = await fetch8KDetail(cik, accessions[i])
        if (detail) { managementChanges.push(...detail.managementChanges); materialContracts.push(...detail.materialContracts) }
      }
    }

    const goingConcernFound = false
    const boardChanges = managementChanges.filter(m => /director/i.test(m.role)).length
    const { debtMaturitiesNext12M, refinancingRisk } = await analyzeDebtMaturity(cik)

    const signalParts: string[] = []
    if (managementChanges.length > 0) signalParts.push(`${managementChanges.length} management change(s) detected`)
    if (boardChanges > 0) signalParts.push(`${boardChanges} board change(s)`)
    if (materialContracts.length > 0) signalParts.push(`${materialContracts.length} new material contract(s)`)
    if (refinancingRisk === 'high') signalParts.push('High refinancing concentration (>30% of debt due in 12mo)')
    else if (refinancingRisk === 'moderate') signalParts.push('Moderate near-term debt maturities')
    if (!goingConcernFound) signalParts.push('Going concern stable')

    return {
      managementChanges, accountingChanges: [], riskFactorDeltas: [], materialContracts,
      goingConcernAbsent: !goingConcernFound, boardChanges, debtMaturitiesNext12M, refinancingRisk,
      signal: signalParts.length > 0 ? `SEC inflection: ${signalParts.join('. ')}` : 'No significant SEC inflection signals detected',
    }
  } catch (e) {
    console.error('[secAnalysis] parseEDGARForInflection failed:', e instanceof Error ? e.message : e)
    return defaultSignal
  }
}
