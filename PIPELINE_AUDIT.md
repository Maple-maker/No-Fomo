# Pipeline Audit — NoFomo Discovery Pipeline

**Audit date:** 2026-06-10
**Branch:** `feat/session-1-discovery-and-ui`

---

## 1. Backend Scraper Inventory

All scrapers live in `NoFomo/NoFomo/backend/`.

### 1a. Working

| File | Source | API Key? | Notes |
|------|--------|----------|-------|
| `sec_scanner.py` | `data.sec.gov/submissions` | None | SEC 8-K/10-Q catalyst scanner. Rate-limited to 8 req/s. Flags M&A, government contracts, FDA, financing, partnerships. Scans a hardcoded DEFAULT_TICKERS list of 36 tickers. |
| `insider_scraper.py` | `data.sec.gov/submissions` + SEC HTML | None | Form 4 insider trading scraper. Parses BeautifulSoup HTML. Detects cluster buying (3+ buys in 30d). Parses officer/director roles. Requires `beautifulsoup4` pip package. |

### 1b. Potentially Broken (yfinance dependency)

These use `yfinance`, which returns 401/429 from dev IPs (per memory `[[free-data-source-reliability]]`). Yahoo may work intermittently but is NOT reliable.

| File | Issue | Severity |
|------|-------|----------|
| `stock_data.py` | Uses `yfinance` for price, RSI, MACD, fundamentals | Medium — price data is critical for screening |
| `earnings_scraper.py` | Uses `yfinance` for earnings dates/estimates | Low — earnings dates are supplementary |
| `refresh_ta.py` | Calls `stock_data.get_snapshot()` which uses `yfinance` | Medium — feeds `ta_data.json` for app consumption |

### 1c. Spec-Only (Not Built)

| File | Referenced In | Status |
|------|---------------|--------|
| `gov_contracts_scraper.py` | SESSION_1_TASK_SPEC line 67 | Not found anywhere in repo. The server has `samGovSearch` TypeScript tool in `server/src/tools/sam.ts` for SAM.gov search, but there's no standalone Python scraper. |
| `coverage_screener.py` | SESSION_1_TASK_SPEC line 67 | Not found. Possibly spec-only in `.opencode/skills/alpha-scrapers/SKILL.md`. No TypeScript equivalent found. |

---

## 2. Server Discovery Pipeline (TypeScript)

The server has its OWN discovery pipeline using TypeScript, NOT the Python backend scripts. This is the path that runs on cron.

### 2a. Cron entry point: `GET/POST /radar/cron`

**File:** `NoFomo/server/src/routes/cron.ts`

```
GET /radar/cron?secret=... (Vercel scheduled)
    │
    ├─ Stage 1: POST /radar/discover  → returns topPicks
    ├─ Stage 2: POST /radar (for each topPick, up to MAX_RADARS_PER_RUN=3)
    └─ Stage 3: POST /radar/sweep → prune stale rows
```

- `vercel.json` cron: `0 15 * * *` (15:00 UTC daily) hits `GET /radar/cron?secret=...`
- `runRadars` defaults to `true` — both GET and POST run radars by default

### 2b. Discovery: `POST /radar/discover`

**File:** `NoFomo/server/src/routes/discover.ts`

Three stages run concurrently:

1. **SEC filings scan** (`scanSECFilings`) — watches DISCOVERY_WATCHLIST (46 tickers) for 8-K/S-1/424B filings → `server/src/tools/secFilings.ts`
2. **Insider clusters** (`getInsiderData`) — watches INSIDER_WATCHLIST (19 tickers) for cluster score ≥ 4 → `server/src/tools/insider.ts`
3. **Open-universe scout** (`scoutCatalystFilings`) — searches SEC EDGAR full-text index for NEW tickers NOT on any watchlist → `server/src/lib/edgarScout.ts`

Then screens all candidates with technical/volume filters, ranks them (scouted new > SEC filings > insider > screen score), and returns top 10.

**Key insight:** The open-universe scout (`edgarScout.ts:17-23`) searches the SEC EDGAR full-text index for 5 catalyst phrases:
- "awarded a contract" → government contract
- "received FDA approval" → FDA/regulatory
- "definitive merger agreement" → M&A
- "strategic partnership" → partnership/contract
- "record quarterly revenue" → revenue inflection

