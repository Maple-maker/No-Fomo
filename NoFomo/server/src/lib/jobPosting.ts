// ── Job Posting Acceleration ──
// Hiring ramp = forward demand signal that leads revenue. We measure job-posting velocity
// (this week vs trailing-month weekly average) via Brave Search over LinkedIn/Indeed results.
// Honest: no scraping of gated boards — we count public search hits only.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const BRAVE_WEB = 'https://api.search.brave.com/res/v1/web/search'

export interface JobSignal {
  acceleration: number | null
  postingCount: number
  departmentBreakdown: Record<string, number>
  signal: string
}

interface BraveHit {
  title?: string
  description?: string
}

const DEPARTMENT_KEYWORDS: Record<string, string[]> = {
  engineering: ['engineer', 'developer', 'software', 'devops', 'platform', 'infrastructure', 'data scientist', 'machine learning'],
  sales: ['sales', 'account executive', 'business development', 'partnerships', 'revenue'],
  operations: ['operations', 'logistics', 'supply chain', 'manufacturing', 'production', 'warehouse'],
  rd: ['research', 'scientist', 'r&d', 'rd', 'principal investigator', 'laboratory'],
}

async function fetchPostings(companyName: string, freshness: 'pw' | 'pm'): Promise<BraveHit[]> {
  const braveKey = process.env.BRAVE_API_KEY
  if (!braveKey) return []
  const query = `"${companyName}" hiring jobs (site:linkedin.com OR site:indeed.com)`
  const res = await fetch(
    `${BRAVE_WEB}?q=${encodeURIComponent(query)}&count=50&freshness=${freshness}`,
    {
      headers: { Accept: 'application/json', 'User-Agent': USER_AGENT, 'X-Subscription-Token': braveKey },
      signal: AbortSignal.timeout(9000),
    },
  )
  if (!res.ok) throw new Error(`Brave HTTP ${res.status}`)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data = (await res.json()) as any
  return (data?.web?.results ?? []) as BraveHit[]
}

function classifyDepartments(hits: BraveHit[]): Record<string, number> {
  const breakdown: Record<string, number> = { engineering: 0, sales: 0, operations: 0, rd: 0, other: 0 }
  for (const h of hits) {
    const title = (h.title ?? '').toLowerCase()
    let matched = false
    for (const [dept, keywords] of Object.entries(DEPARTMENT_KEYWORDS)) {
      if (keywords.some(k => title.includes(k))) {
        breakdown[dept]++
        matched = true
        break
      }
    }
    if (!matched) breakdown.other++
  }
  return breakdown
}

export async function getJobAcceleration(ticker: string, companyName: string): Promise<JobSignal> {
  if (!process.env.BRAVE_API_KEY) {
    console.warn(`[jobs] ${ticker} skipped — BRAVE_API_KEY not configured`)
    return { acceleration: null, postingCount: 0, departmentBreakdown: {}, signal: 'Job data unavailable' }
  }
  try {
    const [weekHits, monthHits] = await Promise.all([
      fetchPostings(companyName, 'pw'),
      fetchPostings(companyName, 'pm'),
    ])
    const thisWeek = weekHits.length
    const monthlyWeeklyAvg = monthHits.length / 4
    const acceleration = Math.round(((thisWeek - monthlyWeeklyAvg) / Math.max(monthlyWeeklyAvg, 1)) * 100)
    const departmentBreakdown = classifyDepartments(monthHits.length >= weekHits.length ? monthHits : weekHits)

    let signal: string
    if (acceleration > 30) signal = `🚀 Job acceleration +${acceleration}% — hiring ramp`
    else if (acceleration > 0) signal = `Job growth +${acceleration}% week-over-trend`
    else signal = `Hiring flat (${thisWeek} postings this week)`

    return { acceleration, postingCount: monthHits.length, departmentBreakdown, signal }
  } catch (e) {
    console.warn(`[jobs] ${ticker} failed:`, e instanceof Error ? e.message : e)
    return { acceleration: null, postingCount: 0, departmentBreakdown: {}, signal: 'Job data unavailable' }
  }
}
