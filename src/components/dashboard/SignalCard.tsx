'use client'

import { useEffect, useState } from 'react'
import MiniSparkline from './MiniSparkline'

export interface Opportunity {
  id: string
  ticker: string
  company_name: string
  sector: string
  tier: 1 | 2 | 3
  score: number
  triple_signal: boolean
  bluf: string
  price: number
  upside: number
  change_pct?: number
  market_cap: string
  catalyst: string
  council?: { gemini?: string; deepseek?: string; cio?: string }
  bull_case?: string
  bear_case?: string
  signals?: Record<string, boolean | number | string | null>
  invalidation?: string
  published_at: string
  is_premium?: boolean
}

interface ChartPoint { close: number | null; date: string }

const TIER_COLORS: Record<number, { bg: string; text: string; label: string }> = {
  1: { bg: 'rgba(217,179,106,0.15)', text: '#d9b36a', label: 'T1' },
  2: { bg: 'rgba(111,200,214,0.10)', text: '#6fc8d6', label: 'T2' },
  3: { bg: 'rgba(90,100,120,0.10)', text: '#5a6478', label: 'T3' },
}

const SIGNAL_LABELS: Record<string, string> = {
  insider_buying: 'Insider buy',
  analyst_upgrade: 'Analyst upgrade',
  positive_earnings: 'Earnings beat',
  government_contract: 'Gov contract',
  new_product: 'New product',
  strong_growth: 'Strong growth',
  oversold: 'RSI oversold',
  volume_spike: 'Vol surge',
  activist: 'Activist',
  triple_signal: 'Triple signal',
}

const BEARISH_KEYS = ['insider_selling', 'analyst_downgrade', 'negative_earnings', 'regulatory_risk', 'margin_pressure', 'overbought']

function ScoreBar({ score }: { score: number }) {
  const color = score >= 80 ? '#d9b36a' : score >= 65 ? '#6fc8d6' : '#5a6478'
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1 rounded-full" style={{ background: 'var(--surface-3)' }}>
        <div
          className="h-full rounded-full transition-all"
          style={{ width: `${Math.min(100, score)}%`, background: color }}
        />
      </div>
      <span className="text-xs mono flex-shrink-0" style={{ color, letterSpacing: '-0.02em', minWidth: 24, textAlign: 'right' }}>
        {score}
      </span>
    </div>
  )
}

