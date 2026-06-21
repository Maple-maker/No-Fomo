# No Fomo — iOS Beta-Readiness (session 2026-06-18)

**Scope chosen by Jaiden:** iOS beta-readiness only. NO web app. The "build out plan/"
phase files target an empty `opportunity_feed` table + a non-existent web product — they are
stale and out of scope. Real product = iOS app + `NoFomo/server` (live Vercel cron) + Supabase
`radar_opportunities`/`radar_feed_public`.

**Locked lesson (from detail-sheet-backlog):** fix the server data write BEFORE the UI, or we
ship prettier blanks. Verified against live rows below.

## Ground truth (radar_opportunities, 2026-06-18)
- `gemini_reasoning` / `deepseek_reasoning` / `cio_reasoning`: ABSENT on every row.
- `sources`: ABSENT (n=0) on every row.
- `peer_comparison`: PRESENT on some (KTOS=4, ASTS=4); absent on others — render when present.
- `key_metrics`: 7 fields decode fine (LLM-approximate); missing P/S, P/FCF, rev growth, short %.
- `support_level`/`resistance_level`: populated → chart overlays have data.

## Data contract (locked — both tracks code to this)
data_snapshot gains:
- `gemini_reasoning`, `deepseek_reasoning`, `cio_reasoning`  (String) ← council result
- `sources`  ([[label, url]])  ← allSources (moved above persist)
- key_metrics gains `ps_ttm`, `pfcf`, `rev_growth_yoy`, `short_pct`  (String) ← real stockData

## Track A — SERVER (me) · NoFomo/server/**
- [ ] opportunity.ts: add 3 reasoning fields + `sources` + 4 key_metrics fields to RadarRow type + data_snapshot write. Reasoning comes from bull.reasoning/bear.reasoning/neutral.synthesis (already passed to buildRadarRow).
- [ ] radar.ts: move `allSources` build ABOVE persist; pass `sources` + key-metrics (from stockDataForValuation) into enrichment.
- [ ] `npm run build` (tsc) green.

## Track B — iOS (agent) · NoFomo/Views, NoFomo/Models
- [ ] #5 wire orphaned `councilSection` into body; retire `councilSummarySection`.
- [ ] #4 Competitive Landscape → render `peerComparison` table; drop `edgeFromBull` fallback.
- [ ] #1 Key Metrics: +4 fields in KeyMetricsData + render; hide empty rows.
- [ ] Evidence: `sourcesSection` renders tappable `sources`.
- [ ] #3 Chart overlays: support/resistance lines + RSI/MACD signal markers.
- [ ] `xcodebuild` green.

## Verify
- [ ] Live re-scan one ticker (KTOS) → confirm data_snapshot has reasoning + sources.
- [ ] xcodebuild green; review diffs; commit + push (frequent — parallel opencode agent deletes untracked files).

## Review (2026-06-18) — DONE, committed a963165 (local, not pushed)
Both tracks landed + verified. `tsc --noEmit` clean; `buildRadarRow` unit test asserts all
9 new fields populate (no regression); `xcodebuild -scheme NoFomo` BUILD SUCCEEDED.

- Server: reasoning (gemini/deepseek/cio) + `sources` + 4 real key-metrics now persist to data_snapshot.
- iOS: council panels render reasoning · peer table replaces edgeFromBull · 4 key-metrics (hidden when empty) ·
  tappable sources wired into body · chart S/R lines + RSI/MACD badges.
- Caught + fixed in review: agent rendered peer gross-margin/rev-growth with `*100` (×100 too big) —
  getStockData stores them as percent numbers already (28.3, not 0.283). Fixed.
- Stale-backlog correction: `councilSection` was ALREADY wired in the body (a prior commit fixed the
  orphan); the real unlock was the SERVER persisting reasoning (now done). Removed dead councilSummarySection.

### Discovered data gaps (not code bugs — flagged for follow-up)
- `peer_comparison` metric VALUES are null on existing rows (e.g. KTOS): peers.ts emits the right tickers
  but getStockData returned nulls at scan time (Yahoo). iOS renders "—". Fresh scans + Yahoo cooperation populate.
- `smart_money_signal`/`government_signal` empty on every row (radar.ts filter yields nothing). Minor.

### Not yet verified end-to-end (offered, not run)
- A live re-scan would confirm real data populates at runtime, but it mutates the PRODUCTION feed
  (delete+reinsert; a closed window would PRUNE the row) and spends API — so left for Jaiden / the next cron.

## Gated / flagged (NOT doing autonomously)
- #2 Analyst Consensus — needs Jaiden's spec (range bar vs richer display).
- RLS lock (`supabase_rls_lock.sql`) — apply only AFTER Jaiden ⌘R-confirms rebuilt app reads `radar_feed_public` (else breaks live anon app).
- Data health: yfinance chart 404s (LAZR, RDFN, FABG); feed stale since Jun 14, opportunities_found=0.
- Push-notify server trigger + `push_tokens` anon-writable security hole.