This IS the auto-discovery mechanism. It surfaces genuinely new tickers.

### 2c. Full radar: `POST /radar`

**File:** `NoFomo/server/src/routes/radar.ts`

- Takes a ticker, runs tool-assisted DeepSeek research (web search, price, SAM.gov, Quiver)
- Synthesizes dossier, runs AI council (Gemini + DeepSeek → CIO arbiter)
- Computes signal scores, asymmetry decay, enriches with fundamentals/insider/analyst data
- Persists to `radar_opportunities` unless `skip_persist=true` or window is CLOSED

### 2d. Existing council: `POST /council`

**File:** `NoFomo/server/src/routes/council.ts`

- Takes a dossier text → runs Gemini + DeepSeek independently → CIO (Claude) arbitrates
- Returns `{gemini, deepseek, cio}` verdicts with tier/score/tripleSignal
- Note: This is the FULL council (Gemini + DeepSeek + Claude CIO), NOT the budget council

---

## 3. Does any code path auto-generate candidates?

**Yes.** The server-side TypeScript pipeline auto-generates candidates:

1. `POST /radar/discover` → runs SEC full-text search for NEW tickers (open-universe scout) + scans watchlists for filings/insider activity
2. `GET /radar/cron` → wired to daily Vercel cron at 15:00 UTC

**However,** the Python backend scrapers (`sec_scanner.py`, `insider_scraper.py`) are NOT wired into the pipeline. They are standalone CLI tools. The server uses its own TypeScript implementations instead.

**What the pipeline currently discovers:**
- New tickers from SEC EDGAR full-text search (5 catalyst phrase queries)
- Filing-flagged tickers from a 46-ticker watchlist
- Insider-cluster tickers from a 19-ticker watchlist

**What's missing for true open-universe discovery:**
- Government contract scanning (SAM.gov is available as a tool in /radar but not as a candidate source in /discover)
- Underfollowed screen (no coverage screener built)
- Earnings surprise/revision momentum as a candidate source

---

## 4. Decision: Python vs. TypeScript for A3 discover.py

The spec asks to build `backend/discover.py` in Python. However, the pipeline already works in TypeScript (server routes). Decision:

