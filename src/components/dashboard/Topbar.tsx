'use client'

import { useEffect, useState } from 'react'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

interface TopbarProps {
  userName: string
  avatarUrl: string | null
  timezone: string
}

function useClock(timezone: string) {
  const [time, setTime] = useState('')
  const [greeting, setGreeting] = useState('')
  const [date, setDate] = useState('')

  useEffect(() => {
    function tick() {
      const now = new Date()
      const h = now.getHours()
      setGreeting(h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening')
      setTime(now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', timeZone: timezone }))
      setDate(now.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', timeZone: timezone }).toUpperCase())
    }
    tick()
    const id = setInterval(tick, 10000)
    return () => clearInterval(id)
  }, [timezone])

  return { time, greeting, date }
}

export default function Topbar({ userName, avatarUrl, timezone }: TopbarProps) {
  const { time, greeting, date } = useClock(timezone)
  const firstName = userName.split(' ')[0]
  const router = useRouter()
  const supabase = createClient()

  async function signOut() {
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <header className="flex items-center justify-between px-6 h-14 flex-shrink-0"
      style={{ borderBottom: '1px solid var(--border)', background: 'var(--surface)' }}>

      {/* Left: greeting */}
      <div className="flex items-center gap-3">
        <div className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ background: 'var(--positive)' }} />
        <span className="text-sm font-medium" style={{ color: 'var(--text)' }}>
          {greeting}, {firstName}.
        </span>
        <span className="text-xs" style={{ color: 'var(--text-3)' }}>
          {date} · {time}
        </span>
      </div>

      {/* Right: user */}
      <div className="flex items-center gap-2">
        <button
          onClick={signOut}
          className="text-xs px-3 py-1 rounded-lg transition-colors"
          style={{ color: 'var(--text-3)', background: 'transparent', border: '1px solid var(--border)' }}
        >
          Sign out
        </button>
        {avatarUrl ? (
          <Image src={avatarUrl} alt={userName} width={28} height={28}
            className="rounded-full" style={{ outline: '1px solid var(--border-2)' }} />
        ) : (
          <div className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold"
            style={{ background: 'var(--signal)', color: 'var(--bg)' }}>
            {firstName[0]?.toUpperCase()}
          </div>
        )}
      </div>
    </header>
  )
}
