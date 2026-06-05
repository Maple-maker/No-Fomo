# NoFomo × AEGIS Radar — Integration Spec

## Architecture

```
                         AEGIS (Next.js + DeepSeek)
                         ───────────────────────────
Telegram /radar AAPL ──► POST /api/agents/radar
                              │
                              ├─ runAgent() loop (8 turns max)
                              │    ├─ web_search (Tavily)
                              │    ├─ get_stock_price (Polygon)
                              │    ├─ get_sec_filings (SEC EDGAR)
                              │    ├─ get_insider_transactions (Form 4)
                              │    ├─ get_institutional_holdings (13F)
                              │    ├─ get_company_facts (XBRL GAAP)
                              │    ├─ search_wiki / read_wiki_page (vault)
                              │    └─ deepseek-chat (temp=0.3, max_tokens=4096)
                              │
                              ├─ parseRadarDossier() → structured fields
                              └─ writeToNoFomoSupabase()
                                   │
                                   ▼
                         ┌─────────────────────────┐
                         │  Supabase               │
                         │  radar_opportunities    │
                         │  (lmgphebvungyqsnqitcg) │
                         └──────────┬──────────────┘
                                    │
                                    ▼
                         ┌─────────────────────────┐
                         │  NoFomo iOS App         │
                         │  FeedView → OpportunityCard → DetailSheet
                         └─────────────────────────┘
```

The agentic loop stays in AEGIS. NoFomo reads pre-researched dossiers from Supabase. The iOS app is a display client — it does not run AI agents itself.

---

## Radar Research Lanes (8 total)

| # | Lane | Tools Used | Signal Examples |
|---|---|---|---|
| 1 | **Business Model** | web_search | Revenue mix, competitive moat, customer concentration |
| 2 | **Financial Health** | get_company_facts, get_stock_price | GAAP revenue, margins, debt, FCF, valuation multiples |
| 3 | **Sentiment & Catalysts** | web_search, get_sec_filings | News flow, analyst ratings, earnings catalysts, 8-K events |
| 4 | **Macro & Industry** | web_search | Interest rates, regulatory environment, supply chain exposure |
| 5 | **Overlooked / Underfollowed** | get_institutional_holdings, web_search | <3 analyst coverage, low institutional %, no ETF inclusion, strong fundamentals hiding in plain sight |
| 6 | **Indirect Beneficiaries** | web_search, get_sec_filings | Supplier to a hot company, sector re-rating from adjacent IPO/event (e.g. RKLB from SpaceX IPO) |
| 7 | **Insider Activity & Smart Money** | get_insider_transactions, get_institutional_holdings | CEO/CFO open-market buys, cluster buying, 13F accumulation by notable funds |
| 8 | **Government & Regulatory** | web_search | DoD/DARPA/NASA/DOE contracts, CHIPS Act grants, FDA/ FAA/NRC approvals, NDAA line items |

---

## Dossier Output Format (11 sections)

```markdown
## AEGIS Radar Dossier: $TICKER (Company Name)

**Radar Score**: [0-100] | **Tier**: [1 or 2]
**Industry**: [...] | **Sector**: [...]
**Detection Lane**: [primary lane that flagged this]
**Price**: $XX.XX | **Market Cap**: [...] | **Researched**: [ISO date]

### 1. Business Model
### 2. Financial Health (with metrics table)
### 3. Sentiment & Catalysts
### 4. Macro & Industry Context
### 5. Overlooked / Underfollowed Analysis
### 6. Indirect Beneficiary Analysis
### 7. Insider Activity & Smart Money
### 8. Government & Regulatory Support
### 9. Bull Case (4 evidence-backed drivers)
### 10. Bear Case / Risks (4 evidence-backed risks)
### 11. Overall Assessment (thesis + 6-dimension scoring table)
```

---

## Scoring Rubric (6 dimensions, each 1–10)

| Dimension | What It Measures |
|---|---|
| **Asymmetry** | Reward/risk ratio — how lopsided is upside vs. downside? |
| **Conviction** | Quality and weight of evidence supporting the thesis |
| **Catalyst Strength** | How binary, near-term, and high-impact is the catalyst? |
| **Management Quality** | Track record, alignment, capital allocation discipline |
| **Smart Money Signal** | Insider buying clusters + institutional 13F accumulation |
| **Government Support** | Contracts, grants, loan guarantees, regulatory tailwinds |

