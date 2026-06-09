// ── Yahoo Finance data via public API (Node.js, no Python required) ──
// Matches the output shape of stock_data.py for drop-in compatibility.
// Works in serverless environments (Vercel, etc.) where Python is unavailable.

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

const YF_QUERY = 'https://query2.finance.yahoo.com/v10/finance/quoteSummary'
const YF_CHART = 'https://query1.finance.yahoo.com/v8/finance/chart'

interface YfQuoteModules {
  price?: {
    regularMarketPrice?: { raw: number }
    regularMarketChangePercent?: { raw: number }
    marketCap?: { raw: number }
    shortName?: string
    longName?: string
    symbol?: string
  }
  summaryDetail?: {
    previousClose?: { raw: number }
    beta?: { raw: number }
    shortRatio?: { raw: number }
    sharesShort?: { raw: number }
    shortPercentOfFloat?: { raw: number }
    sharesShortPriorMonth?: { raw: number }
    sharesShortPreviousMonthDate?: { raw: string }
    dateShortInterest?: { raw: string }
    averageVolume?: { raw: number }
    averageVolume10days?: { raw: number }
    dividendYield?: { raw: number }
    dividendRate?: { raw: number }
    trailingAnnualDividendRate?: { raw: number }
    trailingAnnualDividendYield?: { raw: number }
    fiveYearAvgDividendYield?: { raw: number }
    payoutRatio?: { raw: number }
  }
  financialData?: {
    currentPrice?: { raw: number }
    targetMeanPrice?: { raw: number }
    targetHighPrice?: { raw: number }
    targetLowPrice?: { raw: number }
    recommendationMean?: { raw: number }
    recommendationKey?: string
    numberOfAnalystOpinions?: { raw: number }
    revenueGrowth?: { raw: number }
    grossMargins?: { raw: number }
    priceToSalesTrailing12Months?: { raw: number }
    freeCashflow?: { raw: number }
    enterpriseToEbitda?: { raw: number }
    earningsPerShare?: { raw: number }
    forwardEps?: { raw: number }
  }
  defaultKeyStatistics?: {
    sharesOutstanding?: { raw: number }
    floatShares?: { raw: number }
    priceToFreeCashflow?: { raw: number }
    enterpriseValue?: { raw: number }
    trailingPE?: { raw: number }
    forwardPE?: { raw: number }
    shortPercentOfFloat?: { raw: number }
    lastDividendValue?: { raw: number }
    lastDividendDate?: { raw: number }
  }
  calendarEvents?: {
    earnings?: {
      earningsDate?: { raw: number }[]
      earningsAverage?: { raw: number }
      earningsLow?: { raw: number }
      earningsHigh?: { raw: number }
      revenueAverage?: { raw: number }
      revenueLow?: { raw: number }
      revenueHigh?: { raw: number }
    }
  }
  recommendationTrend?: {
    trend?: Array<{
      period: string
      strongBuy: number
      buy: number
      hold: number
      sell: number
      strongSell: number
    }>
  }
  institutionOwnership?: {
    ownershipList?: Array<{
      holder: string
      position: number
      value: number
      pctHeld: number
      reportDate: string
      change: number
    }>
  }
  assetProfile?: {
    sector?: string
    industry?: string
  }
}

function fmtCap(raw: number | null | undefined): string {
  if (!raw) return 'N/A'
  if (raw >= 1e12) return `$${(raw / 1e12).toFixed(2)}T`
  if (raw >= 1e9) return `$${(raw / 1e9).toFixed(1)}B`
  if (raw >= 1e6) return `$${(raw / 1e6).toFixed(0)}M`
  return `$${raw.toLocaleString()}`
}

function computeRsi(closes: number[], period = 14): { value: number; signal: string } {
  if (closes.length < period + 1) return { value: 50, signal: 'neutral' }
  const gains: number[] = []
  const losses: number[] = []
  for (let i = 1; i <= period; i++) {
    const diff = closes[closes.length - i] - closes[closes.length - 1 - i]
    gains.push(diff > 0 ? diff : 0)
    losses.push(diff < 0 ? -diff : 0)
  }
  const avgGain = gains.reduce((a, b) => a + b, 0) / period
  const avgLoss = losses.reduce((a, b) => a + b, 0) / period
  if (avgLoss === 0) return { value: 100, signal: 'overbought' }
  const rs = avgGain / avgLoss
  const rsi = 100 - 100 / (1 + rs)
  return {
    value: Math.round(rsi * 10) / 10,
    signal: rsi > 70 ? 'overbought' : rsi < 30 ? 'oversold' : 'neutral',
  }
}

