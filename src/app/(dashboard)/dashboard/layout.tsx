import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Topbar from '@/components/dashboard/Topbar'
import Sidebar from '@/components/dashboard/Sidebar'
import type { Database } from '@/lib/types/database'

type ProfileRow = Database['public']['Tables']['profiles']['Row']

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data: profile } = await (supabase as any)
    .from('profiles')
    .select('full_name, avatar_url, timezone')
    .eq('id', user.id)
    .single() as { data: Pick<ProfileRow, 'full_name' | 'avatar_url' | 'timezone'> | null; error: unknown }

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: 'var(--bg)' }}>
      <Sidebar />
      <div className="flex flex-col flex-1 min-w-0 overflow-hidden">
        <Topbar
          userName={profile?.full_name ?? user.email ?? 'Commander'}
          avatarUrl={profile?.avatar_url ?? null}
          timezone={profile?.timezone ?? 'UTC'}
        />
        <main className="flex-1 overflow-y-auto px-6 py-5">
          {children}
        </main>
      </div>
    </div>
  )
}
