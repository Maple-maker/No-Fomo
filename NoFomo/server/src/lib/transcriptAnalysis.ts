// ── Earnings Call Transcript Sentiment ──
// Tone of management commentary leads price. We approximate transcript sentiment from
// bullish/bearish keyword balance across recent transcript search hits (titles + snippets).
// Honest: no full transcript is fabricated — score reflects only public search metadata.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const BRAVE_WEB = 'https://api.search.brave.com/res/v1/web/search'

export interface TranscriptSignal {
  sentimentScore: number
  confidenceLevel: number
  signal: string
}

interface BraveHit {
  title?: string
  description?: string
}

const BULLISH_WORDS = [
  'record', 'beat', 'exceeded', 'accelerating', 'strong', 'growth', 'raised', 'upside',
  'momentum', 'expanding', 'profitable', 'outperform', 'guidance raise', 'optimistic', 'confident',
]
const BEARISH_WORDS = [
  'miss', 'missed', 'decline', 'declining', 'weak', 'headwind', 'lowered', 'cut',
  'slowdown', 'softness', 'disappointing', 'underperform', 'guidance cut', 'cautious', 'challenging',
]

export async function analyzeTranscriptSentiment(ticker: string): Promise<TranscriptSignal | null> {
  const braveKey = process.env.BRAVE_API_KEY
  if (!braveKey) {
    console.warn(`[transcript] ${ticker} skipped — BRAVE_API_KEY not configured`)
    return null
  }
  try {
    const query = `${ticker} earnings call transcript`
    const res = await fetch(
      `${BRAVE_WEB}?q=${encodeURIComponent(query)}&count=20&freshness=pm`,
      {
        headers: { Accept: 'application/json', 'User-Agent': USER_AGENT, 'X-Subscription-Token': braveKey },
        signal: AbortSignal.timeout(9000),
      },
    )
    if (!res.ok) throw new Error(`Brave HTTP ${res.status}`)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = (await res.json()) as any
    const results = (data?.web?.results ?? []) as BraveHit[]
    if (results.length === 0) return null

    let bull = 0
    let bear = 0
    for (const r of results) {
      const text = `${r.title ?? ''} ${r.description ?? ''}`.toLowerCase()
      for (const w of BULLISH_WORDS) if (text.includes(w)) bull++
      for (const w of BEARISH_WORDS) if (text.includes(w)) bear++
    }

    const totalHits = bull + bear
    // sentimentScore: -100..100, positive = bullish. Neutral (0) when no keywords found.
    const sentimentScore = totalHits === 0 ? 0 : Math.round(((bull - bear) / totalHits) * 100)
    // confidenceLevel: 0-100 scaling with the number of transcript results found.
    const confidenceLevel = Math.min(100, Math.round((results.length / 20) * 100))

    let signal: string
    if (sentimentScore > 30) signal = `📈 Bullish transcript tone (+${sentimentScore}) — management upbeat`
    else if (sentimentScore < -30) signal = `📉 Bearish transcript tone (${sentimentScore}) — management cautious`
    else signal = `Neutral transcript tone (${sentimentScore})`

    return { sentimentScore, confidenceLevel, signal }
  } catch (e) {
    console.warn(`[transcript] ${ticker} failed:`, e instanceof Error ? e.message : e)
    return null
  }
}
