// ── Activist Short Reports ──
// Surfaces published activist short theses (Hindenburg, Muddy Waters, Citron, Grizzly, etc.)
// via Brave Search over the past year. Each hit links to a real, verifiable source URL.
// Honest: silence is data — no reports found returns an empty array.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const BRAVE_WEB = 'https://api.search.brave.com/res/v1/web/search'

export interface ShortReport {
  source: string
  title: string
  url: string
  date: string
}

interface BraveHit {
  title?: string
  url?: string
  age?: string
  page_age?: string
  profile?: { name?: string }
  meta_url?: { hostname?: string }
}

export async function getShortReports(ticker: string): Promise<ShortReport[]> {
  const braveKey = process.env.BRAVE_API_KEY
  if (!braveKey) {
    console.warn(`[shortReports] ${ticker} skipped — BRAVE_API_KEY not configured`)
    return []
  }
  try {
    const query = `${ticker} stock (Hindenburg OR "Muddy Waters" OR Citron OR "Grizzly Research" OR "short seller report")`
    const res = await fetch(
      `${BRAVE_WEB}?q=${encodeURIComponent(query)}&count=10&freshness=py`,
      {
        headers: { Accept: 'application/json', 'User-Agent': USER_AGENT, 'X-Subscription-Token': braveKey },
        signal: AbortSignal.timeout(9000),
      },
    )
    if (!res.ok) throw new Error(`Brave HTTP ${res.status}`)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = (await res.json()) as any
    const results = (data?.web?.results ?? []) as BraveHit[]
    return results
      .filter(r => r.url && r.title)
      .map(r => ({
        source: r.profile?.name || r.meta_url?.hostname || 'Unknown',
        title: r.title || '',
        url: r.url || '',
        date: r.age || r.page_age?.slice(0, 10) || '',
      }))
  } catch (e) {
    console.warn(`[shortReports] ${ticker} failed:`, e instanceof Error ? e.message : e)
    return []
  }
}
