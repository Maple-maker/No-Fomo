import type { ToolDef } from '../agents/types'

const EXA_SEARCH = 'https://api.exa.ai/search'

interface ExaResult {
  title?: string
  url?: string
  publishedDate?: string
}

export const exaSearch: ToolDef = {
  name: 'exa_search',
  description: 'Neural semantic search for companies, contracts, themes',
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'The semantic search query' },
      numResults: { type: 'number', description: 'Number of results to return (default 8)' },
    },
    required: ['query'],
  },
  async execute(args) {
    const apiKey = process.env.EXA_API_KEY
    if (!apiKey) {
      console.warn('[exa] EXA_API_KEY not configured — returning empty result set')
      return '[]'
    }
    try {
      const query = args.query as string
      const numResults = typeof args.numResults === 'number' ? args.numResults : 8
      const res = await fetch(EXA_SEARCH, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey },
        body: JSON.stringify({ query, numResults, contents: { text: false } }),
        signal: AbortSignal.timeout(12000),
      })
      if (!res.ok) return `Error: Exa HTTP ${res.status} ${res.statusText}`
      const data = (await res.json()) as { results?: ExaResult[] }
      const results = data.results ?? []
      return JSON.stringify(
        results.map(r => ({ title: r.title, url: r.url, publishedDate: r.publishedDate })),
      )
    } catch (err) {
      return `Error: ${err instanceof Error ? err.message : String(err)}`
    }
  },
}
