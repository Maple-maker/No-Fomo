'use client'

import { useState, useTransition } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Database } from '@/lib/types/database'

type Todo = Database['public']['Tables']['todos']['Row']

const TAG_STYLES: Record<string, { color: string; bg: string; border: string }> = {
  urgent:  { color: '#e68078', bg: 'rgba(230,128,120,0.06)', border: 'rgba(230,128,120,0.3)' },
  focus:   { color: '#6fc8d6', bg: 'rgba(111,200,214,0.06)', border: 'rgba(111,200,214,0.3)' },
  btc:     { color: '#d9b36a', bg: 'rgba(217,179,106,0.06)', border: 'rgba(217,179,106,0.3)' },
  content: { color: '#9b8ce6', bg: 'rgba(155,140,230,0.06)', border: 'rgba(155,140,230,0.3)' },
  health:  { color: '#5fcb95', bg: 'rgba(95,203,149,0.06)',  border: 'rgba(95,203,149,0.3)'  },
}

interface TodosCardProps {
  initialTodos: Todo[]
  userId: string
}

export default function TodosCard({ initialTodos, userId }: TodosCardProps) {
  const [todos, setTodos] = useState(initialTodos)
  const [draft, setDraft] = useState('')
  const [, startTransition] = useTransition()
  const supabase = createClient()

  async function addTodo() {
    const text = draft.trim()
    if (!text) return
    setDraft('')

    const optimistic: Todo = {
      id: `temp-${Date.now()}`,
      user_id: userId,
      text,
      done: false,
      source: 'manual',
      tags: [],
      display_order: 0,
      created_at: new Date().toISOString(),
      completed_at: null,
    }
    setTodos(prev => [optimistic, ...prev])

    const { data } = await supabase
      .from('todos')
      .insert({ user_id: userId, text, source: 'manual' })
      .select()
      .single()

    if (data) {
      setTodos(prev => prev.map(t => t.id === optimistic.id ? data : t))
    }
  }

  async function completeTodo(id: string) {
    setTodos(prev => prev.filter(t => t.id !== id))
    startTransition(async () => {
      await supabase
        .from('todos')
        .update({ done: true, completed_at: new Date().toISOString() })
        .eq('id', id)
    })
  }

  return (
    <div className="rounded-2xl flex flex-col"
      style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}>

      {/* Header */}
      <div className="flex items-center justify-between px-5 py-4"
        style={{ borderBottom: '1px solid var(--border)' }}>
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full" style={{ background: 'var(--signal)' }} />
          <span className="text-sm font-medium" style={{ color: 'var(--text)' }}>
            Today&apos;s Priorities
          </span>
        </div>
        <span className="text-xs" style={{ color: 'var(--text-3)' }}>
          {todos.length} item{todos.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Todo list */}
      <div className="flex flex-col divide-y overflow-y-auto max-h-96"
        style={{ divideColor: 'var(--border)' }}>
        {todos.length === 0 && (
          <p className="px-5 py-8 text-sm text-center" style={{ color: 'var(--text-4)' }}>
            Nothing pending — clean slate.
          </p>
        )}
        {todos.map(todo => (
          <div key={todo.id} className="flex items-start gap-3 px-5 py-3 group">
            <button
              onClick={() => completeTodo(todo.id)}
              className="mt-0.5 w-4 h-4 rounded flex-shrink-0 flex items-center justify-center transition-all border"
              style={{
                borderColor: 'var(--border-2)',
                background: 'transparent',
              }}
            />
            <div className="flex-1 min-w-0">
              <p className="text-sm leading-snug" style={{ color: 'var(--text)' }}>
                {todo.text}
              </p>
              {todo.tags.length > 0 && (
                <div className="flex gap-1 mt-1 flex-wrap">
                  {todo.tags.map(tag => {
                    const s = TAG_STYLES[tag] ?? TAG_STYLES.focus
                    return (
                      <span key={tag}
                        className="text-[10px] px-1.5 py-0.5 rounded font-medium uppercase tracking-wide"
                        style={{ color: s.color, background: s.bg, border: `1px solid ${s.border}` }}>
                        {tag}
                      </span>
                    )
                  })}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Add input */}
      <div className="px-5 py-3 flex gap-2" style={{ borderTop: '1px solid var(--border)' }}>
        <input
          value={draft}
          onChange={e => setDraft(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && addTodo()}
          placeholder="Add item…"
          className="flex-1 text-sm bg-transparent outline-none placeholder:opacity-40"
          style={{ color: 'var(--text)' }}
        />
        <button
          onClick={addTodo}
          className="w-7 h-7 rounded-lg flex items-center justify-center text-sm font-medium flex-shrink-0 transition-all"
          style={{ background: 'var(--signal)', color: 'var(--bg)' }}
        >
          +
        </button>
      </div>
    </div>
  )
}
