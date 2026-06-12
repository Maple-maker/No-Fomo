// ── Dividend Initiation & Increase Tracking ──
// First dividend ever = profitability inflection. Increase on maintained payout = earnings confidence.
// Source: Yahoo dividend fields (on stockData) + dividend history via chart events=div.

import type { StockDataResult } from './stockData'

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const YF_CHART = 'https://query1.finance.yahoo.com/v8/finance/chart'

export interface DividendSignal {
  paysDividend: boolean
  dividendInitiated: boolean
  yieldPct: number | null
  yieldChange: number | null
  payoutRatio: number | null
  dividendCount: number
  signal: string
}

async function fetchDividendHistory(ticker: string): Promise<number[]> {
  try {
    const url = `${YF_CHART}/${ticker}?range=10y&interval=1mo&events=div`
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' }, signal: AbortSignal.timeout(8000) })
    if (!res.ok) return []
    const data = (await res.json()) as any
    const divs = data?.chart?.result?.[0]?.events?.dividends
    if (!divs) return []
    return Object.values(divs).map((d: any) => Number(d?.date)).filter((t: number) => Number.isFinite(t)).sort((a, b) => a - b)
  } catch { return [] }
}

const noDividend: DividendSignal = {
  paysDividend: false, dividendInitiated: false, yieldPct: null,
  yieldChange: null, payoutRatio: null, dividendCount: 0, signal: 'No dividend',
}

export async function analyzeDividendSignal(
  ticker: string,
  stockData?: Partial<StockDataResult> | null,
): Promise<DividendSignal> {
  if (!stockData) return noDividend

  const yieldPct = stockData.dividend_yield ?? null
  const rate = stockData.dividend_rate ?? stockData.trailing_annual_dividend_rate ?? null
  const fiveYrAvg = stockData.five_year_avg_dividend_yield ?? null
  const payoutRatio = stockData.payout_ratio ?? null

  const paysDividend = (rate != null && rate > 0) || (yieldPct != null && yieldPct > 0)
  if (!paysDividend) return noDividend

  const timestamps = await fetchDividendHistory(ticker)
  const dividendCount = timestamps.length
  let dividendInitiated = false
  if (dividendCount > 0) {
    const firstSec = timestamps[0]
    const eighteenMonthsSec = 18 * 30 * 24 * 60 * 60
    const nowSec = Math.floor(Date.now() / 1000)
    dividendInitiated = (nowSec - firstSec) < eighteenMonthsSec || dividendCount <= 4
  } else {
    dividendInitiated = true
  }

  const yieldChange = (yieldPct != null && fiveYrAvg != null) ? Math.round((yieldPct - fiveYrAvg) * 100) / 100 : null

  let signal: string
  if (dividendInitiated) signal = `💵 Dividend initiated${yieldPct != null ? ` (${yieldPct}% yield)` : ''} — profitability inflection`
  else if (yieldChange != null && yieldChange > 0.3) signal = `Dividend growing (yield ${yieldPct}% vs ${fiveYrAvg}% 5yr avg) — earnings confidence`
  else signal = `Pays ${yieldPct != null ? `${yieldPct}% ` : ''}dividend`

  return { paysDividend, dividendInitiated, yieldPct, yieldChange, payoutRatio, dividendCount, signal }
}
