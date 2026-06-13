import { getSupabaseAdmin } from './supabase'
import { ensureChartHistory, MIN_CHART_FLOOR } from './stockData'

export type BackfillResult = {
  scanned: number
  patched: number
  skipped: number
  errors: string[]
  dryRun: boolean
}

export async function backfillCharts(dryRun = true): Promise<BackfillResult> {
  const supabase = getSupabaseAdmin()
  const { data, error } = await supabase
    .from('radar_opportunities')
    .select('id, ticker, data_snapshot')

  if (error) throw new Error(`Supabase read failed: ${error.message}`)

  const rows = (data ?? []) as Array<{ id: number; ticker: string; data_snapshot: Record<string, unknown> }>
  const result: BackfillResult = { scanned: rows.length, patched: 0, skipped: 0, errors: [], dryRun }

  for (const row of rows) {
    const ds = row.data_snapshot ?? {}
    const existing = Array.isArray(ds.price_history) ? (ds.price_history as number[]) : []
    if (existing.length >= MIN_CHART_FLOOR) {
      result.skipped++
      continue
    }

    try {
      const chart = await ensureChartHistory(row.ticker)
      if (chart.closes.length < MIN_CHART_FLOOR) {
        result.errors.push(`${row.ticker}: only ${chart.closes.length} chart points`)
        continue
      }
      const price_history = chart.closes.map(c => Math.round(c * 100) / 100)
      if (!dryRun) {
        const { error: patchErr } = await (supabase.from('radar_opportunities') as any)
          .update({ data_snapshot: { ...ds, price_history } })
          .eq('id', row.id)
        if (patchErr) {
          result.errors.push(`${row.ticker}: ${patchErr.message}`)
          continue
        }
      }
      result.patched++
      console.log(`[backfillCharts] ${dryRun ? 'would patch' : 'patched'} ${row.ticker} (${price_history.length} points)`)
    } catch (e) {
      result.errors.push(`${row.ticker}: ${e instanceof Error ? e.message : String(e)}`)
    }
  }

  return result
}