**Build `backend/discover.py` as a standalone Python script** that calls the existing Python scrapers + adds the missing SAM.gov contract scout. Wire it as a local alternative. The Vercel cron continues to use the TypeScript pipeline (since Vercel can't run Python). For local/immediate use, `python3 backend/discover.py` gives Jaiden a one-command discovery run without needing the server.

The server's `/radar/discover` route can later import the Python logic or the Python script can POST to the server — the spec leaves this decision to be documented, so documenting both paths here.

---

## 5. A0 Confirmation

- ✅ One project ID: `jmtkygwvmrolfvwueggs` across all live code
- ✅ One table: `radar_opportunities` across all live code
- ✅ `opportunity_feed` table exists in Supabase but is empty — no migration needed
- ✅ Zero references to old project ID or old table name in code

---

## 6. A2 Dry-Run Results

### sec_scanner.py ✅ Working
Scanned 31 tickers over 7 days, found 16 catalyst filings:
- MSTR (3x 8-K), LUNR (2x 8-K), CRVO (2x 8-K), PLTR, SMCI, RDW, OKLO, ABCL, ALB, RKLB, AVGO, HOOD (1x each)
- All classified as "corporate event" — keyword matching works but could be more specific
- SEC API responds reliably, rate limiting enforced

### insider_scraper.py ⚠️ Working, parsing needs tuning
- Found Form 4 transactions for PLTR (3 txns) and KTOS (3 txns)
- Cluster signal shows "none" because transactions are awards (A) and dispositions (D), not open-market purchases (P)
- Price parsing produces anomalies: $7,335/share for PLTR and $2,100/share for KTOS — likely misreading HTML (stock splits/adjustments)
- Cluster detection works correctly for "P" (purchase) codes only

### stock_data.py ✅ Working (yfinance responding today)
- PLTR: $131.99, RSI 42.2 (neutral), MACD bearish, 27 analysts, $316.4B market cap
- All TA indicators compute correctly: RSI, MACD, Bollinger Bands

### earnings_scraper.py ✅ Working (yfinance responding today)
- PLTR: next earnings TBD, last 3 quarters show positive surprises (+18.1%, +8.6%)
- KTOS: next earnings TBD, last 3 quarters show positive surprises (+19.3%, +22.1%)

### refresh_ta.py ✅ Working
- Full TA + 90-day price history for PLTR
- Outputs valid JSON to stdout (--pretty flag) or ta_data.json

### POST /radar ✅ Working (server localhost:3001)
- KTOS: Tier 2, Score 72, window "closing" (asymmetry 62/100)
- 13 tool calls, 8908-char dossier with competitive advantages, risks, bull/bear cases
- Council: Gemini BULL, DeepSeek BEAR, CIO BULL

### gov_contracts_scraper.py ❌ Not built (spec-only)
### coverage_screener.py ❌ Not built (spec-only)

---

## 7. B0 iOS Layer Audit — Roadmap vs Reality

**Audit date:** 2026-06-10. The June 9 roadmap says the detail sheet "doesn't exist" and the app has no loading/error/empty states. The opencode agent already built most of this.

### What EXISTS (already built):

| Feature | File | Status |
|---------|------|--------|
| **DetailSheet** | `Views/Detail/DetailSheet.swift` (1586 lines) | ✅ Comprehensive |
| **Feed→Detail navigation** | `FeedView.swift:121` | ✅ `.sheet(item: $detailOpp)` |
| **Loading state** | `FeedView.swift:52-61` | ✅ ProgressView spinner |
| **Error banner** | `FeedView.swift:64-89` | ✅ Shows error with dismiss |
| **Pull-to-refresh** | `FeedView.swift:114` | ✅ `.refreshable` modifier |
| **Filter chips** | `FeedView.swift:44-49` | ✅ All / Tier 1 / Tier 2 / Triple Signal / Radar |
| **Manual ticker scanner** | `FeedView.swift:136-183` | ✅ Text field + Scan button |

### What's MISSING (needs work):

| Gap | Priority | Effort |
|-----|----------|--------|
| **Empty state** — no "No opportunities found" view | High | Small |
| **Error Retry button** — error banner has dismiss but no Retry | Medium | Tiny |
| **Skeleton loading** — ProgressView spinner is functional but skeleton rows would be more polished | Low | Small |

---

## 8. A3 discover.py Results

**First run** (`--skip-budget --force --no-server`): 10 candidates → 8 persisted, 2 window-closed

| Ticker | Tier | Score | Persisted | Status |
|--------|------|-------|-----------|--------|
| PLTR | 2 | 68 | ✅ | Existing, updated |
| MSTR | 2 | 65 | ✅ | Existing, updated |
| RKLB | 2 | 72 | ✅ | Existing, updated |
| ASTS | 2 | 65 | ✅ | Existing, updated |
| OKLO | 2 | 68 | ✅ | Existing, updated |
| NVDA | 1 | 85 | ❌ | Window closed (mega-cap consensus) |
| **MRVL** | **1** | **78** | ✅ | **NEW** — Tier 1, AI silicon thesis |
| **SMCI** | **2** | **65** | ✅ | **NEW** — AI infra, governance risk |
| AMD | 1 | 78 | ❌ | Window closed (well-covered) |
| **CRVO** | **3** | **45** | ✅ | **NEW** — Biotech binary catalyst |

**Second run** (idempotent, with freshness + budget council): 17 tickers detected as fresh → 15 skipped → 6 remaining candidates all killed by budget council (scores 45-55). **0 duplicate rows.**

**Acceptance criteria met:**
- ✅ One command runs end-to-end with zero manual ticker input
- ✅ 8 tickers landed in `radar_opportunities` with tier, score, thesis populated
- ✅ 3 NEW tickers (MRVL, SMCI, CRVO) not from the original 14
- ✅ Second run is a no-op (17 fresh → 0 persisted)
- ✅ Budget council gates the funnel (killed 6 weak candidates in second run)
- ⚠️ Only 3 new tickers (spec asks for ≥5). Root cause: server discovery endpoint times out (~60s screening for 50+ candidates). Open-universe scout (SEC full-text search) is functional but slow. SAM.gov contract scanning not wired as candidate source yet.

