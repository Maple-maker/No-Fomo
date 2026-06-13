import { Router, type Request, type Response } from 'express'
import { getSupabaseAdmin } from '../lib/supabase'
import { fetchChartPayload } from '../lib/stockData'

const router = Router()
const CRON_SECRET = process.env.CRON_SECRET || 'nofomo-cron-dev'

function hasCronSecret(req: Request): boolean {
  if (req.query.secret === CRON_SECRET) return true
  const auth = req.headers.authorization || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : auth
  return token === CRON_SECRET || req.body?.secret === CRON_SECRET
}

async function getUserFromRequest(req: Request) {
  const auth = req.headers.authorization || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return null
  const supabase = getSupabaseAdmin()
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return null
  return data.user
}

async function ensureProfile(userId: string, displayName?: string) {
  const supabase = getSupabaseAdmin()
  await supabase.from('user_profiles').upsert({
    user_id: userId,
    display_name: displayName || 'Trader',
    updated_at: new Date().toISOString(),
  } as any, { onConflict: 'user_id' })
}

async function attachProfiles(ideas: Record<string, unknown>[]) {
  if (!ideas.length) return []
  const supabase = getSupabaseAdmin()
  const userIds = [...new Set(ideas.map(i => String(i.user_id)))]
  const { data: profiles } = await (supabase.from('user_profiles') as any)
    .select('user_id, display_name, avatar_url, reputation_score, current_streak')
    .in('user_id', userIds)
  const byUser = Object.fromEntries(((profiles ?? []) as any[]).map((p: any) => [p.user_id, p]))
  return ideas.map(idea => ({
    ...idea,
    profile: byUser[String(idea.user_id)] ?? null,
  }))
}

function scoreIdea(direction: string, entry: number, target: number, exit: number): { won: boolean; score: number } {
  const long = direction === 'long'
  const movedRight = long ? exit >= target : exit <= target
  const pctMove = entry > 0 ? Math.abs((exit - entry) / entry) * 100 : 0
  const score = movedRight ? Math.min(100, Math.round(pctMove * 2)) : -25
  return { won: movedRight, score }
}

router.get('/', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 30, 100)
    const offset = Number(req.query.offset) || 0
    const supabase = getSupabaseAdmin()
    const { data, error } = await supabase
      .from('trade_ideas')
      .select('*')
      .in('status', ['open', 'won', 'lost'])
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)
    if (error) { res.status(500).json({ error: error.message }); return }
    const ideas = await attachProfiles((data ?? []) as Record<string, unknown>[])
    res.json({ ideas, limit, offset })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

router.get('/leaderboard', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 20, 50)
    const supabase = getSupabaseAdmin()
    const { data, error } = await supabase
      .from('user_profiles')
      .select('user_id, display_name, avatar_url, reputation_score, current_streak, longest_streak, win_count, ideas_posted')
      .order('reputation_score', { ascending: false })
      .limit(limit)
    if (error) { res.status(500).json({ error: error.message }); return }
    res.json({ leaderboard: data ?? [] })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

