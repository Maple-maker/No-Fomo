// ── Options Implied Volatility (IV) + Put/Call Skew ──
// Rising IV on a beaten-down stock = market pricing in a binary catalyst.
// Source: Yahoo Finance options chain (free). True 52wk IV expansion needs a historical
// baseline we don't have for free, so ivExpansion stays null (not fabricated).

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const YF_OPTIONS = 'https://query1.finance.yahoo.com/v7/finance/options'

export interface OptionsSignal {
  impliedVol: number | null
  ivExpansion: number | null
  putCallRatio: number | null
  signal: string
}

interface YfContract { strike?: number; impliedVolatility?: number; openInterest?: number }

export async function analyzeOptionsVol(ticker: string): Promise<OptionsSignal | null> {
  try {
    const res = await fetch(`${YF_OPTIONS}/${ticker}`, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' }, signal: AbortSignal.timeout(8000) })
    if (!res.ok) return null
    const data = (await res.json()) as any
    const result = data?.optionChain?.result?.[0]
    if (!result) return null
    const spot: number | null = result.quote?.regularMarketPrice ?? null
    const chain = result.options?.[0]
    if (!chain) return null
    const calls: YfContract[] = chain.calls ?? []
    const puts: YfContract[] = chain.puts ?? []
    if (calls.length === 0 && puts.length === 0) return null

    let impliedVol: number | null = null
    if (spot && spot > 0) {
      const nearest = (arr: YfContract[]) => arr.filter(c => c.impliedVolatility && c.strike)
        .sort((a, b) => Math.abs((a.strike! - spot)) - Math.abs((b.strike! - spot)))[0]
      const ivs = [nearest(calls)?.impliedVolatility, nearest(puts)?.impliedVolatility].filter((v): v is number => v != null && v > 0)
      if (ivs.length > 0) impliedVol = Math.round((ivs.reduce((a, b) => a + b, 0) / ivs.length) * 1000) / 10
    }
    const callOI = calls.reduce((s, c) => s + (c.openInterest ?? 0), 0)
    const putOI = puts.reduce((s, c) => s + (c.openInterest ?? 0), 0)
    const putCallRatio = callOI > 0 ? Math.round((putOI / callOI) * 100) / 100 : null

    let signal: string
    if (impliedVol != null && impliedVol > 80) signal = `⚡ High implied vol ${impliedVol}% — market pricing a binary catalyst`
    else if (putCallRatio != null && putCallRatio > 1.5) signal = `Put-heavy positioning (P/C ${putCallRatio})${impliedVol != null ? `, IV ${impliedVol}%` : ''}`
    else if (putCallRatio != null && putCallRatio < 0.6) signal = `Call-heavy positioning (P/C ${putCallRatio})${impliedVol != null ? `, IV ${impliedVol}%` : ''} — bullish skew`
    else if (impliedVol != null) signal = `Implied vol ${impliedVol}%${putCallRatio != null ? `, P/C ${putCallRatio}` : ''}`
    else signal = 'Options data thin'

    return { impliedVol, ivExpansion: null, putCallRatio, signal }
  } catch (e) {
    console.warn(`[options] ${ticker} failed:`, e instanceof Error ? e.message : e)
    return null
  }
}