export default function SignalCard({ op, isNew }: { op: Opportunity; isNew?: boolean }) {
  const [chartPoints, setChartPoints] = useState<ChartPoint[]>([])
  const [expanded, setExpanded] = useState(false)

  const tier = TIER_COLORS[op.tier] ?? TIER_COLORS[2]!
  const changePct = op.change_pct ?? 0
  const isUp = changePct >= 0

  const bullishSignals = Object.entries(op.signals ?? {})
    .filter(([k, v]) => v === true && SIGNAL_LABELS[k] && !BEARISH_KEYS.includes(k))
    .map(([k]) => SIGNAL_LABELS[k]!)

  const bearishSignals = Object.entries(op.signals ?? {})
    .filter(([k, v]) => v === true && BEARISH_KEYS.includes(k))
    .map(([k]) => SIGNAL_LABELS[k] ?? k)

  useEffect(() => {
    let cancelled = false
    async function load() {
      try {
        const res = await fetch(`/api/chart?ticker=${op.ticker}&range=1mo`)
        if (!res.ok) return
        const data = await res.json()
        if (!cancelled && data.points?.length) setChartPoints(data.points)
      } catch {}
    }
    load()
    return () => { cancelled = true }
  }, [op.ticker])

  const publishedAt = new Date(op.published_at)
  const age = Math.floor((Date.now() - publishedAt.getTime()) / 60000)
  const ageLabel = age < 60 ? `${age}m ago` : age < 1440 ? `${Math.floor(age / 60)}h ago` : `${Math.floor(age / 1440)}d ago`

  return (
    <div
      className="rounded-2xl cursor-pointer transition-all"
      style={{
        background: 'var(--surface)',
        border: `1px solid ${isNew ? 'rgba(111,200,214,0.35)' : 'var(--border)'}`,
        boxShadow: isNew ? '0 0 20px rgba(111,200,214,0.08)' : 'none',
      }}
      onClick={() => setExpanded(e => !e)}
    >
      {/* Header row */}
      <div className="flex items-center gap-3 px-4 pt-4 pb-2">
        {/* Tier badge */}
        <span
          className="flex-shrink-0 text-[10px] font-bold px-2 py-0.5 rounded-md mono tracking-wider"
          style={{ background: tier.bg, color: tier.text }}
        >
          {tier.label}
        </span>

        {/* Ticker + company */}
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-2">
            <span className="text-sm font-semibold mono" style={{ color: 'var(--text)' }}>{op.ticker}</span>
            <span className="text-xs truncate" style={{ color: 'var(--text-3)' }}>{op.company_name}</span>
          </div>
          <div className="text-[10px] mt-0.5" style={{ color: 'var(--text-4)' }}>
            {op.sector || 'Uncategorized'} · {ageLabel}
          </div>
        </div>

        {/* Triple signal badge */}
        {op.triple_signal && (
          <span
            className="text-[10px] font-semibold px-2 py-0.5 rounded-md"
            style={{ background: 'rgba(217,179,106,0.12)', color: '#d9b36a', border: '1px solid rgba(217,179,106,0.25)' }}
          >
            TRIPLE
          </span>
        )}

        {/* Price block */}
        <div className="flex-shrink-0 text-right">
          <div className="text-sm font-semibold mono" style={{ color: 'var(--text)' }}>
            ${op.price?.toFixed(2) ?? '—'}
          </div>
          <div className="text-[10px] mono" style={{ color: isUp ? 'var(--positive)' : 'var(--negative)' }}>
            {isUp ? '+' : ''}{changePct.toFixed(2)}%
          </div>
        </div>

        {/* Sparkline */}
        <div className="flex-shrink-0">
          {chartPoints.length > 1 ? (
            <MiniSparkline points={chartPoints} width={72} height={28} />
          ) : (
            <div style={{ width: 72, height: 28, background: 'var(--surface-2)', borderRadius: 4 }} />
          )}
        </div>
      </div>

      {/* Score bar */}
      <div className="px-4 pb-3">
        <ScoreBar score={Math.round(op.score)} />
      </div>

      {/* Signals row */}
      <div className="px-4 pb-3 flex flex-wrap gap-1.5">
        {bullishSignals.map(s => (
          <span key={s} className="text-[10px] px-2 py-0.5 rounded-md" style={{ background: 'rgba(95,203,149,0.08)', color: '#5fcb95' }}>
            {s}
          </span>
        ))}
        {bearishSignals.map(s => (
          <span key={s} className="text-[10px] px-2 py-0.5 rounded-md" style={{ background: 'rgba(230,128,120,0.08)', color: '#e68078' }}>
            {s}
          </span>
        ))}
      </div>

      {/* BLUF */}
      <div className="px-4 pb-3">
        <p className="text-xs leading-relaxed" style={{ color: 'var(--text-2)' }}>{op.bluf}</p>
      </div>

      {/* Expanded: bull/bear/invalidation */}
      {expanded && (
        <div className="px-4 pb-4 border-t" style={{ borderColor: 'var(--border)' }}>
          <div className="grid grid-cols-2 gap-3 mt-3">
            {op.bull_case && (
              <div>
                <p className="text-[9px] tracking-widest mb-1" style={{ color: 'var(--positive)' }}>BULL CASE</p>
                <p className="text-[11px] leading-relaxed" style={{ color: 'var(--text-2)' }}>{op.bull_case}</p>
              </div>
            )}
            {op.bear_case && (
              <div>
                <p className="text-[9px] tracking-widest mb-1" style={{ color: 'var(--negative)' }}>BEAR CASE</p>
                <p className="text-[11px] leading-relaxed" style={{ color: 'var(--text-2)' }}>{op.bear_case}</p>
              </div>
            )}
          </div>
          {op.invalidation && (
            <div className="mt-3 px-3 py-2 rounded-lg" style={{ background: 'var(--surface-2)', borderLeft: '2px solid var(--negative)' }}>
              <p className="text-[9px] tracking-widest mb-1" style={{ color: 'var(--negative)' }}>INVALIDATION</p>
              <p className="text-[11px]" style={{ color: 'var(--text-3)' }}>{op.invalidation}</p>
            </div>
          )}
          {op.catalyst && (
            <div className="mt-2">
              <p className="text-[9px] tracking-widest mb-1" style={{ color: 'var(--signal)' }}>CATALYST</p>
              <p className="text-[11px]" style={{ color: 'var(--text-2)' }}>{op.catalyst}</p>
            </div>
          )}
          {op.upside > 0 && (
            <div className="mt-2 flex gap-4">
              <div>
                <p className="text-[9px] tracking-widest" style={{ color: 'var(--text-4)' }}>UPSIDE</p>
                <p className="text-sm font-semibold mono" style={{ color: 'var(--positive)' }}>+{op.upside.toFixed(0)}%</p>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
