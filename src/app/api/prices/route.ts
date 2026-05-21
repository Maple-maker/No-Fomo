import { NextRequest, NextResponse } from 'next/server'

// Simple price router: CoinGecko for crypto, Polygon.io for stocks/ETFs.
// Tickers ending in -USD are CoinGecko (BTC-USD → bitcoin, ETH-USD → ethereum).
// Everything else goes to Polygon.io free tier (15-min delayed).

const COINGECKO_MAP: Record<string, string> = {
  'BTC-USD':  'bitcoin',
  'ETH-USD':  'ethereum',
  'VVV':      'venice-token',
  'HYPE':     'hyperliquid',
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const raw = searchParams.get('tickers') ?? ''
  const tickers = raw.split(',').map(t => t.trim()).filter(Boolean)

  if (tickers.length === 0) return NextResponse.json({})

  const prices: Record<string, number> = {}

  // Split into CoinGecko vs Polygon sets
  const cgIds: string[] = []
  const cgTickerMap: Record<string, string> = {} // coingecko_id → ticker
  const polyTickers: string[] = []

  for (const ticker of tickers) {
    const cgId = COINGECKO_MAP[ticker]
    if (cgId) {
      cgIds.push(cgId)
      cgTickerMap[cgId] = ticker
    } else {
      polyTickers.push(ticker)
    }
  }

  // CoinGecko (free, no key needed)
  if (cgIds.length > 0) {
    try {
      const res = await fetch(
        `https://api.coingecko.com/api/v3/simple/price?ids=${cgIds.join(',')}&vs_currencies=usd`,
        { next: { revalidate: 60 } }
      )
      if (res.ok) {
        const data = await res.json()
        for (const [cgId, ticker] of Object.entries(cgTickerMap)) {
          if (data[cgId]?.usd) prices[ticker] = data[cgId].usd
        }
      }
    } catch {}
  }

  // Polygon.io free tier (15-min delayed, 5 req/min on free plan)
  // Uses previous day's close as a proxy when real-time isn't available
  if (polyTickers.length > 0) {
    const polygonKey = process.env.POLYGON_API_KEY
    if (polygonKey) {
      await Promise.all(polyTickers.map(async (ticker) => {
        try {
          const res = await fetch(
            `https://api.polygon.io/v2/aggs/ticker/${ticker}/prev?adjusted=true&apiKey=${polygonKey}`,
            { next: { revalidate: 300 } }
          )
          if (res.ok) {
            const data = await res.json()
            const close = data.results?.[0]?.c
            if (close) prices[ticker] = close
          }
        } catch {}
      }))
    }
  }

  return NextResponse.json(prices, {
    headers: { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300' }
  })
}
