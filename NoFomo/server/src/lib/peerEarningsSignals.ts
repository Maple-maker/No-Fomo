// ── Competitor Earnings Beats / Misses ──
// Peer miss = sector headwind; peer beat = tailwind. Cohort beating but this name lagging
// (or vice-versa) is a relative-strength setup.
// Source: Yahoo earningsHistory per peer; peers from PEER_GROUPS in peers.ts.

import { getPeers } from './peers'

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
const YF_QUERY = 'https://query2.finance.yahoo.com/v10/finance/quoteSummary'

export interface PeerEarningsSignal {
  peerBeatsCount: number
  peerMissesCount: number
  sectorMomentum: number
  peersAnalyzed: number
  signal: string
}

async function fetchPeerEarnings(peer: string): Promise<{ beats: number; misses: number }> {
  try {
    const res = await fetch(`${YF_QUERY}/${peer}?modules=earningsHistory`, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' }, signal: AbortSignal.timeout(8000) })
    if (!res.ok) return { beats: 0, misses: 0 }
    const data = (await res.json()) as any
    const history = data?.quoteSummary?.result?.[0]?.earningsHistory?.history ?? []
    let beats = 0, misses = 0
    for (const q of history) {
      const actual = q?.epsActual?.raw, estimate = q?.epsEstimate?.raw
      if (actual == null || estimate == null) continue
      if (actual >= estimate) beats++; else misses++
    }
    return { beats, misses }
  } catch { return { beats: 0, misses: 0 } }
}

export async function trackPeerEarnings(ticker: string): Promise<PeerEarningsSignal | null> {
  const peers = getPeers(ticker).slice(0, 3)
  if (peers.length === 0) return null
  const results = await Promise.all(peers.map(p => fetchPeerEarnings(p)))
  const peerBeatsCount = results.reduce((s, r) => s + r.beats, 0)
  const peerMissesCount = results.reduce((s, r) => s + r.misses, 0)
  const total = peerBeatsCount + peerMissesCount
  if (total === 0) return null
  const sectorMomentum = Math.round((peerBeatsCount / total) * 100) / 100
  let signal: string
  if (sectorMomentum >= 0.75) signal = `📈 Sector tailwind: peers beating (${peerBeatsCount}/${total} quarters)`
  else if (sectorMomentum <= 0.4) signal = `Sector headwind: peers missing (${peerMissesCount}/${total} quarters) — contrarian if this name beats`
  else signal = `Mixed peer earnings (${peerBeatsCount} beats / ${peerMissesCount} misses)`
  return { peerBeatsCount, peerMissesCount, sectorMomentum, peersAnalyzed: peers.length, signal }
}
