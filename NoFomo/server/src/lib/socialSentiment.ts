// ── Social Mention Velocity ──
// Detects crowdsourced discovery. Reddit's JSON API hard-blocks cloud access (403), so we
// measure reddit.com/stocktwits.com mention velocity through Brave Search (existing key).

export interface SocialSignal {
  mentionVelocity: number
  mentionsThisWeek: number
  mentionsLastMonth: number
  sentiment: 'bullish' | 'bearish' | 'neutral'
  signal: string
}

const BULLISH_WORDS = ['buy', 'long', 'calls', 'moon', 'undervalued', 'bullish', 'squeeze', 'breakout', 'rocket', 'gem', 'bull']
const BEARISH_WORDS = ['sell', 'short', 'puts', 'overvalued', 'bearish', 'dump', 'crash', 'avoid', 'bagholder', 'bear']

interface BraveHit { title?: string; description?: string }

async function fetchSocialMentions(ticker: string, freshness: 'pw' | 'pm'): Promise<BraveHit[]> {
  const braveKey = process.env.BRAVE_API_KEY
  if (!braveKey) return []
  const query = `$${ticker} stock (site:reddit.com OR site:stocktwits.com)`
  const res = await fetch(
    `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(query)}&count=20&freshness=${freshness}`,
    { headers: { Accept: 'application/json', 'X-Subscription-Token': braveKey }, signal: AbortSignal.timeout(9000) },
  )
  if (!res.ok) throw new Error(`Brave HTTP ${res.status}`)
  const data = (await res.json()) as any
  return (data?.web?.results ?? []) as BraveHit[]
}

function classifySentiment(hits: BraveHit[]): 'bullish' | 'bearish' | 'neutral' {
  let bull = 0, bear = 0
  for (const h of hits) {
    const text = `${h.title ?? ''} ${h.description ?? ''}`.toLowerCase()
    for (const w of BULLISH_WORDS) if (text.includes(w)) bull++
    for (const w of BEARISH_WORDS) if (text.includes(w)) bear++
  }
  if (bull > bear * 1.3) return 'bullish'
  if (bear > bull * 1.3) return 'bearish'
  return 'neutral'
}

export async function getRedditMentionVelocity(ticker: string): Promise<SocialSignal | null> {
  try {
    if (!process.env.BRAVE_API_KEY) return null
    const [weekHits, monthHits] = await Promise.all([fetchSocialMentions(ticker, 'pw'), fetchSocialMentions(ticker, 'pm')])
    const mentionsThisWeek = weekHits.length
    const mentionsLastMonth = monthHits.length
    if (mentionsLastMonth === 0 && mentionsThisWeek === 0) return null
    const weeklyAvg = Math.max(mentionsLastMonth / 4, 0.5)
    const mentionVelocity = Math.round((mentionsThisWeek / weeklyAvg) * 100) / 100
    const sentiment = classifySentiment([...weekHits, ...monthHits])
    let signal: string
    if (mentionVelocity >= 5) signal = `🔥 Social mentions ${mentionVelocity}x normal this week — ${sentiment} discovery surge`
    else if (mentionVelocity >= 3) signal = `Social attention rising ${mentionVelocity}x (${sentiment})`
    else signal = `${mentionsThisWeek} social mentions this week (${sentiment})`
    return { mentionVelocity, mentionsThisWeek, mentionsLastMonth, sentiment, signal }
  } catch (e) {
    console.warn(`[social] ${ticker} mention fetch failed:`, e instanceof Error ? e.message : e)
    return null
  }
}
