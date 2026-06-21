import { execFile } from 'node:child_process'
import path from 'node:path'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)

export type RadarV2ShadowResult = {
  dry_run: boolean
  results: Array<{
    ticker: string
    radar_score: number
    gate_pass: boolean
    category_scores: Record<string, number>
    confluence: {
      k: number
      multiplier: number
      triple_signal: boolean
      categories: string[]
    }
    crowding: {
      value: number
      penalty_applied: number
    }
    signals: Array<{
      type: string
      category: string
      evidence: string
      source_url: string
      decayed_score: number
      age_days: number
      direction: number
    }>
    regime_flags: string[]
    reprice_gap: Record<string, unknown> | null
  }>
}

export async function runRadarV2Shadow(ticker: string): Promise<RadarV2ShadowResult | null> {
  if (process.env.RADAR_V2_SHADOW !== '1') return null

  const backendDir = path.resolve(process.cwd(), '..', 'backend')
  const python = process.env.PYTHON_BIN || 'python3'
  const { stdout } = await execFileAsync(
    python,
    ['-m', 'radar_v2.run_scan', '--tickers', ticker, '--days', '30', '--dry-run'],
    {
      cwd: backendDir,
      timeout: 120_000,
      maxBuffer: 1024 * 1024,
    },
  )
  return JSON.parse(stdout) as RadarV2ShadowResult
}
