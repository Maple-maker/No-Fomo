import type { ToolDef } from '../agents/types'

const SAM_SEARCH = 'https://api.sam.gov/opportunities/v2/search'

interface SamOpportunity {
  title?: string
  fullParentPathName?: string
  department?: string
  postedDate?: string
  uiLink?: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  award?: { amount?: number | string } | any
}

export const samGovSearch: ToolDef = {
  name: 'sam_gov_search',
  description: 'Search SAM.gov federal contract awards',
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Keyword search (company name, agency, or program)' },
      postedFrom: { type: 'string', description: 'Start date MM/DD/YYYY' },
      postedTo: { type: 'string', description: 'End date MM/DD/YYYY' },
    },
    required: ['query'],
  },
  async execute(args) {
    const apiKey = process.env.SAM_API_KEY
    if (!apiKey) {
      console.warn('[sam] SAM_API_KEY not configured — returning empty result set')
      return JSON.stringify([])
    }
    try {
      const url = new URL(SAM_SEARCH)
      url.searchParams.set('api_key', apiKey)
      url.searchParams.set('q', args.query as string)
      url.searchParams.set('limit', '10')
      if (typeof args.postedFrom === 'string') url.searchParams.set('postedFrom', args.postedFrom)
      if (typeof args.postedTo === 'string') url.searchParams.set('postedTo', args.postedTo)

      const res = await fetch(url.toString(), {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(12000),
      })
      if (!res.ok) return `Error: SAM.gov HTTP ${res.status} ${res.statusText}`

      const data = (await res.json()) as { opportunitiesData?: SamOpportunity[] }
      const opportunities = data.opportunitiesData ?? []
      return JSON.stringify(
        opportunities.map(o => {
          const rawAmount = o.award?.amount
          const amount =
            typeof rawAmount === 'number'
              ? rawAmount
              : typeof rawAmount === 'string'
                ? Number(rawAmount) || undefined
                : undefined
          return {
            title: o.title ?? '',
            agency: o.fullParentPathName || o.department || '',
            postedDate: o.postedDate ?? '',
            link: o.uiLink ?? '',
            ...(amount != null ? { amount } : {}),
          }
        }),
      )
    } catch (err) {
      return `Error: ${err instanceof Error ? err.message : String(err)}`
    }
  },
}