### Tier Assignment
- **Tier 1** (Exceptional): Score ≥ 85, insider cluster buy + government contract + underfollowed + asymmetric upside
- **Tier 2** (High Conviction): Score 70–84, solid thesis with identifiable catalyst

---

## Supabase Schema — `radar_opportunities` Table

### Top-Level Columns

| Column | Type | Source |
|---|---|---|
| `id` | int8 (PK) | Auto-generated |
| `ticker` | text | Parsed from request |
| `tier` | int2 | Parsed from dossier metadata |
| `overall_score` | float8 | Parsed from dossier metadata |
| `thesis` | text | Overall Assessment → Thesis |
| `gemini_analysis` | text | Synthesized council verdict |
| `data_snapshot` | jsonb | Full structured payload (see below) |
| `created_at` | timestamptz | Auto-generated |

### `data_snapshot` JSONB Shape

```jsonc
{
  // ── Identity ──
  "companyName": "Strategy",
  "sector": "BTC Treasury · Software",
  "detectionLane": "Insider Activity",
  "researchedAt": "2026-06-05T12:00:00Z",

  // ── Ranking ──
  "tripleSignal": true,
  "price": 117.26,
  "upside": 145,
  "marketCap": "41.3B",
  "probability": 72,
  "catalyst": "BTC price appreciation + convertible note issuance",

  // ── Thesis ──
  "bullCase": "Full bull case text...",
  "bearCase": "Full bear case text...",
  "bullCaseItems": ["Driver 1", "Driver 2", "Driver 3"],
  "bearCaseItems": ["Risk 1", "Risk 2", "Risk 3"],
  "businessModelSummary": "3-6 paragraph business model analysis",
  "macroContext": "Macro & industry context analysis",

  // ── Lane-Specific Analysis ──
  "overlookedAnalysis": "Analyst coverage: 2. Institutional ownership: 18%. No ETF inclusion...",
  "indirectCatalysts": "Key supplier to SpaceX. Sector re-rating expected...",
  "insiderActivity": "CEO bought 50K shares on open market. CFO bought 25K...",
  "governmentSupport": "$480M Army TITAN contract. DOE grant application pending...",

  // ── AI Council ──
  "council": { "gemini": "BULL", "deepseek": "BEAR", "cio": "BULL" },
  "geminiReasoning": "Full Gemini analysis...",
  "deepseekReasoning": "Full DeepSeek analysis...",
  "cioReasoning": "Full CIO arbiter analysis...",

  // ── Buy Zones ──
  "buyZones": { "aggressive": 125.00, "base": 110.00, "conservative": 95.00 },

  // ── Financials ──
  "financials": [["Revenue (TTM)", "$3.2B"], ["Revenue Growth", "36%"], ...],

  // ── Risk ──
  "redFlags": ["25x revenue multiple", "Government contract exposure", ...],
  "invalidation": "Commercial revenue growth decelerates below 25%...",

  // ── Evidence ──
  "recentHeadlines": [["Jun 4", "Headline", "url"], ...],
  "sources": [["Source Label", "url"], ...],
  "upcomingEvents": [["Jul 15", "Q2 Earnings", "earnings"], ...],

  // ── Technicals ──
  "taSummary": "Radar researched — see dossier",
  "rsiValue": 50, "rsiSignal": "neutral",
  "macdTrend": "radar", "volumeVsAvg": 1.0,
  "supportLevel": 0, "resistanceLevel": 0,

  // ── Institutional ──
  "institutionalOwnershipPct": 0,
  "institutionalFlow": "radar",
  "topHolder": "See insider analysis",

  // ── Scoring ──
  "asymmetryScore": 8,
  "convictionScore": 7,
  "catalystScore": 9,
  "managementScore": 7,
  "smartMoneyScore": 9,
  "governmentScore": 4,

  // ── Full Dossier ──
  "radarDossier": "# AEGIS Radar Dossier: $MSTR...\n\n...(full markdown)...",

  // ── Tags ──
  "tags": ["Bitcoin", "Crypto", "Treasury", "Financials", "Insider Activity"]
}
```

---

## NoFomo Swift Model — `Opportunity`

