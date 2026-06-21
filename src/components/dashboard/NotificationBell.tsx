'use client'

import { useEffect, useRef, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Opportunity } from './SignalCard'

const STORAGE_KEY = 'nofomo_last_read'

interface Alert {
  id: string
  ticker: string
  tier: number
  bluf: string
  published_at: string
}

export default function NotificationBell() {
  const [alerts, setAlerts] = useState<Alert[]>([])
  const [unread, setUnread] = useState(0)
  const [open, setOpen] = useState(false)
  const panelRef = useRef<HTMLDivElement>(null)
  const supabase = createClient()

  function getLastRead(): number {
    try { return parseInt(localStorage.getItem(STORAGE_KEY) ?? '0') } catch { return 0 }
  }

  function markRead() {
    const now = Date.now()
    try { localStorage.setItem(STORAGE_KEY, String(now)) } catch {}
    setUnread(0)
  }

  // Load recent alerts on mount
  useEffect(() => {
    async function loadRecent() {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data } = await (supabase as any)
        .from('opportunity_feed')
        .select('id, ticker, tier, bluf, published_at')
        .in('tier', [1, 2])
        .order('published_at', { ascending: false })
        .limit(20) as { data: Alert[] | null }

      if (!data) return
      setAlerts(data)

      const lastRead = getLastRead()
      const unreadCount = data.filter(a => new Date(a.published_at).getTime() > lastRead).length
      setUnread(unreadCount)
    }
    loadRecent()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Subscribe to new opportunities
  useEffect(() => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const channel = (supabase as any)
      .channel('notif-bell')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'opportunity_feed' },
        (payload: { new: Opportunity }) => {
          const op = payload.new
          if (!op || (op.tier !== 1 && op.tier !== 2)) return
          const alert: Alert = { id: op.id, ticker: op.ticker, tier: op.tier, bluf: op.bluf, published_at: op.published_at }
          setAlerts(prev => [alert, ...prev].slice(0, 20))
          setUnread(n => n + 1)
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Close on outside click
  useEffect(() => {
    if (!open) return
    function handle(e: MouseEvent) {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handle)
    return () => document.removeEventListener('mousedown', handle)
  }, [open])

  function handleOpen() {
    setOpen(o => !o)
    if (!open) markRead()
  }

  const age = (ts: string) => {
    const mins = Math.floor((Date.now() - new Date(ts).getTime()) / 60000)
    return mins < 60 ? `${mins}m` : mins < 1440 ? `${Math.floor(mins / 60)}h` : `${Math.floor(mins / 1440)}d`
  }

  return (
    <div className="relative" ref={panelRef}>
      <button
        onClick={handleOpen}
        className="relative w-8 h-8 rounded-lg flex items-center justify-center transition-colors cursor-pointer"
        style={{ color: 'var(--text-3)', background: open ? 'var(--surface-2)' : 'transparent' }}
        aria-label="Notifications"
      >
        {/* Bell icon */}
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path d="M8 1.5C5.515 1.5 3.5 3.515 3.5 6V9.5L2 11H14L12.5 9.5V6C12.5 3.515 10.485 1.5 8 1.5Z"
            stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
          <path d="M6.5 11C6.5 11.828 7.172 12.5 8 12.5C8.828 12.5 9.5 11.828 9.5 11"
            stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"/>
        </svg>
        {unread > 0 && (
          <span
            className="absolute -top-0.5 -right-0.5 min-w-[14px] h-3.5 rounded-full flex items-center justify-center text-[9px] font-bold mono px-1"
            style={{ background: 'var(--signal)', color: 'var(--bg)' }}
          >
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {open && (
        <div
          className="absolute right-0 top-10 rounded-xl overflow-hidden z-50"
          style={{
            width: 320,
            background: 'var(--surface)',
            border: '1px solid var(--border-2)',
            boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
          }}
        >
          <div className="flex items-center justify-between px-4 py-3" style={{ borderBottom: '1px solid var(--border)' }}>
            <span className="text-xs font-semibold" style={{ color: 'var(--text)' }}>Signal Alerts</span>
            <span className="text-[10px]" style={{ color: 'var(--text-4)' }}>{alerts.length} recent</span>
          </div>
          <div className="overflow-y-auto" style={{ maxHeight: 360 }}>
            {alerts.length === 0 ? (
              <p className="py-8 text-center text-xs" style={{ color: 'var(--text-4)' }}>No alerts yet</p>
            ) : (
              alerts.map(a => (
                <div key={a.id} className="flex items-start gap-3 px-4 py-3" style={{ borderBottom: '1px solid var(--border)' }}>
                  <span
                    className="text-[9px] font-bold px-1.5 py-0.5 rounded mono flex-shrink-0 mt-0.5"
                    style={{
                      background: a.tier === 1 ? 'rgba(217,179,106,0.15)' : 'rgba(111,200,214,0.10)',
                      color: a.tier === 1 ? '#d9b36a' : '#6fc8d6',
                    }}
                  >
                    T{a.tier}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold mono" style={{ color: 'var(--text)' }}>{a.ticker}</p>
                    <p className="text-[10px] mt-0.5 line-clamp-2" style={{ color: 'var(--text-3)' }}>{a.bluf}</p>
                  </div>
                  <span className="text-[9px] flex-shrink-0 mt-0.5" style={{ color: 'var(--text-4)' }}>{age(a.published_at)}</span>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  )
}
