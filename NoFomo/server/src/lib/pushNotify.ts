/**
 * pushNotify.ts — APNs push notification sender for No Fomo
 *
 * Entry points:
 *   notifyIfQualifying(row)  — applies No Fomo notify policy, sends to all registered tokens
 *   sendTestPush(token, ticker) — single-token push for manual verification
 *
 * Env contract (all required for sends; missing any → clean no-op):
 *   APNS_KEY_PATH   — absolute path to .p8 auth key from App Store Connect → Keys
 *                     (enable "Apple Push Notifications service" when generating)
 *   APNS_KEY_P8     — alternative: inline .p8 PEM content (use if path not viable)
 *                     One of APNS_KEY_PATH or APNS_KEY_P8 must be set.
 *   APNS_KEY_ID     — 10-char Key ID shown in App Store Connect
 *   APNS_TEAM_ID    — 10-char Team ID from App Store Connect → Membership
 *   APNS_BUNDLE_ID  — app bundle ID (default: com.nofomodev.app)
 *   APNS_ENV        — 'development' → sandbox; 'production' → live (default: development)
 *
 * APNs token-based auth requires the .p8 from:
 *   App Store Connect → Users and Access → Integrations → Keys
 *   Click "+" → enable "Apple Push Notifications service" → download once.
 */

import * as crypto from 'crypto'
import * as fs from 'fs'
import { getSupabaseAdmin } from './supabase'

// ── Notify policy (from NoFomo/CLAUDE.md "When to notify") ─────────────────
// Tier 1 — always
// Tier 2 — if catalyst_score >= 8 OR all four scores (asymmetry/conviction/catalyst/management) >= 7
// Tier 3 — never

function meetsNotifyPolicy(row: { tier: number; data_snapshot: any }): boolean {
  const { tier, data_snapshot } = row
  if (tier === 1) return true
  if (tier === 3) return false
  if (tier === 2) {
    const catalystScore: number = data_snapshot?.catalyst_score ?? 0
    if (catalystScore >= 8) return true
    const asymmetry: number = data_snapshot?.asymmetry_score ?? 0
    const conviction: number = data_snapshot?.conviction_score ?? 0
    const catalyst: number = data_snapshot?.catalyst_score ?? 0
    const management: number = data_snapshot?.management_score ?? 0
    if (asymmetry >= 7 && conviction >= 7 && catalyst >= 7 && management >= 7) return true
    return false
  }
  // Unknown tier — skip
  return false
}

// ── APNs JWT (ES256, cached ~55 min) ──────────────────────────────────────

interface JwtCache {
  token: string
  issuedAt: number  // unix seconds
}

let jwtCache: JwtCache | null = null
const JWT_TTL_SECONDS = 55 * 60  // 55 min; APNs accepts up to 60

function buildJwt(privateKeyPem: string, keyId: string, teamId: string): string {
  const now = Math.floor(Date.now() / 1000)

  // Return cached token if still fresh
  if (jwtCache && now - jwtCache.issuedAt < JWT_TTL_SECONDS) {
    return jwtCache.token
  }

  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: keyId })).toString('base64url')
  const claims = Buffer.from(JSON.stringify({ iss: teamId, iat: now })).toString('base64url')
  const unsigned = `${header}.${claims}`

  const key = crypto.createPrivateKey({ key: privateKeyPem, format: 'pem' })
  // dsaEncoding: 'ieee-p1363' produces the fixed-length r||s format APNs requires
  const sig = crypto.sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' })
  const jwt = `${unsigned}.${sig.toString('base64url')}`

  jwtCache = { token: jwt, issuedAt: now }
  return jwt
}

// ── Load private key (path or inline) ────────────────────────────────────

function loadPrivateKey(): string | null {
  const keyPath = process.env.APNS_KEY_PATH
  const keyInline = process.env.APNS_KEY_P8

  if (keyPath) {
    try {
      return fs.readFileSync(keyPath, 'utf8')
    } catch (e) {
      console.error(`[push] Failed to read APNS_KEY_PATH (${keyPath}):`, e instanceof Error ? e.message : e)
      return null
    }
  }

  if (keyInline) {
    // Support both raw PEM and escaped-newline format (common in env vars)
    return keyInline.replace(/\\n/g, '\n')
  }

  return null
}

// ── Resolve APNs host from env ────────────────────────────────────────────

function apnsHost(): string {
  const env = process.env.APNS_ENV ?? 'development'
  return env === 'production'
    ? 'api.push.apple.com'
    : 'api.sandbox.push.apple.com'
}

// ── Single-device push (returns true on HTTP 200) ────────────────────────

