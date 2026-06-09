// ── Kalshi Prediction-Market Signal (Jelly Signals) ──
// Prediction-market odds shift BEFORE news breaks — exactly the early-inflection signal
// NoFomo hunts. Kalshi's public market data needs no API key.
// Source: https://api.elections.kalshi.com/trade-api/v2/markets (free, public).

import type { ToolDef } from '../agents/types'

const KALSHI_BASE = 'https://api.elections.kalshi.com/trade-api/v2'
const USER_AGENT = 'NoFomo/1.0 (radar research)'

export interface KalshiMarket {
  ticker: string
  title: string
  impliedProbability: number   // 0-100 (last traded price in cents)
  yesBid: number | null
  yesAsk: number | null
  volume24h: number
  openInterest: number
  closeDate: string | null
  signal: string
}

interface RawMarket {
  ticker?: string
  title?: string
  last_price?: number
  yes_bid?: number
  yes_ask?: number
  volume_24h?: number
  open_interest?: number
  close_time?: string
}

function toMarket(m: RawMarket): KalshiMarket {
  const prob = m.last_price ?? (m.yes_bid != null && m.yes_ask != null ? Math.round((m.yes_bid + m.yes_ask) / 2) : 50)
  const vol = m.volume_24h ?? 0
  let signal: string
  if (vol > 5000 && prob >= 40 && prob <= 60) signal = `⚡ Live coin-flip (${prob}%) on high volume — repricing in progress`
  else if (vol > 5000) signal = `High-conviction market: ${prob}% implied, heavy volume`
  else signal = `${prob}% implied probability`
  return {
    ticker: m.ticker ?? '',
    title: m.title ?? '',
    impliedProbability: prob,
    yesBid: m.yes_bid ?? null,
    yesAsk: m.yes_ask ?? null,
    volume24h: vol,
    openInterest: m.open_interest ?? 0,
    closeDate: m.close_time ?? null,
    signal,
  }
}

/**
 * Fetch open Kalshi markets, optionally filtered by a free-text query over titles.
 * Sorted by 24h volume (most liquid / most informative first). Empty on failure.
 */
export async function getKalshiMarkets(query?: string, limit = 100): Promise<KalshiMarket[]> {
  try {
    const url = `${KALSHI_BASE}/markets?limit=${Math.min(limit, 1000)}&status=open`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' }, signal: AbortSignal.timeout(10000) })
    if (!res.ok) return []
    const data = (await res.json()) as { markets?: RawMarket[] }
    let markets = (data.markets ?? []).map(toMarket)
    if (query && query.trim()) {
      const q = query.toLowerCase().trim()
      markets = markets.filter(m => m.title.toLowerCase().includes(q) || m.ticker.toLowerCase().includes(q))
    }
    return markets.sort((a, b) => b.volume24h - a.volume24h).slice(0, 25)
  } catch (e) {
    console.warn('[kalshi] fetch failed:', e instanceof Error ? e.message : e)
    return []
  }
}

// ToolDef so the radar agent can pull prediction-market odds for macro/event context.
export const kalshiSearch: ToolDef = {
  name: 'kalshi_search',
  description: 'Search Kalshi prediction markets for event/economic odds (Fed decisions, recession, regulatory outcomes, geopolitics). Returns implied probabilities — useful as a leading signal before news breaks.',
  parameters: {
    type: 'object',
    properties: { query: { type: 'string', description: 'Topic to search market titles, e.g. "fed rate", "recession", "government shutdown"' } },
    required: ['query'],
  },
  async execute(args) {
    const query = String(args.query ?? '')
    const markets = await getKalshiMarkets(query, 200)
    if (markets.length === 0) return JSON.stringify([])
    return JSON.stringify(markets.slice(0, 10).map(m => ({ title: m.title, impliedProbability: m.impliedProbability, volume24h: m.volume24h, signal: m.signal })))
  },
}
