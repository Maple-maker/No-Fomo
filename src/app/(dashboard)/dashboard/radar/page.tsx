import { createClient } from '@/lib/supabase/server'
import RadarFeed from '@/components/dashboard/RadarFeed'
import type { Opportunity } from '@/components/dashboard/SignalCard'

export default async function RadarPage() {
  const supabase = await createClient()

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data: feed } = await (supabase as any)
    .from('opportunity_feed')
    .select('id, ticker, company_name, sector, tier, score, triple_signal, bluf, price, upside, market_cap, catalyst, council, bull_case, bear_case, signals, invalidation, published_at, is_premium')
    .in('tier', [1, 2])
    .order('published_at', { ascending: false })
    .limit(50) as { data: Opportunity[] | null }

  return (
    <div>
      {/* Page header */}
      <div className="flex items-center justify-between mb-5">
        <div>
          <h1 className="text-lg font-semibold" style={{ color: 'var(--text)', letterSpacing: '-0.02em' }}>
            Opportunity Radar
          </h1>
          <p className="text-xs mt-0.5" style={{ color: 'var(--text-4)' }}>
            Early signal detection · Updated in real time
          </p>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ background: 'var(--positive)' }} />
          <span className="text-xs" style={{ color: 'var(--text-3)' }}>Live</span>
        </div>
      </div>

      <RadarFeed initialItems={feed ?? []} />
    </div>
  )
}