function computeMacd(closes: number[]): { macd: number; signal: number; histogram: number; bullish: boolean } {
  if (closes.length < 35) return { macd: 0, signal: 0, histogram: 0, bullish: false }
  const ema = (data: number[], period: number): number[] => {
    const k = 2 / (period + 1)
    const result: number[] = [data[0]]
    for (let i = 1; i < data.length; i++) {
      result.push(data[i] * k + result[i - 1] * (1 - k))
    }
    return result
  }
  const ema12 = ema(closes, 12)
  const ema26 = ema(closes, 26)
  const macdLine = ema12.map((v, i) => v - ema26[i])
  const signal = ema(macdLine, 9)
  const macdV = macdLine[macdLine.length - 1]
  const sigV = signal[signal.length - 1]
  return {
    macd: Math.round(macdV * 10000) / 10000,
    signal: Math.round(sigV * 10000) / 10000,
    histogram: Math.round((macdV - sigV) * 10000) / 10000,
    bullish: macdV > sigV,
  }
}

function computeBollinger(closes: number[]): { upper: number; middle: number; lower: number } {
  if (closes.length < 20) return { upper: 0, middle: 0, lower: 0 }
  const recent = closes.slice(-20)
  const mean = recent.reduce((a, b) => a + b, 0) / 20
  const variance = recent.reduce((sum, v) => sum + (v - mean) ** 2, 0) / 20
  const std = Math.sqrt(variance)
  return {
    upper: Math.round((mean + 2 * std) * 100) / 100,
    middle: Math.round(mean * 100) / 100,
    lower: Math.round((mean - 2 * std) * 100) / 100,
  }
}

export interface StockDataResult {
  ticker: string
  company: string
  sector: string
  industry: string
  price: number
  change_pct: number
  prev_close: number
  market_cap: string
  pe_trailing: number | null
  pe_forward: number | null
  ps_ttm: number | null
  pfcf: number | null
  ev_ebitda: number | null
  gross_margin: number | null
  rev_growth_yoy: number | null
  rev_acceleration?: number | null
  beta: number | null
  short_pct: number | null
  analyst_count: number | null
  analyst_target_mean: number | null
  analyst_target_high: number | null
  analyst_target_low: number | null
  analyst_consensus: string | null
  analyst_mean_rating: number | null
  rsi_14: number
  rsi_signal: string
  macd: { macd: number; signal: number; histogram: number; bullish: boolean }
  bollinger: { upper: number; middle: number; lower: number }
  avg_volume: number
  vol_vs_avg: number | null
  price_history: number[]
  recommendation_breakdown: {
    strongBuy: number
    buy: number
    hold: number
    sell: number
    strongSell: number
  }
  institutional_holders: Array<{
    name: string
    value: number
    pct_change: number
    date_reported: string
  }>
  catalysts: Array<{
    date: string
    type: string
    label: string
    detail: string
  }>
  // Short interest
  shares_short: number | null
  short_ratio: number | null
  short_pct_of_float: number | null
  shares_short_prior_month: number | null
  short_prior_month_date: string | null
  short_interest_date: string | null
  // New fundamental quality signals
  insider_pct?: number | null
  gaap_quality_score?: number | null
  earnings_miss_count?: number
  // Share structure (squeeze analysis)
  shares_outstanding?: number | null
  float_shares?: number | null
  // Dividend signals
  dividend_yield?: number | null
  dividend_rate?: number | null
  trailing_annual_dividend_rate?: number | null
  five_year_avg_dividend_yield?: number | null
  payout_ratio?: number | null
  last_dividend_value?: number | null
  // Analyst revision trend (per-period recommendation breakdown, newest first)
  recommendation_trend?: Array<{
    period: string
    strongBuy: number
    buy: number
    hold: number
    sell: number
    strongSell: number
  }>
  error?: string
}

async function fetchJson(url: string, retries = 2): Promise<any> {
  for (let attempt = 0; attempt <= retries; attempt++) {
    const res = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
      signal: AbortSignal.timeout(8000),
    })
    if (res.ok) return res.json()
    if (res.status === 429 && attempt < retries) {
      const delay = 1500 * (attempt + 1)
      console.warn(`[stockData] 429 on ${url.slice(0, 80)} — retry ${attempt + 1}/${retries} in ${delay}ms`)
      await new Promise(r => setTimeout(r, delay))
      continue
    }
    throw new Error(`HTTP ${res.status}: ${res.statusText}`)
  }
}

