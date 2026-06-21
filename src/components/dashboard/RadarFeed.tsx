'use client'

import { useEffect, useRef, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import SignalCard, { type Opportunity } from './SignalCard'

interface Toast {
  id: string
  ticker: string
  tier: number
  bluf: string
}

function ToastBanner({ toasts, onDismiss }: { toasts: Toast[]; onDismiss: (id: string) => void }) {
  if (!toasts.length) return null
  return (
    <div className="fixed top-16 right-4 z-50 flex flex-col gap-2 pointer-events-none" style={{ maxWidth: 340 }}>
      {toasts.map(t => (
        <div
          key={t.id}
          className="pointer-events-auto rounded-xl px-4 py-3 flex items-start gap-3"
          style={{
            background: 'var(--surface-2)',
            border: '1px solid var(--signal)',
            boxShadow: '0 4px 24px rgba(0,0,0,0.4)',
          }}
        >
          <span
            className="text-[10px] font-bold px-1.5 py-0.5 rounded flex-shrink-0 mono mt-0.5"
            style={{
              background: t.tier === 1 ? 'rgba(217,179,106,0.15)' : 'rgba(111,200,214,0.10)',
              color: t.tier === 1 ? '#d9b36a' : '#6fc8d6',
            }}
          >
            T{t.tier}
          </span>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-semibold mono" style={{ color: 'var(--text)' }}>{t.ticker} signal detected</p>
            <p className="text-[11px] mt-0.5 line-clamp-2" style={{ color: 'var(--text-3)' }}>{t.bluf}</p>
          </div>
          <button
            onClick={() => onDismiss(t.id)}
            className="flex-shrink-0 text-xs cursor-pointer"
            style={{ color: 'var(--text-4)' }}
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  )
}

interface Props {
  initialItems: Opportunity[]
}

export default function RadarFeed({ initialItems }: Props) {
  const [items, setItems] = useState<Opportunity[]>(initialItems)
  const [newIds, setNewIds] = useState<Set<string>>(new Set())
  const [toasts, setToasts] = useState<Toast[]>([])
  const [filter, setFilter] = useState<'all' | 1 | 2>('all')
  const supabase = createClient()
  const timerRefs = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map())

  function addToast(op: Opportunity) {
    const id = Date.now().toString()
    const toast: Toast = { id, ticker: op.ticker, tier: op.tier, bluf: op.bluf }
    setToasts(prev => [toast, ...prev].slice(0, 5))
    timerRefs.current.set(id, setTimeout(() => dismissToast(id), 9000))
  }

  function dismissToast(id: string) {
    clearTimeout(timerRefs.current.get(id))
    timerRefs.current.delete(id)
    setToasts(prev => prev.filter(t => t.id !== id))
  }

  useEffect(() => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const channel = (supabase as any)
      .channel('radar-live')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'opportunity_feed' },
        (payload: { new: Opportunity }) => {
          const op = payload.new
          if (!op) return
          setItems(prev => [op, ...prev])
          setNewIds(prev => new Set([...prev, op.id]))
          if (op.tier === 1 || (op.tier === 2 && op.score >= 75)) {
            addToast(op)
          }
          // Pull out new highlight after 10s
          setTimeout(() => setNewIds(prev => { const s = new Set(prev); s.delete(op.id); return s }), 10000)
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    return () => { timerRefs.current.forEach(t => clearTimeout(t)) }
  }, [])

  const filtered = filter === 'all' ? items : items.filter(i => i.tier === filter)

  return (
    <>
      <ToastBanner toasts={toasts} onDismiss={dismissToast} />

      {/* Filter bar */}
      <div className="flex items-center gap-2 mb-4">
        {(['all', 1, 2] as const).map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className="text-xs px-3 py-1.5 rounded-lg transition-colors cursor-pointer"
            style={{
              background: filter === f ? 'var(--surface-2)' : 'transparent',
              color: filter === f ? 'var(--text)' : 'var(--text-3)',
              border: `1px solid ${filter === f ? 'var(--border-2)' : 'transparent'}`,
            }}
          >
            {f === 'all' ? 'All signals' : `Tier ${f}`}
          </button>
        ))}
        <span className="ml-auto text-xs" style={{ color: 'var(--text-4)' }}>
          {filtered.length} signal{filtered.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Feed */}
      {filtered.length === 0 ? (
        <EmptyRadar />
      ) : (
        <div className="flex flex-col gap-3">
          {filtered.map(op => (
            <SignalCard key={op.id} op={op} isNew={newIds.has(op.id)} />
          ))}
        </div>
      )}
    </>
  )
}

function EmptyRadar() {
  return (
    <div
      className="rounded-2xl flex flex-col items-center justify-center py-20 text-center"
      style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}
    >
      {/* Radar sweep SVG */}
      <svg width="56" height="56" viewBox="0 0 56 56" fill="none" className="mb-4">
        <circle cx="28" cy="28" r="26" stroke="var(--border-2)" strokeWidth="1.5" />
        <circle cx="28" cy="28" r="18" stroke="var(--border)" strokeWidth="1" />
        <circle cx="28" cy="28" r="10" stroke="var(--border)" strokeWidth="1" />
        <line x1="28" y1="2" x2="28" y2="54" stroke="var(--border)" strokeWidth="1" />
        <line x1="2" y1="28" x2="54" y2="28" stroke="var(--border)" strokeWidth="1" />
        <path d="M28 28 L28 2" stroke="var(--signal)" strokeWidth="2" strokeLinecap="round" opacity="0.4" />
        <circle cx="28" cy="28" r="2.5" fill="var(--signal)" />
      </svg>
      <p className="text-sm font-medium mb-1" style={{ color: 'var(--text-2)' }}>Radar scanning</p>
      <p className="text-xs max-w-xs" style={{ color: 'var(--text-4)' }}>
        No signals yet. Run the Python radar backend to start detecting opportunities.
        New signals appear here in real time.
      </p>
      <div
        className="mt-6 text-xs px-3 py-1.5 rounded-lg mono"
        style={{ background: 'var(--surface-2)', color: 'var(--text-3)', border: '1px solid var(--border)' }}
      >
        python3 NoFomo/server/radar_mvp.py
      </div>
    </div>
  )
}
