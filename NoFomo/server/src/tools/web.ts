import type { ToolDef } from '../agents/types'

export const braveSearch: ToolDef = {
  name: 'web_search',
  description:
    'Search the web for current information. Returns top results with titles, URLs, and content snippets. Use this for company research, news, financial data, and industry analysis.',
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'The search query' },
    },
    required: ['query'],
  },
  async execute(args) {
    const apiKey = process.env.BRAVE_API_KEY
    if (!apiKey) return 'Error: BRAVE_API_KEY not configured'

    try {
      const url = new URL('https://api.search.brave.com/res/v1/web/search')
      url.searchParams.set('q', args.query as string)
      url.searchParams.set('count', '5')

      const res = await fetch(url.toString(), {
        headers: {
          Accept: 'application/json',
          'Accept-Encoding': 'gzip',
          'X-Subscription-Token': apiKey,
        },
      })

      if (!res.ok) return `Brave search error: ${res.status} ${res.statusText}`

      const data = (await res.json()) as {
        web?: { results?: { title: string; url: string; description: string }[] }
      }

      const results = data.web?.results
      if (!results || results.length === 0) return 'No results found.'

      return JSON.stringify(
        results.map(r => ({
          title: r.title,
          url: r.url,
          snippet: r.description.slice(0, 500),
        })),
      )
    } catch (err) {
      return `Search error: ${err instanceof Error ? err.message : String(err)}`
    }
  },
}
