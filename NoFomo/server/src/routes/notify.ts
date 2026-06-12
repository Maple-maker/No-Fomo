import { Router, type Request, type Response } from 'express'
import { getSupabaseAdmin } from '../lib/supabase'
import * as crypto from 'crypto'

const router = Router()

interface NotifyPayload {
  ticker: string
  score: number
  tier: number
  watchlistOnly?: boolean
}

interface ApnsToken {
  apns_token: string
  user_id: string
}

// Sends a single APNs push via HTTP/2 using fetch + JWT bearer auth (p8 key).
// Returns true on 200, false otherwise.
async function sendApnsPush(token: string, payload: object): Promise<boolean> {
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID
  const bundleId = process.env.APNS_BUNDLE_ID
  const privateKeyPem = process.env.APNS_PRIVATE_KEY?.replace(/\\n/g, '\n')

  if (!keyId || !teamId || !bundleId || !privateKeyPem) return false

  const issuedAt = Math.floor(Date.now() / 1000)
  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: keyId })).toString('base64url')
  const claims = Buffer.from(JSON.stringify({ iss: teamId, iat: issuedAt })).toString('base64url')
  const unsigned = `${header}.${claims}`

  const key = crypto.createPrivateKey({ key: privateKeyPem, format: 'pem' })
  const sig = crypto.sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' })
  const jwt = `${unsigned}.${sig.toString('base64url')}`

  const prod = process.env.APNS_PRODUCTION === 'true'
  const host = prod ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'

  const res = await fetch(`https://${host}/3/device/${token}`, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${jwt}`,
      'apns-topic': bundleId,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  })
  return res.status === 200
}

// Single-token push with a custom title/body — used by the thesis matcher.
// Extra `data` keys land at the payload root for the app to read on tap.
export async function sendCustomPush(token: string, title: string, body: string, data?: Record<string, string>): Promise<boolean> {
  return sendApnsPush(token, {
    aps: {
      alert: { title, body },
      badge: 1,
      sound: 'default',
    },
    ...(data ?? {}),
  })
}

// Core dispatch logic — exported so radar route can call it without HTTP round-trip.
export async function dispatchNotifications(opts: NotifyPayload): Promise<{ sent: number; failed: number; reason?: string }> {
  const { ticker, score, tier, watchlistOnly = false } = opts

  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID
  const bundleId = process.env.APNS_BUNDLE_ID
  const privateKey = process.env.APNS_PRIVATE_KEY

  if (!keyId || !teamId || !bundleId || !privateKey) {
    console.log('[notify] APNs not configured — skipping push dispatch')
    return { sent: 0, failed: 0, reason: 'APNs not configured' }
  }

  const supabase = getSupabaseAdmin()

  let tokenQuery = supabase.from('push_tokens').select('apns_token, user_id')

  if (watchlistOnly) {
    const { data: watchlistRows } = await supabase
      .from('user_watchlist')
      .select('user_id')
      .eq('ticker', ticker)
    const userIds = (watchlistRows || []).map((r: { user_id: string }) => r.user_id)
    if (userIds.length === 0) return { sent: 0, failed: 0 }
    tokenQuery = tokenQuery.in('user_id', userIds)
  }

  const { data: tokens, error } = await tokenQuery
  if (error || !tokens?.length) return { sent: 0, failed: 0 }

  const tierLabel = tier === 1 ? 'Tier 1 — Exceptional' : 'Tier 2 — High Conviction'
  const apnsPayload = {
    aps: {
      alert: { title: tierLabel, body: `$${ticker} scored ${Math.round(score)}/100` },
      badge: 1,
      sound: 'default',
    },
  }

  const results = await Promise.allSettled(
    (tokens as ApnsToken[]).map(t => sendApnsPush(t.apns_token, apnsPayload))
  )

  const sent = results.filter(r => r.status === 'fulfilled' && r.value).length
  const failed = results.length - sent
  console.log(`[notify] ${ticker} — sent ${sent}, failed ${failed}`)
  return { sent, failed }
}

// POST /notify — manual trigger for testing
router.post('/', async (req: Request, res: Response) => {
  const { ticker, score, tier, watchlistOnly } = req.body as NotifyPayload
  if (!ticker || score == null || tier == null) {
    res.status(400).json({ error: 'ticker, score, and tier are required' })
    return
  }
  const result = await dispatchNotifications({ ticker, score, tier, watchlistOnly })
  res.json(result)
})

export default router
