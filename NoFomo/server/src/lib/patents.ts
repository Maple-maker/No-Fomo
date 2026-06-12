// Patent velocity — detects R&D acceleration 12-24 months before earnings inflection.
// Uses free USPTO PatentsView API (no auth required). Degrades gracefully.

export interface PatentSignal {
  acceleration: number | null
  totalFilings: number
  citationDensity: number
  recentFilingsQ4: number
  priorFilingsQ4: number
  signal: string
}

const ASSIGNEE_NAMES: Record<string, string[]> = {
  NVDA: ['NVIDIA', 'NVIDIA CORPORATION'], PLTR: ['PALANTIR', 'PALANTIR TECHNOLOGIES'],
  AMD: ['ADVANCED MICRO', 'AMD'], KTOS: ['KRATOS', 'KRATOS DEFENSE'], AVAV: ['AEROVIRONMENT'],
  ALAB: ['ASTERA', 'ASTERA LABS'], MU: ['MICRON', 'MICRON TECHNOLOGY'], RKLB: ['ROCKET LAB', 'ROCKET'],
  TSLA: ['TESLA', 'TESLA MOTORS'], AAPL: ['APPLE', 'APPLE INC'], MSFT: ['MICROSOFT', 'MICROSOFT CORPORATION'],
  GOOG: ['GOOGLE', 'ALPHABET', 'GOOGLE LLC'], META: ['FACEBOOK', 'META', 'META PLATFORMS'],
  AMZN: ['AMAZON', 'AMAZON TECHNOLOGIES'], QCOM: ['QUALCOMM', 'QUALCOMM INCORPORATED'], ARM: ['ARM', 'ARM HOLDINGS'],
}

export async function getPatentAcceleration(ticker: string, companyName?: string): Promise<PatentSignal> {
  const empty = (signal: string): PatentSignal => ({ acceleration: null, totalFilings: 0, citationDensity: 0, recentFilingsQ4: 0, priorFilingsQ4: 0, signal })
  try {
    const assignees = ASSIGNEE_NAMES[ticker] || [companyName || ticker]
    const query = JSON.stringify({ assignee_name: assignees[0] })
    const url = `https://api.patentsview.org/patents/query?q=${encodeURIComponent(query)}&f=["patent_id","patent_date","patent_title","assignee_name","num_claims"]&o={"page":1,"per_page":100}`

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 8000)
    const response = await fetch(url, { headers: { 'User-Agent': 'NoFomo/1.0', Accept: 'application/json' }, signal: controller.signal })
    clearTimeout(timeoutId)

    if (!response.ok || response.headers.get('content-type')?.includes('text/html')) return empty('Patent data unavailable')

    const data = (await response.json()) as { patents?: Array<{ patent_date: string; num_claims?: number }> }
    const patents = data.patents || []
    if (patents.length === 0) return empty('No patents found')

    const now = new Date()
    const currentYear = now.getFullYear()
    const priorYearQ4Start = new Date(currentYear - 1, 9, 1)
    const priorYearQ4End = new Date(currentYear, 0, 0)
    const currentYearQ4Start = new Date(currentYear, 9, 1)
    const currentYearQ4End = new Date(currentYear + 1, 0, 0)

    let recentQ4 = 0, priorQ4 = 0, totalClaims = 0
    for (const patent of patents) {
      const filingDate = new Date(patent.patent_date)
      const claims = patent.num_claims || 20
      if (filingDate >= currentYearQ4Start && filingDate < currentYearQ4End) { recentQ4++; totalClaims += claims }
      else if (filingDate >= priorYearQ4Start && filingDate < priorYearQ4End) priorQ4++
    }

    let acceleration: number | null = null
    if (priorQ4 > 0) acceleration = ((recentQ4 - priorQ4) / priorQ4) * 100
    const citationDensity = totalClaims / Math.max(recentQ4, 1)

    return {
      acceleration, totalFilings: patents.length, citationDensity, recentFilingsQ4: recentQ4, priorFilingsQ4: priorQ4,
      signal: acceleration && acceleration > 20 ? `📈 Patent acceleration +${Math.round(acceleration)}% YoY`
        : acceleration && acceleration > 0 ? `Patent filing growth +${Math.round(acceleration)}%` : 'No significant patent acceleration',
    }
  } catch (error) {
    console.error('Patent acceleration fetch error:', error)
    return empty('Patent check unavailable')
  }
}
