'use client'

import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'

export default function LoginPage() {
  const [loading, setLoading] = useState(false)
  const supabase = createClient()

  async function signInWithGoogle() {
    setLoading(true)
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`,
        scopes: 'openid email profile https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/gmail.readonly',
      },
    })
  }

  return (
    <div className="min-h-screen flex items-center justify-center" style={{ background: 'var(--bg)' }}>
      <div className="w-full max-w-sm px-6">

        {/* Logo */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-3 mb-4">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center"
              style={{ background: 'var(--signal)', boxShadow: '0 0 20px rgba(111,200,214,0.3)' }}>
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                <path d="M8 1L14 4.5V11.5L8 15L2 11.5V4.5L8 1Z"
                  stroke="var(--bg)" strokeWidth="1.5" fill="none"/>
                <circle cx="8" cy="8" r="2" fill="var(--bg)"/>
              </svg>
            </div>
            <span className="text-xl font-semibold tracking-widest" style={{ color: 'var(--text)', letterSpacing: '0.25em' }}>
              AEGIS
            </span>
          </div>
          <p className="text-sm" style={{ color: 'var(--text-3)' }}>
            Personal intelligence system
          </p>
        </div>

        {/* Card */}
        <div className="rounded-2xl p-8"
          style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}>
          <h1 className="text-lg font-medium mb-1" style={{ color: 'var(--text)' }}>
            Sign in
          </h1>
          <p className="text-sm mb-8" style={{ color: 'var(--text-3)' }}>
            Connect with Google to access your command center.
          </p>

          <button
            onClick={signInWithGoogle}
            disabled={loading}
            className="w-full flex items-center justify-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition-all"
            style={{
              background: loading ? 'var(--surface-3)' : 'var(--surface-2)',
              border: '1px solid var(--border-2)',
              color: 'var(--text)',
              cursor: loading ? 'not-allowed' : 'pointer',
            }}
          >
            {loading ? (
              <div className="w-4 h-4 rounded-full border-2 animate-spin"
                style={{ borderColor: 'var(--text-3)', borderTopColor: 'var(--signal)' }} />
            ) : (
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
                <path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z" fill="#4285F4"/>
                <path d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z" fill="#34A853"/>
                <path d="M3.964 10.707A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.707V4.961H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.039l3.007-2.332z" fill="#FBBC05"/>
                <path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>
              </svg>
            )}
            {loading ? 'Connecting…' : 'Continue with Google'}
          </button>
        </div>

        <p className="text-center text-xs mt-6" style={{ color: 'var(--text-4)' }}>
          Your data is private and never shared.
        </p>
      </div>
    </div>
  )
}
