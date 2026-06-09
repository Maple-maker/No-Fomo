// ── Layered AI council routing (budget / speed / full) ──
// Auto-selects the council mode from signal strength. Higher conviction → more models.

export type CouncilMode = 'budget' | 'speed' | 'full'

export interface ModeConfig {
  mode: CouncilMode
  models: string[]
}

const CONFIGS: Record<CouncilMode, ModeConfig> = {
  budget: { mode: 'budget', models: ['deepseek', 'deepseek', 'claude'] },
  speed: { mode: 'speed', models: ['gemini-flash', 'deepseek', 'claude'] },
  full: { mode: 'full', models: ['gemini-pro', 'deepseek', 'grok', 'claude-opus'] },
}

/**
 * Select council mode. Explicit override wins; otherwise derived from signal strength:
 *   full   — Tier 1, triple-signal, or score ≥ 80
 *   speed  — score 65–79
 *   budget — score < 65
 */
export function selectMode(
  override: CouncilMode | undefined,
  signal: { score?: number; tier?: number; tripleSignal?: boolean },
): ModeConfig {
  if (override && CONFIGS[override]) return CONFIGS[override]
  const score = signal.score ?? 50
  const tier = signal.tier ?? 2
  if (signal.tripleSignal || tier === 1 || score >= 80) return CONFIGS.full
  if (score >= 65) return CONFIGS.speed
  return CONFIGS.budget
}