async function fetchQuoteSummary(ticker: string): Promise<YfQuoteModules> {
  const modules = [
    'price', 'summaryDetail', 'financialData', 'defaultKeyStatistics',
    'calendarEvents', 'recommendationTrend', 'institutionOwnership', 'assetProfile',
  ].join(',')
  const url = `${YF_QUERY}/${ticker}?modules=${modules}`
  try {
    const data = await fetchJson(url)
    return data?.quoteSummary?.result?.[0] ?? {}
  } catch (err) {
    console.error(`[stockData] quoteSummary failed for ${ticker}:`, err)
    return {}
  }
}

async function fetchChart(ticker: string): Promise<{ closes: number[]; volumes: number[] }> {
  const url = `${YF_CHART}/${ticker}?range=1y&interval=1d`
  try {
    const data = await fetchJson(url)
    const result = data?.chart?.result?.[0]
    if (!result) return { closes: [], volumes: [] }
    const quotes = result.indicators?.quote?.[0]
    const adjCloses = result.indicators?.adjclose?.[0]?.adjclose
    const closes = (adjCloses || quotes?.close || []).filter((v: number | null) => v != null).map(Number)
    const volumes = (quotes?.volume || []).filter((v: number | null) => v != null).map(Number)
    return { closes, volumes }
  } catch (err) {
    console.error(`[stockData] chart failed for ${ticker}:`, err)
    return { closes: [], volumes: [] }
  }
}

