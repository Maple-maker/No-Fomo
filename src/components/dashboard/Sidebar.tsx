'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

const NAV = [
  {
    href: '/dashboard',
    label: 'Home',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <rect x="1" y="1" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.4"/>
        <rect x="11" y="1" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.4"/>
        <rect x="1" y="11" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.4"/>
        <rect x="11" y="11" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.4"/>
      </svg>
    ),
  },
  {
    href: '/dashboard/portfolio',
    label: 'Portfolio',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <polyline points="1,13 5,8 8,10 12,5 17,9" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    ),
  },
  {
    href: '/dashboard/brief',
    label: 'Brief',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <rect x="3" y="2" width="12" height="14" rx="2" stroke="currentColor" strokeWidth="1.4"/>
        <line x1="6" y1="6" x2="12" y2="6" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
        <line x1="6" y1="9" x2="12" y2="9" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
        <line x1="6" y1="12" x2="9" y2="12" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    href: '/dashboard/settings',
    label: 'Settings',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <circle cx="9" cy="9" r="2.5" stroke="currentColor" strokeWidth="1.4"/>
        <path d="M9 1v2M9 15v2M1 9h2M15 9h2M3.22 3.22l1.42 1.42M13.36 13.36l1.42 1.42M14.78 3.22l-1.42 1.42M4.64 13.36l-1.42 1.42"
          stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
      </svg>
    ),
  },
]

export default function Sidebar() {
  const pathname = usePathname()

  return (
    <nav className="flex flex-col items-center w-14 py-4 gap-1 flex-shrink-0"
      style={{ borderRight: '1px solid var(--border)', background: 'var(--surface)' }}>

      {/* AEGIS logo mark */}
      <div className="w-8 h-8 rounded-lg flex items-center justify-center mb-4 flex-shrink-0"
        style={{ background: 'var(--signal)', boxShadow: '0 0 16px rgba(111,200,214,0.25)' }}>
        <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
          <path d="M8 1L14 4.5V11.5L8 15L2 11.5V4.5L8 1Z" stroke="var(--bg)" strokeWidth="1.5"/>
          <circle cx="8" cy="8" r="2" fill="var(--bg)"/>
        </svg>
      </div>

      {NAV.map(({ href, label, icon }) => {
        const active = pathname === href || (href !== '/dashboard' && pathname.startsWith(href))
        return (
          <Link key={href} href={href} title={label}
            className="w-9 h-9 rounded-xl flex items-center justify-center transition-all"
            style={{
              color: active ? 'var(--signal)' : 'var(--text-3)',
              background: active ? 'rgba(111,200,214,0.08)' : 'transparent',
            }}>
            {icon}
          </Link>
        )
      })}
    </nav>
  )
}
