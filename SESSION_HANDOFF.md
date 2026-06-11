# NoFomo — Session Handoff

**Date:** 2026-06-09 · **Author:** Claude (Opus) session · **For:** continuing model + review helper AI

---

## 0. TL;DR — read this first

1. **The user's recurring complaint ("I keep seeing the same 8 companies") has a ROOT CAUSE that is now identified and ONE fix away:**
   The iOS app reads the **wrong Supabase project**. opencode's rewrite hardcoded the app to project **`lmgphebvungyqsnqitcg`** (empty), but all data — the original 8 *and* the 13 I just added — lives in project **`jmtkygwvmrolfvwueggs`** (the user's real `.env` project, which the server writes to).
   👉 **IMMEDIATE FIX:** update `NoFomo/Services/SupabaseService.swift` lines ~5–6 (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) to the `jmtkygwvmrolfvwueggs` project. The correct URL + anon key are in `/Users/jaidenrabatin/NoFomo/.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). Then rebuild → the feed shows 13 companies. **This was in progress when the session was stopped — it is NOT yet applied.**

2. **The feed data is fixed at the source:** the `radar_opportunities` table in `jmtkygwvmrolfvwueggs` now has **13 companies** (was 8). New: SMR, ALAB, SOUN, RDW, LUNR. (GEV was correctly auto-pruned as a "closed" large-cap — the decay engine working as designed.)

3. **The server is fully repaired and builds clean** (`tsc` exit 0); the iOS app **now compiles and runs** on the iPhone 17 sim after this session's fixes — it just points at the wrong DB (#1 above).

---

## 1. CRITICAL CONTEXT — parallel tool + nested repo

- The user runs a **parallel `opencode` agent** on this repo (see `.opencode/`, `opencode.json`, `AGENTS.md`). During this session it **restructured the whole repo** and committed as the user (`aed06a7`).
- **Repo layout is now nested:** git root is `/Users/jaidenrabatin/NoFomo`; the iOS app is at `/Users/jaidenrabatin/NoFomo/NoFomo/` and the server at `/Users/jaidenrabatin/NoFomo/NoFomo/server/`. A Next.js scaffold also exists at the root.
- **HAZARD:** opencode's restructure **deleted every untracked file** (it orphaned ~22 server modules + the iOS app's old networking). **Commit/push promptly** — do not leave new work untracked, or the next opencode run may wipe it.

---

## 2. What was accomplished this session

### Server (committed + pushed — PR #1, branch `fix/server-repair-jelly-signals`)
- **Repaired the unbuildable server:** reconstructed 22 orphaned modules (stockData, peers, secAnalysis, patents, insider [+Form 3/5], tiers, buyLevels, themes, jobPosting, shortReports, transcriptAnalysis, exa, quiver, sam) + the **Phase-2 signal expansion** (analyst revisions, short squeeze, buyback, dividend, social-via-Brave, options IV, peer earnings) + **asymmetry-decay engine**. `tsc` exit 0; server boots; all providers green.
- **Asymmetry decay** (`lib/asymmetryDecay.ts`): scores remaining asymmetry → `open|closing|closed` (mega-cap / coverage-saturation / upside-exhausted / overbought / stale). Closed names are pruned at scan-time + via `POST /radar/sweep`. **NVDA-today → CLOSED, NVDA-2019 → open** (verified).
  - ⚠️ **Bug fixed this session:** a missing/zero `analystTargetMean` was computing "-100% downside to target" and wrongly pruning *every* stock when the analyst feed was down. Guarded with `analystTargetMean > 0`. If you see legit names getting pruned, re-check this.
- **Daily discovery automation:** fixed the cron-persist gap (scheduled `GET /radar/cron` now runs radars + persists + sweeps — previously persisted nothing). Added `lib/edgarScout.ts` (open-universe scouting via SEC full-text search — surfaces NEW tickers market-wide). `vercel.json`: daily 15:00 UTC + `maxDuration`.
- **Restored dropped routes:** `GET /radar/filings`, `POST /radar/screen`, `POST /radar/supply-chain` (re-mounted in `index.ts`).
- **Kalshi (Jelly Signals foundation):** `tools/kalshi.ts` + `GET /radar/kalshi` + `kalshiSearch` ToolDef. ⚠️ Kalshi's firehose `markets` endpoint is **sports-prop-dominated/untraded** — surfacing liquid econ/Fed markets needs **series-ticker targeting** (e.g. `KXFED`) or `/events?category=`. Not yet done.
- **Security:** added `.env` / `.env.*` / `dist` / `.cache` to `.gitignore` (root `.env` was untracked-but-unignored). No secrets in the PR diff.

### Data (NOT in git — lives in Supabase `jmtkygwvmrolfvwueggs`)
- Ran live `/radar` scans → feed grew **8 → 13** companies. The server was left running on `localhost:3001` (kill with `pkill -f "node dist/index.js"` if needed).

### iOS (UNCOMMITTED working-tree changes — opencode's domain; see §5)
opencode's rewrite (new minimal `Opportunity` model + `APIService` replacing `RadarService`) left the app **not compiling**. Fixed it to build:
- `project.yml`: scoped `sources` to the Swift dirs only (was `path: NoFomo`, which slurped `server/node_modules` → resource-collision build errors).
- `Models/Opportunity.swift`: re-added (additive, optional/defaulted) the fields `DetailSheet` needs — `councilSummary`, `competitiveAdvantages`, `investmentRisks`, `keyMetrics` (+ `KeyMetricsData` struct), insider fields, and `static let mocks: [Opportunity] = []`.
- `ViewModels/FeedViewModel.swift`: added `serverOnline`; `scanTicker(_:isPremium:)` defaulted param.
- `Views/Feed/FeedView.swift`: removed the orphaned `supplyChainView` + `scanResultCard` (both referenced the deleted `RadarService`).
- Result: **BUILD SUCCEEDED**, installs + launches on iPhone 17 sim (`33CD9A4E-C4A1-4899-9742-1674D54D6A20`).

---

## 3. ⭐ NEXT STEPS (priority order)

1. **Point the app at the right Supabase project** (makes the 13 companies appear). Edit `NoFomo/Services/SupabaseService.swift` `SUPABASE_URL` + `SUPABASE_ANON_KEY` → use the values from root `.env` (`jmtkygwvmrolfvwueggs`). Rebuild + relaunch on iPhone 17 sim. **This is the single highest-value action.**
2. **Decide ownership of the iOS layer.** opencode is mid-rewrite (minimal model + `APIService` at `http://72.61.206.167:3002`). Either (a) let opencode finish its iOS migration, or (b) keep this session's additive fixes. Don't fight it — coordinate.
3. **Populate more companies / verify automation.** Run `POST http://localhost:3001/radar/cron -H "Authorization: Bearer nofomo-cron-dev" -d '{"run_radars":true}'` (discover → radar → persist → sweep). Or scan specific tickers via `POST /radar {"ticker":"X"}`.
4. **Jelly Signals (the user's larger plan):** Kalshi econ-targeting (series tickers) → CoinGecko → Binance → orchestration/scoring module → feedback loop → event calendar.
5. **Commit the iOS fixes** if keeping them (they're uncommitted). Branch first; never push to `main`.

---

## 4. Build / run

**Server:** `cd NoFomo/server && npm install && npm run build` (tsc) → `node dist/index.js` (or `npm run dev`). Needs `NoFomo/server/.env` (already copied from root `.env`; gitignored).
**iOS:** `cd /Users/jaidenrabatin/NoFomo && xcodegen generate && xcodebuild -project NoFomo.xcodeproj -scheme NoFomo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`. ⚠️ Run `xcodegen generate` after adding Swift files (the `.xcodeproj` is generated/untracked).

---

## 5. Git state

- **Branch `fix/server-repair-jelly-signals`** (pushed) → **PR #1**: https://github.com/Maple-maker/No-Fomo/pull/1 — all SERVER work (4 commits). Build green.
- **Uncommitted working-tree changes (iOS + project.yml):** `Models/Opportunity.swift`, `ViewModels/FeedViewModel.swift`, `Views/Feed/FeedView.swift`, `project.yml`, regenerated `NoFomo.xcodeproj`. The app's `SupabaseService.swift` still has the WRONG project ref (fix #1 not yet applied).
- `NoFomo/server/.env` exists (copied from root) and is **gitignored** — do not commit.

---

## 6. Gotchas / data-source reliability

- **Yahoo Finance**: rate-limits/auth-walls the dev IP (429/401). Price falls back to **Polygon** (key in `.env`); other Yahoo-derived enrichment degrades gracefully. Scans still work + persist via DeepSeek/Brave/SEC.
- **Reddit** JSON API hard-blocks cloud IPs (403) → social signal uses **Brave Search** instead.
- **Kalshi** firehose is sports-only → needs series-ticker targeting (see §2).
- **SEC EDGAR / XBRL / full-text search** + **Brave** are reliable, no extra keys.
- **Decay engine** prunes "closed" windows at scan time → consensus/mega-cap/over-valued names won't persist (by design). If nothing persists, check `analystTargetMean` guard (§2) and whether Yahoo degradation is dragging composite scores down.

---

## 7. For the REVIEW helper AI — what to verify

- **Correctness:** does `lib/asymmetryDecay.ts` prune fairly under degraded data? (Re-check the `analystTargetMean > 0` guard and the composite/contrarian "score collapse" rules firing on missing data.)
- **Security:** confirm no secrets in the PR diff; confirm `.env`/`.env.*` are gitignored; the app's anon key is a public client key (safe to embed) but the SERVICE_ROLE key must never reach the client.
- **The Supabase project mismatch (§0.1):** confirm which project is canonical (`jmtkygwvmrolfvwueggs` per root `.env`) and that app + server agree.
- **iOS additive model restore:** verify the re-added `Opportunity` fields decode correctly and don't break opencode's `APIService` mapping.
- **Reconstructed modules:** `quiver.ts`, `exa.ts`, `sam.ts`, `transcriptAnalysis.ts`, `shortReports.ts`, `jobPosting.ts`, `buyLevels.ts`, `tiers.ts`, `themes.ts`, `secFilings.ts` are **functional reconstructions from interface contracts** (the originals were unrecoverable) — verify behavior against intent, not just compilation.
