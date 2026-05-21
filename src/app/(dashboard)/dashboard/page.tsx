import { createClient } from '@/lib/supabase/server'
import PortfolioCard from '@/components/dashboard/PortfolioCard'
import TodosCard from '@/components/dashboard/TodosCard'

export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  // Fetch todos server-side for initial render
  const { data: todos } = await supabase
    .from('todos')
    .select('*')
    .eq('user_id', user.id)
    .eq('done', false)
    .order('display_order', { ascending: true })
    .order('created_at', { ascending: false })

  return (
    <div className="grid grid-cols-12 gap-5">
      {/* Row 1: Priorities + Portfolio */}
      <div className="col-span-4">
        <TodosCard initialTodos={todos ?? []} userId={user.id} />
      </div>
      <div className="col-span-8">
        <PortfolioCard userId={user.id} />
      </div>

      {/* Placeholder rows — Calendar, Brief, etc. added in future weeks */}
      <div className="col-span-12 rounded-2xl h-40 flex items-center justify-center text-sm"
        style={{ background: 'var(--surface)', border: '1px solid var(--border)', color: 'var(--text-4)' }}>
        Calendar · coming week 4
      </div>
    </div>
  )
}
