import type { ToolDef } from '../agents/types'

// ── Quiver Quant enrichment ──
// Alternative-data signals: congressional trading, federal government contracts, and
// WallStreetBets mention velocity. Source: api.quiverquant.com (Bearer auth).
// Honest: no key → null. Every source link below resolves to a real quiverquant.com page.

const QUIVER_BASE = 'https://api.quiverquant.com/beta'

export interface EnrichedData {
  tickerData?: {
    wsbMentionsWeekly?: number
    congressBought?: number
    congressSold?: number
  }
  congressTrades?: Array<{
    TransactionDate?: string
    Transaction?: string
    Representative?: string
    Party?: string
    Range?: string
    House?: string
  }>
  govContracts?: Array<{
    Date?: string
    Description?: string
    Agency?: string
    Amount?: number
  }>
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function quiverGet(path: string, apiKey: string): Promise<any> {
  const res = await fetch(`${QUIVER_BASE}${path}`, {
    headers: { Accept: 'application/json', Authorization: `Bearer ${apiKey}` },
    signal: AbortSignal.timeout(12000),
  })
  if (!res.ok) throw new Error(`Quiver HTTP ${res.status} on ${path}`)
  return res.json()
}

export async function enrichTicker(ticker: string): Promise<EnrichedData | null> {
  const apiKey = process.env.QUIVER_API_KEY
  if (!apiKey) {
    console.warn(`[quiver] ${ticker} skipped — QUIVER_API_KEY not configured`)
    return null
  }
  const clean = ticker.toUpperCase().trim()
  try {
    const [congressRaw, contractsRaw, wsbRaw] = await Promise.all([
      quiverGet(`/historical/congresstrading/${clean}`, apiKey).catch(() => []),
      quiverGet(`/historical/govcontractsall/${clean}`, apiKey).catch(() => []),
      quiverGet(`/historical/wallstreetbets/${clean}`, apiKey).catch(() => []),
    ])

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const congressArr: any[] = Array.isArray(congressRaw) ? congressRaw : []
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const contractsArr: any[] = Array.isArray(contractsRaw) ? contractsRaw : []
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const wsbArr: any[] = Array.isArray(wsbRaw) ? wsbRaw : []

    const congressTrades = congressArr.slice(0, 25).map(t => ({
      TransactionDate: t.TransactionDate ?? t.Date,
      Transaction: t.Transaction,
      Representative: t.Representative,
      Party: t.Party,
      Range: t.Range,
      House: t.House,
    }))

    const govContracts = contractsArr.slice(0, 25).map(c => ({
      Date: c.Date,
      Description: c.Description,
      Agency: c.Agency,
      Amount: typeof c.Amount === 'number' ? c.Amount : Number(c.Amount) || undefined,
    }))

    const isBuy = (tx?: string) => /buy|purchase/i.test(tx ?? '')
    const isSell = (tx?: string) => /sell|sale/i.test(tx ?? '')
    const congressBought = congressTrades.filter(t => isBuy(t.Transaction)).length
    const congressSold = congressTrades.filter(t => isSell(t.Transaction)).length

    // WSB mentions: most recent record's weekly mention count, if present.
    const latestWsb = wsbArr[0] ?? {}
    const wsbMentionsWeekly =
      typeof latestWsb.Mentions === 'number'
        ? latestWsb.Mentions
        : Number(latestWsb.Mentions) || undefined

    return {
      tickerData: { wsbMentionsWeekly, congressBought, congressSold },
      congressTrades,
      govContracts,
    }
  } catch (e) {
    console.warn(`[quiver] ${clean} failed:`, e instanceof Error ? e.message : e)
    return null
  }
}

export const quiverEnrich: ToolDef = {
  name: 'quiver_enrich',
  description: 'Get news, events, insider trades, gov contracts, congressional trading for a ticker',
  parameters: {
    type: 'object',
    properties: {
      ticker: { type: 'string', description: 'The stock ticker symbol (e.g. AAPL, MSTR)' },
    },
    required: ['ticker'],
  },
  async execute(args) {
    const ticker = (args.ticker as string).toUpperCase()
    const data = await enrichTicker(ticker)
    return JSON.stringify(data ?? {})
  },
}

export function formatSources(data: EnrichedData): { label: string; url: string }[] {
  const sources: { label: string; url: string }[] = []
  if (data.congressTrades && data.congressTrades.length > 0) {
    sources.push({
      label: `Congressional trading (${data.congressTrades.length} disclosures)`,
      url: 'https://www.quiverquant.com/congresstrading/',
    })
  }
  if (data.govContracts && data.govContracts.length > 0) {
    sources.push({
      label: `Federal government contracts (${data.govContracts.length} awards)`,
      url: 'https://www.quiverquant.com/sources/govcontracts',
    })
  }
  if (data.tickerData?.wsbMentionsWeekly && data.tickerData.wsbMentionsWeekly > 0) {
    sources.push({
      label: `WallStreetBets mentions (${data.tickerData.wsbMentionsWeekly} this week)`,
      url: 'https://www.quiverquant.com/wallstreetbets/',
    })
  }
  return sources
}
