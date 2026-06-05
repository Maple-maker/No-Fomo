import type { ToolDef } from '../agents/types'

export const getStockPrice: ToolDef = {
  name: 'get_stock_price',
  description:
    'Get the latest price and daily change for a stock ticker. Returns price, change %, and volume.',
  parameters: {
    type: 'object',
    properties: {
      ticker: { type: 'string', description: 'The stock ticker symbol (e.g. AAPL, MSTR)' },
    },
    required: ['ticker'],
  },
  async execute(args) {
    const ticker = (args.ticker as string).toUpperCase()

    // Try Polygon first if key is set
    const polygonKey = process.env.POLYGON_API_KEY
    if (polygonKey) {
      try {
        const url = `https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers/${ticker}?apiKey=${polygonKey}`
        const res = await fetch(url)
        if (res.ok) {
          const data = (await res.json()) as {
            ticker?: {
              day?: { c?: number; v?: number }
              prevDay?: { c?: number }
              lastTrade?: { p?: number }
              updated?: number
            }
          }
          const t = data?.ticker
          if (t) {
            const price = t.day?.c ?? t.lastTrade?.p
            const prevClose = t.prevDay?.c
            const change =
              price && prevClose ? (((price - prevClose) / prevClose) * 100).toFixed(2) + '%' : 'N/A'
            return JSON.stringify({ ticker, price: price ?? 'N/A', change, volume: t.day?.v ?? 'N/A' })
          }
        }
      } catch {
        // Fall through to Yahoo
      }
    }

    // Fallback: Yahoo Finance unofficial API
    try {
      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?interval=1d&range=1d`
      const res = await fetch(url, {
        headers: { 'User-Agent': 'NoFomo/1.0' },
      })
      if (!res.ok) return `Could not fetch price for ${ticker}`

      const data = (await res.json()) as {
        chart?: {
          result?: [
            {
              meta?: { regularMarketPrice?: number; previousClose?: number; regularMarketVolume?: number }
            },
          ]
        }
      }
      const meta = data.chart?.result?.[0]?.meta
      if (!meta) return `No price data found for ${ticker}`

      const price = meta.regularMarketPrice ?? 'N/A'
      const prevClose = meta.previousClose
      const change =
        typeof price === 'number' && prevClose
          ? (((price - prevClose) / prevClose) * 100).toFixed(2) + '%'
          : 'N/A'

      return JSON.stringify({
        ticker,
        price,
        change,
        volume: meta.regularMarketVolume ?? 'N/A',
      })
    } catch (err) {
      return `Error fetching price: ${err instanceof Error ? err.message : String(err)}`
    }
  },
}