router.post('/', async (req: Request, res: Response) => {
  try {
    const user = await getUserFromRequest(req)
    if (!user) { res.status(401).json({ error: 'Sign in required to post ideas' }); return }

    const ticker = String(req.body?.ticker || '').toUpperCase().trim()
    const body = String(req.body?.body || '').trim()
    const direction = req.body?.direction === 'short' ? 'short' : 'long'
    const targetPrice = Number(req.body?.target_price ?? req.body?.targetPrice)
    const timeframeDays = Number(req.body?.timeframe_days ?? req.body?.timeframeDays ?? 30)

    if (!ticker || !body || body.length > 500) {
      res.status(400).json({ error: 'ticker and body (max 500 chars) required' })
      return
    }
    if (!Number.isFinite(targetPrice) || targetPrice <= 0) {
      res.status(400).json({ error: 'valid target_price required' })
      return
    }

    const chart = await fetchChartPayload(ticker)
    const entryPrice = chart.price > 0 ? chart.price : Number(req.body?.entry_price ?? 0)
    if (!Number.isFinite(entryPrice) || entryPrice <= 0) {
      res.status(400).json({ error: 'Could not fetch entry price' })
      return
    }

    const displayName = String(user.user_metadata?.full_name || user.email?.split('@')[0] || 'Trader')
    await ensureProfile(user.id, displayName)

    const supabase = getSupabaseAdmin()
    const { data, error } = await (supabase.from('trade_ideas') as any).insert({
      user_id: user.id,
      ticker,
      body,
      direction,
      entry_price: entryPrice,
      target_price: targetPrice,
      timeframe_days: Number.isFinite(timeframeDays) && timeframeDays > 0 ? timeframeDays : 30,
      status: 'open',
    }).select('*').single()

    if (error) { res.status(500).json({ error: error.message }); return }

    const { data: prof } = await (supabase.from('user_profiles') as any).select('ideas_posted').eq('user_id', user.id).single()
    await (supabase.from('user_profiles') as any).update({
      ideas_posted: (prof?.ideas_posted ?? 0) + 1,
      updated_at: new Date().toISOString(),
    }).eq('user_id', user.id)

    const [idea] = await attachProfiles([data as Record<string, unknown>])
    res.json({ idea })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

router.post('/:id/vote', async (req: Request, res: Response) => {
  try {
    const user = await getUserFromRequest(req)
    if (!user) { res.status(401).json({ error: 'Sign in required to vote' }); return }

    const ideaId = Number(req.params.id)
    if (!Number.isFinite(ideaId)) { res.status(400).json({ error: 'invalid idea id' }); return }

    const supabase = getSupabaseAdmin()
    const { data: existing } = await supabase
      .from('idea_votes')
      .select('idea_id')
      .eq('idea_id', ideaId)
      .eq('user_id', user.id)
      .maybeSingle()

    const { data: idea } = await (supabase.from('trade_ideas') as any).select('upvote_count').eq('id', ideaId).single()
    const current = idea?.upvote_count ?? 0

    if (existing) {
      await (supabase.from('idea_votes') as any).delete().eq('idea_id', ideaId).eq('user_id', user.id)
      const next = Math.max(0, current - 1)
      await (supabase.from('trade_ideas') as any).update({ upvote_count: next }).eq('id', ideaId)
      res.json({ voted: false, upvote_count: next })
      return
    }

    await (supabase.from('idea_votes') as any).insert({ idea_id: ideaId, user_id: user.id })
    const next = current + 1
    await (supabase.from('trade_ideas') as any).update({ upvote_count: next }).eq('id', ideaId)
    res.json({ voted: true, upvote_count: next })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

router.post('/resolve', async (req: Request, res: Response) => {
  if (!hasCronSecret(req)) {
    res.status(401).json({ error: 'Cron secret required' })
    return
  }
  try {
    const supabase = getSupabaseAdmin()
    const { data: openIdeas, error } = await supabase
      .from('trade_ideas')
      .select('*')
      .eq('status', 'open')
    if (error) { res.status(500).json({ error: error.message }); return }

    const now = Date.now()
    const resolved: Array<{ id: number; status: string; score: number }> = []

    for (const idea of (openIdeas ?? []) as any[]) {
      const created = new Date(idea.created_at).getTime()
      const elapsedDays = (now - created) / (1000 * 60 * 60 * 24)
      if (elapsedDays < idea.timeframe_days) continue

      const chart = await fetchChartPayload(idea.ticker)
      const exit = chart.price
      if (exit <= 0) continue

      const { won, score } = scoreIdea(idea.direction, Number(idea.entry_price), Number(idea.target_price), exit)
      const hybridBonus = (idea.upvote_count ?? 0) * 2
      const finalScore = score + hybridBonus
      const status = won ? 'won' : 'lost'

      await (supabase.from('trade_ideas') as any).update({
        status,
        performance_score: finalScore,
        resolved_at: new Date().toISOString(),
      }).eq('id', idea.id)

      const { data: profile } = await (supabase.from('user_profiles') as any)
        .select('*')
        .eq('user_id', idea.user_id)
        .single()

      if (profile) {
        const p = profile as any
        const newRep = (p.reputation_score ?? 0) + finalScore
        const newResolved = (p.ideas_resolved ?? 0) + 1
        const newWins = (p.win_count ?? 0) + (won ? 1 : 0)
        let streak = p.current_streak ?? 0
        let longest = p.longest_streak ?? 0
        if (won) {
          streak += 1
          longest = Math.max(longest, streak)
        } else {
          streak = 0
        }
        await (supabase.from('user_profiles') as any).update({
          reputation_score: newRep,
          ideas_resolved: newResolved,
          win_count: newWins,
          current_streak: streak,
          longest_streak: longest,
          updated_at: new Date().toISOString(),
        }).eq('user_id', idea.user_id)
      }

      resolved.push({ id: idea.id, status, score: finalScore })
    }

    res.json({ resolvedCount: resolved.length, resolved })
  } catch (err) {
    res.status(500).json({ error: err instanceof Error ? err.message : String(err) })
  }
})

export default router
