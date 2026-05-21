'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

interface AccountRow {
  id: string
  name: string
  type: string
  value: number
  color: string
  pct: number
}

interface PortfolioState {
  total: number
  accounts: AccountRow[]
  loading: boolean
}

const ACCOUNT_COLORS: Record<string, string> = {
  'btc':          '#D9B36A',
  'roth-ira':     '#9B8CE6',
  'rh-taxable':   '#6FC8D6',
  'fixed-income': '#5FCB95',
  'alt-crypto':   '#F0A05A',
}

function fmt(n: number) {
  return '$' + Math.round(n).toLocaleString('en-US')
}

function DonutChart({ accounts, total }: { accounts: AccountRow[]; total: number }) {
  useEffect(() => {
    const canvas = document.getElementById('portfolio-donut') as HTMLCanvasElement | null
    if (!canvas || accounts.length === 0) return

    const dpr = window.devicePixelRatio || 1
    const size = 140
    canvas.width = size * dpr
    canvas.height = size * dpr
    canvas.style.width = size + 'px'
    canvas.style.height = size + 'px'

    const ctx = canvas.getContext('2d')!
    ctx.scale(dpr, dpr)

    const cx = size / 2, cy = size / 2, r = 62, inner = 41
    let angle = -Math.PI / 2
    const gap = 0.04

    for (const a of accounts) {
      const sweep = a.pct * Math.PI * 2 - gap
      if (sweep <= 0) continue
      ctx.beginPath()
      ctx.arc(cx, cy, r, angle + gap / 2, angle + sweep)
      ctx.arc(cx, cy, inner, angle + sweep, angle + gap / 2, true)
      ctx.closePath()
      ctx.fillStyle = a.color
      ctx.shadowColor = a.color
      ctx.shadowBlur = 10
      ctx.fill()
      ctx.shadowBlur = 0
      angle += sweep + gap
    }
  }, [accounts])

  return (
    <div className="relative flex-shrink-0" style={{ width: 140, height: 140 }}>
      <canvas id="portfolio-donut" />
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <span className="text-xs font-semibold mono" style={{ color: 'var(--text)', letterSpacing: '-0.02em' }}>
          {fmt(total)}
        </span>
        <span className="text-[8px] tracking-widest mt-0.5" style={{ color: 'var(--text-3)' }}>
          TOTAL
        </span>
      </div>
    </div>
  )
}

export default function PortfolioCard({ userId }: { userId: string }) {
  const [state, setState] = useState<PortfolioState>({ total: 0, accounts: [], loading: true })
  const supabase = createClient()

  useEffect(() => {
    async function load() {
      const { data: accts } = await supabase
        .from('accounts')
        .select('id, slug, name, type, color, holdings(ticker, shares, cost_per_share, coingecko_id)')
        .eq('user_id', userId)
        .order('display_order')

      if (!accts || accts.length === 0) {
        setState({ total: 0, accounts: [], loading: false })
        return
      }

      // Collect tickers for price fetch
      const tickers = [...new Set(
        accts.flatMap(a => (a.holdings as any[]).map((h: any) => h.ticker))
      )]

      // Fetch prices from our API route
      let prices: Record<string, number> = {}
      try {
        const res = await fetch(`/api/prices?tickers=${tickers.join(',')}`)
        if (res.ok) prices = await res.json()
      } catch {}

      const rows: AccountRow[] = accts.map(a => {
        const value = (a.holdings as any[]).reduce((sum: number, h: any) => {
          const price = prices[h.ticker] ?? 0
          return sum + (h.shares ?? 0) * price
        }, 0)
        return {
          id: a.slug,
          name: a.name,
          type: a.type,
          value,
          color: ACCOUNT_COLORS[a.slug] ?? a.color,
          pct: 0,
        }
      })

      const total = rows.reduce((s, r) => s + r.value, 0)
      rows.forEach(r => { r.pct = total > 0 ? r.value / total : 0 })

      setState({ total, accounts: rows, loading: false })
    }

    load()
    const interval = setInterval(load, 5 * 60 * 1000)
    return () => clearInterval(interval)
  }, [userId])

  if (state.loading) {
    return (
      <div className="rounded-2xl p-5 h-64 flex items-center justify-center"
        style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}>
        <div className="w-5 h-5 rounded-full border-2 animate-spin"
          style={{ borderColor: 'var(--border-2)', borderTopColor: 'var(--signal)' }} />
      </div>
    )
  }

  return (
    <div className="rounded-2xl" style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}>
      {/* Header */}
      <div className="flex items-center justify-between px-5 py-4"
        style={{ borderBottom: '1px solid var(--border)' }}>
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full" style={{ background: 'var(--positive)' }} />
          <span className="text-sm font-medium" style={{ color: 'var(--text)' }}>Portfolio</span>
        </div>
        <span className="text-xs" style={{ color: 'var(--text-3)' }}>LIVE</span>
      </div>

      <div className="p-5 flex gap-6">
        {/* Left: total */}
        <div className="flex-1">
          <p className="text-[10px] tracking-widest mb-1" style={{ color: 'var(--text-3)' }}>TOTAL NET WORTH</p>
          <p className="text-4xl font-light mono" style={{ color: 'var(--text)', letterSpacing: '-0.03em' }}>
            {fmt(state.total)}
          </p>
        </div>

        {/* Right: donut */}
        <div className="flex flex-col items-center gap-3">
          <p className="text-[9px] tracking-wider self-start" style={{ color: 'var(--text-3)' }}>ALLOCATION</p>
          <DonutChart accounts={state.accounts} total={state.total} />
        </div>
      </div>

      {/* Legend */}
      <div className="px-5 pb-2 border-t" style={{ borderColor: 'var(--border)' }}>
        {state.accounts.filter(a => a.value > 0).map(a => (
          <div key={a.id} className="flex items-center justify-between py-2 border-b last:border-0"
            style={{ borderColor: 'rgba(255,255,255,0.03)' }}>
            <div className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: a.color }} />
              <span className="text-xs" style={{ color: 'var(--text-3)' }}>{a.name}</span>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-xs mono" style={{ color: 'var(--text-2)' }}>{fmt(a.value)}</span>
              <span className="text-[10px]" style={{ color: 'var(--text-4)' }}>{(a.pct * 100).toFixed(1)}%</span>
            </div>
          </div>
        ))}
        {state.accounts.length === 0 && (
          <p className="py-6 text-sm text-center" style={{ color: 'var(--text-4)' }}>
            No accounts yet — add them in Settings.
          </p>
        )}
      </div>
    </div>
  )
}
