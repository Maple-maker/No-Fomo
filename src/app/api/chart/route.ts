import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const ticker = searchParams.get('ticker')?.toUpperCase()
  const range = searchParams.get('range') || '1mo'

  if (!ticker) return NextResponse.json({ error: 'ticker required' }, { status: 400 })

  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?interval=1d&range=${range}`
    const res = await fetch(url, {
      headers: { 'User-Agent': 'NoFomo/1.0' },
      next: { revalidate: 300 },
    })
    if (!res.ok) return NextResponse.json({ points: [] })

    const data = await res.json()
    const result = data?.chart?.result?.[0]
    if (!result) return NextResponse.json({ points: [] })

    const timestamps: number[] = result.timestamp || []
    const quote = result.indicators?.quote?.[0] || {}
    const closes: (number | null)[] = quote.close || []
    const volumes: (number | null)[] = quote.volume || []

    const points = timestamps
      .map((ts, i) => ({
        date: new Date(ts * 1000).toISOString().split('T')[0],
        close: closes[i] ?? null,
        volume: volumes[i] ?? null,
      }))
      .filter(p => p.close !== null)

    return NextResponse.json(
      {
        ticker,
        points,
        meta: {
          regularMarketPrice: result.meta?.regularMarketPrice ?? null,
          previousClose: result.meta?.previousClose ?? null,
          averageVolume: result.meta?.averageDailyVolume3Month ?? null,
        },
      },
      { headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=900' } }
    )
  } catch {
    return NextResponse.json({ points: [] })
  }
}