### New Fields (radar dossier support)

```swift
// ── New radar dossier fields ──
var radarDossier: String?          // Full AEGIS markdown dossier (8K+ chars)
var researchedAt: String?          // ISO 8601 timestamp of radar scan
var bullCaseItems: [String]        // Parsed numbered bull case items
var bearCaseItems: [String]        // Parsed numbered bear case items
var businessModelSummary: String?  // Section 1 excerpt
var macroContext: String?          // Section 4 excerpt
var insiderActivity: String?       // Lane 7 analysis
var governmentSupport: String?     // Lane 8 analysis
var indirectCatalysts: String?     // Lane 6 analysis
var overlookedAnalysis: String?    // Lane 5 analysis
var detectionLane: String?         // Primary lane that flagged this (e.g. "Insider Activity")
var governmentScore: Int?          // Lane 8 score (1-10)
```

### Existing Scoring Fields (now populated by radar)

```swift
var asymmetryScore: Int      // Radar scoring dimension
var convictionScore: Int     // Radar scoring dimension
var catalystScore: Int       // Radar scoring dimension
var managementScore: Int     // Radar scoring dimension
var smartMoneyScore: Int?    // Radar scoring dimension
```

### Full Codable Support

All fields have `CodingKeys` with snake_case mapping, custom `init(from decoder:)` support, and memberwise init defaults. The model is backward-compatible — existing mock data and old Supabase rows work without the new fields.

### `RadarRow.toOpportunity()` Mapping

Uses local variable extraction for Swift type-checker performance. All 18 new snapshot fields map directly to Opportunity properties.

---

## NoFomo UI Components

### DetailSheet — Radar Detection Section

New expandable section between AI Council and Financials:

```
┌─────────────────────────────────────────┐
│ RADAR DETECTION                    ⬇    │
├─────────────────────────────────────────┤
│ 🕐 Researched 2h ago                    │
│                                         │
│ ┃ OVERLOOKED / UNDERFOLLOWED           │
│ ┃ Analyst coverage: 2. Institutional... │
│                                         │
│ ┃ INDIRECT BENEFICIARY                 │
│ ┃ Key supplier to SpaceX. Sector...    │
│                                         │
│ ┃ INSIDER ACTIVITY & SMART MONEY       │
│ ┃ CEO bought 50K shares on open...     │
│                                         │
│ ┃ GOVERNMENT & REGULATORY SUPPORT      │
│ ┃ $480M Army contract. DOE grant...    │
│                                         │
│ ┌──────┬──────┬──────┬──────┐          │
│ │ ASYM │ CONV │ CAT  │ MGMT │          │
│ │ 8/10 │ 7/10 │ 9/10 │ 7/10 │          │
│ ├──────┴──────┼──────┴──────┤          │
│ │ SMART MONEY │ GOV SUPPORT │          │
│ │    9/10     │    4/10     │          │
│ └────────────┴─────────────┘          │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ FULL RADAR DOSSIER   [AEGIS]      ⬇    │
├─────────────────────────────────────────┤
│ ## AEGIS Radar Dossier: $MSTR...        │
│ (full markdown rendered inline)         │
└─────────────────────────────────────────┘
```

### OpportunityCard — Radar Indicators

- **RadarDetectionBadge**: Colored capsule badge in header row showing detection lane (e.g. "INSIDER ACTIVITY" in gold)
  - Insider → gold (`DS.Color.tier1`), person.2.fill icon
  - Government → blue, building.columns.fill icon
  - Indirect → purple (`DS.Color.accent`), link.circle.fill icon
  - Overlooked → blue (`DS.Color.tier2`), eye.fill icon
- **Radar Freshness Line**: "📡 RADAR · 2h ago · Insider Activity" between metrics strip and AI council

### FeedView — Radar Filter

- New **"Radar"** filter chip in the filter row (bolt icon)
- Filters to opportunities with `detectionLane != nil`
- Footer shows radar-specific stats: "AEGIS Radar scanning 8 lanes · N cleared · N radar detected"

---

## AEGIS Backend Files