async function sendOnePush(
  token: string,
  payload: object,
  jwt: string,
  bundleId: string,
): Promise<boolean> {
  const host = apnsHost()
  const url = `https://${host}/3/device/${token}`

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        authorization: `bearer ${jwt}`,
        'apns-topic': bundleId,
        'apns-push-type': 'alert',
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    if (res.status !== 200) {
      let detail = ''
      try { detail = await res.text() } catch {}
      console.warn(`[push] token ${token.slice(0, 8)}… → HTTP ${res.status} ${detail}`)
    }

    return res.status === 200
  } catch (e) {
    console.warn(`[push] token ${token.slice(0, 8)}… → network error:`, e instanceof Error ? e.message : e)
    return false
  }
}

// ── Config guard — returns null if required vars are missing ─────────────

interface ApnsConfig {
  privateKeyPem: string
  keyId: string
  teamId: string
  bundleId: string
}

function loadConfig(): ApnsConfig | null {
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID
  const bundleId = process.env.APNS_BUNDLE_ID ?? 'com.nofomodev.app'
  const privateKeyPem = loadPrivateKey()

  if (!keyId || !teamId || !privateKeyPem) {
    console.log('[push] APNs not configured — skipping')
    return null
  }

  return { privateKeyPem, keyId, teamId, bundleId }
}

// ── Public API ────────────────────────────────────────────────────────────

/**
 * notifyIfQualifying — apply No Fomo notify policy then push to all registered tokens.
 *
 * Tier 1        → always notify
 * Tier 2        → notify if catalyst_score >= 8 OR all four scores >= 7
 * Tier 3 / else → no-op (silent watchlist add is the radar route's concern)
 *
 * No-ops cleanly when APNs env vars are unset.
 */
export async function notifyIfQualifying(row: {
  ticker: string
  tier: number
  data_snapshot: any
}): Promise<void> {
  // 1. Policy gate
  if (!meetsNotifyPolicy(row)) return

  // 2. Config gate
  const config = loadConfig()
  if (!config) return  // already logged

  // 3. Build JWT (cached)
  const jwt = buildJwt(config.privateKeyPem, config.keyId, config.teamId)

  // 4. Fetch device tokens from Supabase
  let tokens: { apns_token: string }[] = []
  try {
    const supabase = getSupabaseAdmin()
    const { data, error } = await supabase
      .from('push_tokens')
      .select('apns_token')
    if (error) {
      console.error('[push] Failed to fetch push_tokens:', error.message)
      return
    }
    tokens = data ?? []
  } catch (e) {
    console.error('[push] Supabase error fetching push_tokens:', e instanceof Error ? e.message : e)
    return
  }

  if (tokens.length === 0) {
    console.log(`[push] ${row.ticker} qualifies (tier ${row.tier}) but no registered tokens`)
    return
  }

  // 5. Build APNs payload
  const tierLabel = row.tier === 1 ? 'Tier 1 — Exceptional Asymmetry' : 'Tier 2 — High Conviction'
  const catalystScore: number = row.data_snapshot?.catalyst_score ?? 0
  const bluf: string = row.data_snapshot?.bluf ?? row.data_snapshot?.thesis ?? ''
  const body = bluf
    ? bluf.slice(0, 160)
    : `Catalyst strength ${catalystScore}/10 — open the app for the full dossier.`

  const payload = {
    aps: {
      alert: {
        title: `$${row.ticker} flagged — ${tierLabel}`,
        body,
      },
      sound: 'default',
    },
    ticker: row.ticker,  // iOS deep-link reads this key on tap
  }

  // 6. Fan out, handle per-token failures without aborting
  const results = await Promise.allSettled(
    tokens.map(t => sendOnePush(t.apns_token, payload, jwt, config.bundleId))
  )

  const sent = results.filter(r => r.status === 'fulfilled' && r.value === true).length
  const failed = results.length - sent
  console.log(`[push] ${row.ticker} tier=${row.tier} — sent ${sent}/${tokens.length}, failed ${failed}`)
}

/**
 * sendTestPush — fire a single test push to a specific device token.
 * Useful for end-to-end verification before real data flows through.
 * No-ops cleanly when APNs env vars are unset.
 */
export async function sendTestPush(token: string, ticker: string): Promise<void> {
  const config = loadConfig()
  if (!config) return

  const jwt = buildJwt(config.privateKeyPem, config.keyId, config.teamId)
  const payload = {
    aps: {
      alert: {
        title: `[TEST] $${ticker} — No Fomo push verification`,
        body: 'If you see this, APNs is wired up correctly.',
      },
      sound: 'default',
    },
    ticker,
  }

  const ok = await sendOnePush(token, payload, jwt, config.bundleId)
  console.log(`[push] test push to ${token.slice(0, 8)}… → ${ok ? 'delivered' : 'failed'}`)
}