export async function getStockData(ticker: string): Promise<StockDataResult> {
  const clean = ticker.toUpperCase().trim()
  const modules = await fetchQuoteSummary(clean)
  await new Promise(r => setTimeout(r, 1200))
  const chart = await fetchChart(clean)

  const price = modules.price
  const detail = modules.summaryDetail
  const fin = modules.financialData
  const stats = modules.defaultKeyStatistics
  const cal = modules.calendarEvents
  const recTrend = modules.recommendationTrend
  const instOwn = modules.institutionOwnership
  const profile = modules.assetProfile

  const lastPrice = price?.regularMarketPrice?.raw ?? fin?.currentPrice?.raw ?? 0
  const changePct = price?.regularMarketChangePercent?.raw
    ? Math.round(price.regularMarketChangePercent.raw * 10000) / 100
    : 0
  const prevClose = detail?.previousClose?.raw ?? lastPrice

  const closes = chart.closes.length > 0 ? chart.closes : []
  const volumes = chart.volumes.length > 0 ? chart.volumes : []
  const latestVolume = volumes[volumes.length - 1] ?? 0
  const avgVolume = detail?.averageVolume?.raw ?? detail?.averageVolume10days?.raw ?? 0

  const rsi = closes.length > 15 ? computeRsi(closes) : { value: 50, signal: 'neutral' }
  const macd = computeMacd(closes)
  const bb = computeBollinger(closes)

  let recBreakdown = { strongBuy: 0, buy: 0, hold: 0, sell: 0, strongSell: 0 }
  if (recTrend?.trend?.length) {
    const latest = recTrend.trend.find((t: any) => t.period === '0m') ?? recTrend.trend[0]
    recBreakdown = {
      strongBuy: latest.strongBuy ?? 0,
      buy: latest.buy ?? 0,
      hold: latest.hold ?? 0,
      sell: latest.sell ?? 0,
      strongSell: latest.strongSell ?? 0,
    }
  }
  const recommendationTrend = (recTrend?.trend ?? []).map((t: any) => ({
    period: t.period ?? '',
    strongBuy: t.strongBuy ?? 0,
    buy: t.buy ?? 0,
    hold: t.hold ?? 0,
    sell: t.sell ?? 0,
    strongSell: t.strongSell ?? 0,
  }))

  const instHolders: StockDataResult['institutional_holders'] = []
  if (instOwn?.ownershipList) {
    for (const h of instOwn.ownershipList.slice(0, 10)) {
      instHolders.push({
        name: h.holder ?? '',
        value: h.value ?? 0,
        pct_change: h.change ?? 0,
        date_reported: h.reportDate ?? '',
      })
    }
  }

  const catalysts: StockDataResult['catalysts'] = []
  const earnings = cal?.earnings
  if (earnings?.earningsDate?.length) {
    for (const ed of earnings.earningsDate) {
      if (ed?.raw) {
        const d = new Date(ed.raw * 1000).toISOString().slice(0, 10)
        catalysts.push({
          date: d,
          type: 'earnings',
          label: 'Earnings',
          detail: `EPS est: $${earnings.earningsAverage?.raw ?? 'N/A'} | Rev est: $${earnings.revenueAverage?.raw ? fmtCap(earnings.revenueAverage.raw) : 'N/A'}`,
        })
      }
    }
  }

  const rawShortPct = detail?.shortPercentOfFloat?.raw ?? stats?.shortPercentOfFloat?.raw

  return {
    ticker: clean,
    company: price?.shortName ?? price?.longName ?? clean,
    sector: profile?.sector ?? '',
    industry: profile?.industry ?? '',
    price: lastPrice,
    change_pct: changePct,
    prev_close: prevClose,
    market_cap: fmtCap(price?.marketCap?.raw),
    pe_trailing: stats?.trailingPE?.raw ?? null,
    pe_forward: stats?.forwardPE?.raw ?? null,
    ps_ttm: fin?.priceToSalesTrailing12Months?.raw ?? null,
    pfcf: stats?.priceToFreeCashflow?.raw ?? fin?.freeCashflow?.raw ?? null,
    ev_ebitda: fin?.enterpriseToEbitda?.raw ?? null,
    gross_margin: fin?.grossMargins?.raw != null ? Math.round(fin.grossMargins.raw * 1000) / 10 : null,
    rev_growth_yoy: fin?.revenueGrowth?.raw != null ? Math.round(fin.revenueGrowth.raw * 1000) / 10 : null,
    beta: detail?.beta?.raw ?? null,
    short_pct: rawShortPct != null ? Math.round(rawShortPct * 1000) / 10 : null,
    analyst_count: fin?.numberOfAnalystOpinions?.raw ?? null,
    analyst_target_mean: fin?.targetMeanPrice?.raw ?? null,
    analyst_target_high: fin?.targetHighPrice?.raw ?? null,
    analyst_target_low: fin?.targetLowPrice?.raw ?? null,
    analyst_consensus: fin?.recommendationKey ?? null,
    analyst_mean_rating: fin?.recommendationMean?.raw ?? null,
    rsi_14: rsi.value,
    rsi_signal: rsi.signal,
    macd,
    bollinger: bb,
    avg_volume: Math.round(avgVolume),
    vol_vs_avg: avgVolume > 0 && latestVolume > 0 ? Math.round((latestVolume / avgVolume) * 100) / 100 : null,
    price_history: closes.map(c => Math.round(c * 100) / 100),
    recommendation_breakdown: recBreakdown,
    institutional_holders: instHolders,
    catalysts,
    shares_short: detail?.sharesShort?.raw ?? null,
    short_ratio: detail?.shortRatio?.raw ?? null,
    short_pct_of_float: rawShortPct != null ? Math.round(rawShortPct * 10000) / 100 : null,
    shares_short_prior_month: detail?.sharesShortPriorMonth?.raw ?? null,
    short_prior_month_date: detail?.sharesShortPreviousMonthDate?.raw ?? null,
    short_interest_date: detail?.dateShortInterest?.raw ?? null,
    // Share structure
    shares_outstanding: stats?.sharesOutstanding?.raw ?? null,
    float_shares: stats?.floatShares?.raw ?? null,
    // Dividend signals (yields stored as %)
    dividend_yield: detail?.dividendYield?.raw != null
      ? Math.round(detail.dividendYield.raw * 10000) / 100
      : (detail?.trailingAnnualDividendYield?.raw != null ? Math.round(detail.trailingAnnualDividendYield.raw * 10000) / 100 : null),
    dividend_rate: detail?.dividendRate?.raw ?? null,
    trailing_annual_dividend_rate: detail?.trailingAnnualDividendRate?.raw ?? null,
    five_year_avg_dividend_yield: detail?.fiveYearAvgDividendYield?.raw ?? null,
    payout_ratio: detail?.payoutRatio?.raw ?? null,
    last_dividend_value: stats?.lastDividendValue?.raw ?? null,
    recommendation_trend: recommendationTrend,
  }
}