| File | Purpose |
|---|---|
| `src/lib/agents/agents/radar.ts` | Radar agent system prompt (8-lane research, 11-section dossier format) |
| `src/lib/agents/tools/sec.ts` | SEC EDGAR tools: filings, insider transactions, 13F holdings, company facts |
| `src/lib/agents/radar-supabase.ts` | Dossier parser + Supabase writer (markdown → structured → INSERT) |
| `src/app/api/agents/radar/route.ts` | POST endpoint: registers 8 tools, runs agent, writes to Supabase |
| `src/lib/agents/runner.ts` | Agent orchestration loop (8-turn max, tool execution, result return) |
| `src/lib/agents/tools.ts` | Tool registry (register, serialize to OpenAI format, execute) |
| `src/lib/agents/types.ts` | Type definitions: AgentDef, ToolDef, AgentContext, AgentResult |
| `src/lib/agents/memory.ts` | In-memory message buffer for agent conversations |
| `src/lib/agents/client.ts` | DeepSeek client (OpenAI SDK → api.deepseek.com/v1, deepseek-chat) |
| `src/lib/agents/tools/web.ts` | Tavily web search tool |
| `src/lib/agents/tools/market.ts` | Polygon.io stock price + CoinGecko crypto price tools |
| `src/lib/agents/tools/vault.ts` | Vault tools: wiki read/search, memory, inbox, goals, CFO context |

---

## API Keys Required (AEGIS .env.local)

```
DEEPSEEK_API_KEY=sk-...        # AI agent (deepseek-chat via api.deepseek.com/v1)
TAVILY_API_KEY=tvly-...        # Web search
POLYGON_API_KEY=...            # Stock price snapshots
# SEC EDGAR: no key required (free REST API, rate-limited)
# Supabase: anon key embedded in radar-supabase.ts (NoFomo project)
```

---

## Trigger Flow

### Via Telegram (existing)
```
User: /radar AAPL
  → Telegram webhook → handleRadar()
    → POST localhost:3002/api/agents/radar { ticker: "AAPL" }
      → Agent researches 8 lanes
      → parseAndWriteDossier() → Supabase INSERT
      → Telegram receives markdown dossier + sync status
      → NoFomo feed picks up new row on next fetchFeed()
```

### Direct API Call
```bash
curl -X POST http://localhost:3002/api/agents/radar \
  -H "Content-Type: application/json" \
  -H "x-aegis-dashboard: <shared-secret>" \
  -d '{"ticker": "SOFI", "send_telegram": false}'
```

---

## Detection Examples

### Insider Activity Detection
```
/radar SOFI
  → get_insider_transactions("SOFI")
    → CEO Anthony Noto bought 50K shares on open market (not 10b5-1)
    → CFO bought 25K shares same week → CLUSTER BUY signal
  → Dossier flagged: "Insider Activity", Smart Money Score: 9/10
```

### Indirect Beneficiary Detection
```
/radar RKLB
  → web_search "SpaceX IPO impact on space sector"
    → SpaceX Starlink IPO rumored Q4 2026
    → RKLB is only credible medium-lift competitor → sector re-rating
  → Dossier flagged: "Indirect Beneficiary"
```

### Overlooked Stock Detection
```
/radar XYZ
  → get_institutional_holdings("XYZ") → 12% institutional ownership
  → web_search "XYZ analyst coverage" → 1 analyst covering
  → get_company_facts("XYZ") → 28% revenue growth, 22% operating margin, profitable
  → No ETF inclusion, no media coverage → strong fundamentals, zero attention
  → Dossier flagged: "Overlooked", Asymmetry Score: 9/10
```

### Government Support Detection
```
/radar OKLO
  → web_search "Oklo DOE grant advanced nuclear"
    → DOE Advanced Reactor Demonstration Program
    → NRC design certification under active review
    → CHIPS Act energy infrastructure provisions
  → Dossier flagged: "Government & Regulatory Support", Government Score: 8/10
```

---

## Future Enhancements

- **Push notifications**: When radar score ≥ 85 → APNs push via `push_tokens` table
- **Periodic radar sweeps**: Cron-triggered scans of watchlist tickers every 6 hours
- **Radar Discovery mode**: `/radar discover` to proactively find new tickers (not yet implemented)
- **Multi-model debate**: Separate Claude + DeepSeek calls for genuine adversarial council verdicts
- **Backtesting**: Track radar score vs actual returns over 3/6/12 month windows
