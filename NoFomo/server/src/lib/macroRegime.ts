import { execFile } from 'node:child_process'
import path from 'node:path'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)

export interface MacroContext {
  macro_regime: string          // 'goldilocks' | 'stagflation' | 'recession' | 'overheating' | 'recovery'
  global_gdp_trend: string      // 'accelerating' | 'decelerating' | 'flat'
  defense_spend_trend: string   // 'rising' | 'falling' | 'flat'
  imf_us_gdp_forecast_1y: number | null
  bis_credit_gap_us: number | null
  regime_flags: string[]        // e.g. ['global_slowdown', 'credit_stress']
  scraped_at: string
}

let _cached: MacroContext | null = null
let _cachedAt = 0
const TTL_MS = 24 * 60 * 60 * 1000

export async function getMacroContext(): Promise<MacroContext | null> {
  if (_cached && Date.now() - _cachedAt < TTL_MS) return _cached

  const backendDir = path.resolve(process.cwd(), '..', 'backend')
  const python = process.env.PYTHON_BIN || 'python3'
  try {
    const { stdout } = await execFileAsync(
      python,
      ['macro_scraper.py', '--json'],
      { cwd: backendDir, timeout: 30_000, maxBuffer: 512 * 1024 },
    )
    _cached = JSON.parse(stdout) as MacroContext
    _cachedAt = Date.now()
    return _cached
  } catch (e) {
    console.warn('[macro] scraper failed:', e instanceof Error ? e.message : e)
    return _cached // return stale cache if available rather than null
  }
}
