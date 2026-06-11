# NoFomo Signal Expansion — 10 High-ROI Free Data Sources

**Status:** 🎯 Phase 2 Integration (Free, No API Keys Required)
**Owner:** Hermes (via Opus)
**Goal:** Add 10 complementary signal sources to boost early inflection detection by 35-50%

---

## TIER 1: IMMEDIATE (Highest Alpha, Easiest Implementation)

### [ ] 1. Analyst Estimate Revisions Tracking

**What it does:** Detects earnings inflection 4-8 weeks before stock reprices. 3+ upward revisions in 30 days = confidence inflection.

**Setup:**
1. Data source: Seeking Alpha (free tier — no API key, web scrape)
2. Alternative: Yahoo Finance estimate history (free, no key)
3. No API key required

**Create new file:** `server/src/lib/analystRevisions.ts`
- Function: `trackAnalystRevisions(ticker: string): Promise<RevisionSignal>`
- Fetch last 90 days of estimate changes from Seeking Alpha search results
- Count: revisions up vs down, trend direction
- Return: `{ revisionMomentum: number, revisionsUp: number, revisionsDown: number, signal: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `analystRevisions?: RevisionSignal | null` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreFundamental()` → 3+ upward revisions in 30 days = +65pts
- `server/src/lib/opportunity.ts` → `RadarRow.data_snapshot` → Add `analyst_revisions_momentum`

**Why it works:** Analysts lead the stock by 4-6 weeks. Revisions cluster = consensus inflection about to happen.

---

### [ ] 2. Float + Short Squeeze Analysis

**What it does:** Identifies extreme squeeze setups. (Shares Short / Float) >25% + insider buying = 🚀 signal.

**Setup:**
1. Data source: Existing stock data (shares outstanding, insider holdings)
2. Calculate: Float = sharesOutstanding - insiderShares
3. Calculate: ShortSqueezePct = (sharesShort / float) * 100
4. No new API key required — use data from `stockData.ts`

**Create new file:** `server/src/lib/squeezeAnalysis.ts`
- Function: `analyzeShortSqueeze(ticker: string, stockData: StockDataResult, insiderPct: number): Promise<SqueezeSignal>`
- Fetch current short interest, calculate float
- Flag: >20% = caution, >30% = high risk, >50% = extreme
- Return: `{ floatPct: number, shortSqueezePct: number, daysToClose: number, signal: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `squeezeAnalysis?: SqueezeSignal | null` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreContrarian()`:
  - Short squeeze >25% + insider cluster ≥7 = +75pts (massive asymmetry)
  - Short squeeze >25% alone = +50pts
- `server/src/lib/opportunity.ts` → `data_snapshot` → Add `short_squeeze_pct`, `days_to_cover`

**Why it works:** Short squeezes are binary catalysts. Most profitable when combined with insider buying (insiders front-run it).

**Testing:**
```bash
# Check for extreme squeezes (GME-like setup)
curl http://localhost:3001/radar -X POST -d '{"tickers":["GFAI","SMCI","NVDA"]}' | jq '.opportunities[] | select(.data_snapshot.short_squeeze_pct > 30)'
```

---

### [ ] 3. Stock Buyback Tracking

**What it does:** Management capital allocation confidence. Buying at lows = smart allocation, buying at highs = wealth destruction signal.

**Setup:**
1. Data source: SEC 10-K Item 5 (Issuer Purchases), 8-K Item 2.06 (Material Definitive Agreement)
2. Parse "Issuer Repurchases" table from latest 10-K
3. No API key required

**Create new file:** `server/src/lib/buybackAnalysis.ts`
- Function: `analyzeBuybacks(ticker: string): Promise<BuybackSignal>`
- Fetch latest 10-K from SEC EDGAR (reuse CIK lookup from insider.ts)
- Parse: Buyback authorization date, total authorization, shares repurchased to date, average price paid
- Compare: buyback price vs current price
- Return: `{ buybackActive: boolean, sharesRepurchased: number, avgPrice: number, currentVsAvg: number, signal: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `buybackAnalysis?: BuybackSignal | null` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreFundamental()`:
  - Buyback active + avgPrice < currentPrice by >15% = +60pts (smart timing)
  - Buyback active = +35pts (baseline confidence)
- `server/src/lib/opportunity.ts` → `data_snapshot` → Add `buyback_active`, `buyback_avg_price`, `shares_repurchased_pct`

**Why it works:** Buybacks signal: (1) undervaluation thesis, (2) confidence in future, (3) no capex constraints. Management putting money where mouth is.

---

## TIER 2: HIGH PRIORITY (Strong Signals, Medium Implementation)

### [ ] 4. Dividend Initiation & Increase Tracking

**What it does:** First dividend ever = profitability inflection. Dividend increase on maintained payout = earnings confidence.

**Setup:**
1. Data source: SEC filings (DEF 14A proxy, 8-K Item 2.02), company IR pages
2. No API key required
3. Historical dividend data in stock data you already fetch

**Create new file:** `server/src/lib/dividendSignals.ts`
- Function: `analyzeDividendSignal(ticker: string, stockData: StockDataResult): Promise<DividendSignal>`
- Check: Is this first dividend ever?
- Check: Dividend yield increase, payout ratio change
- Return: `{ dividendInitiated: boolean, yieldChange: number, payoutRatio: number, signal: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `dividendSignal?: DividendSignal | null` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreFundamental()`:
  - First dividend ever = +70pts (cash generation proof)
  - Dividend increase on flat payout = +50pts (earnings acceleration)
- `server/src/lib/opportunity.ts` → `data_snapshot` → Add `dividend_initiated`, `yield_pct`, `payout_ratio`

**Why it works:** Management only initiates dividend when confident in sustained profitability. High-conviction inflection signal.

---

### [ ] 5. Reddit/Social Mention Velocity

**What it does:** Detects crowdsourced alpha. Underfollowed stock suddenly mentioned 10x more = discovery phase.

**Setup:**
1. Data source: Reddit r/stocks, r/investing, r/securityanalysis (web scrape, free)
2. Alternative: Pushshift Reddit archive (free, historical)
3. No API key required

**Create new file:** `server/src/lib/socialSentiment.ts`
- Function: `getRedditMentionVelocity(ticker: string): Promise<SocialSignal>`
- Search r/stocks, r/investing for ticker mentions (past week vs past month)
- Calculate: velocity = mentions_this_week / mentions_last_month
- Parse top posts for sentiment (bullish/bearish keywords)
- Return: `{ mentionVelocity: number, mentionsThisWeek: number, mentionsLastMonth: number, sentiment: string, signal: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `socialSentiment?: SocialSignal | null` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreContrarian()`:
  - Mention velocity >5x + underfollowed (≤2 analysts) = +70pts (discovery signal)
  - Mention velocity >3x = +50pts (attention inflection)
- `server/src/lib/opportunity.ts` → `data_snapshot` → Add `reddit_mention_velocity`, `reddit_sentiment`

**Why it works:** Retail discovers mispricing before institutions. Mention surge = retrocausal alpha (discovery happening now, repricing in 4-12 weeks).

---

### [ ] 6. Options Implied Volatility (IV) Expansion

**What it does:** Rising IV on beaten-down stock = market pricing in upcoming binary catalyst. Falling IV = market pricing out risk.

**Setup:**
1. Data source: Yahoo Finance options chain (free, public)
2. Alternative: Brave search for IV data from financial sites
3. No API key required

**Create new file:** `server/src/lib/optionsSignals.ts`
- Function: `analyzeOptionsVol(ticker: string): Promise<OptionsSignal>`
- Fetch 30-day implied volatility (free from Yahoo via Brave search)
- Compare: current IV vs 52-week avg
- Calculate: IV expansion % = (current - 52wk avg) / 52wk avg * 100
- Return: `{ impliedVol: number, ivExpansion: number, putCallRatio: number, signal: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `optionsSignal?: OptionsSignal | null` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreContrarian()`:
  - IV expanding + stock down >20% YTD + bullish thesis = +60pts (pre-catalyst setup)
  - IV contracting + stock up = +40pts (complacency risk)
- `server/src/lib/opportunity.ts` → `data_snapshot` → Add `implied_vol`, `iv_expansion_pct`, `put_call_ratio`

**Why it works:** Options market prices in binary events 2-4 weeks ahead. IV expansion on downturn = smart money loading.

---

### [ ] 7. Insider Form 3 & Form 5 Analysis

**What it does:** Form 3 (initial) = founder/insider confirmation. Form 5 (annual) = unreported transactions = hidden signal.

**Setup:**
1. Data source: SEC EDGAR (same CIK lookup as Form 4)
2. Reuse existing `insider.ts` scraping patterns
3. No API key required

**Enhance:** `server/src/tools/insider.ts`
- Add Form 3 scraping: new insiders = founder confirmation
- Add Form 5 scraping: annual summary = detect large unreported transactions
- Extend `InsiderResult` with:
  - `form3Insiders?: string[]` — newly registered insiders (founder signal)
  - `form5UnreportedVolume?: number` — shares from Form 5 (hidden insider activity)

**Integrate into:**
- `server/src/lib/signals.ts` → `scoreInsider()`:
  - New Form 3 filing for CEO = +80pts (founder confirmation)
  - Form 5 unreported volume >1M shares = +50pts (insider accumulation)

**Why it works:** Form 3 = founder/executive newly registering = major signal. Form 5 = annual summary catches late disclosures.

---

## TIER 3: OPTIONAL (Nice-to-Have, Lower Implementation Priority)

### [ ] 8. Competitor Earnings Beats/Misses

**What it does:** Peer company earnings miss = headwind for sector. Peer beat = tailwind for your stock.

**Setup:**
1. Data source: Seeking Alpha (free, web scrape), Yahoo Finance earnings calendar
2. No API key required

**Create new file:** `server/src/lib/peerEarningsSignals.ts`
- Function: `trackPeerEarnings(ticker: string): Promise<PeerEarningsSignal>`
- Identify peer companies (from peers.ts)
- Fetch last 5 earnings results for each peer
- Track: beats vs misses
- Return: `{ peerBeatsCount: number, peerMissesCount: number, sectorMomentum: number, signal: string }`

**Integrate into:**
- `server/src/lib/signals.ts` → `scoreSentiment()`:
  - All peers beat in last 2 quarters = +55pts (sector tailwind)
  - All peers missed = +50pts (contrarian setup if your stock beat)

---

### [ ] 9. Board Composition Changes

**What it does:** New independent directors = governance upgrade. Director departures = turmoil.

**Setup:**
1. Data source: SEC DEF 14A (proxy statements, annual)
2. Reuse SEC parsing from `secAnalysis.ts`
3. No API key required

**Enhance:** `server/src/lib/secAnalysis.ts`
- Add DEF 14A parsing: board member additions, departures, independence ratio
- Return: `{ boardChanges: BoardChange[], independenceRatio: number }`

**Why it works:** Board changes = strategic inflection. New independent directors = activist pressure or transition.

---

### [ ] 10. Debt Maturity Spikes & Refinancing Risk

**What it does:** Large debt due next year = refinancing risk. If rates rising = problematic. If rates falling = opportunity.

**Setup:**
1. Data source: SEC 10-K Item 7 (Liquidity & Capital Resources), 10-Q Item 1 (Financial Statements)
2. Reuse SEC parsing
3. No API key required

**Enhance:** `server/src/lib/secAnalysis.ts`
- Parse debt schedule: annual maturities by year
- Flag: >10% of debt due in next 12 months = refinancing concentration
- Return: `{ debtMaturitiesNext12M: number, refinancingRisk: string }`

**Integrate into:**
- `server/src/lib/signals.ts` → `scoreFundamental()`:
  - Debt spike + rising rates = -40pts (refinancing pressure)
  - Debt paid down = +30pts (deleveraging discipline)

**Why it works:** Refinancing risk = hidden balance sheet risk. Debt paydown = confidence + cash generation.

---

## .ENV FILE UPDATES

No new API keys required. All sources are free + web scrape (Brave Search existing key) or SEC public data.

---

## IMPLEMENTATION CHECKLIST

### Code Files (by priority)

**Tier 1 (IMPLEMENT FIRST):**
- [ ] `server/src/lib/analystRevisions.ts` (NEW)
- [ ] `server/src/lib/squeezeAnalysis.ts` (NEW)
- [ ] `server/src/lib/buybackAnalysis.ts` (NEW)

**Tier 2 (IMPLEMENT SECOND):**
- [ ] `server/src/lib/dividendSignals.ts` (NEW)
- [ ] `server/src/lib/socialSentiment.ts` (NEW)
- [ ] `server/src/lib/optionsSignals.ts` (NEW)
- [ ] `server/src/tools/insider.ts` (ENHANCE — Form 3/5)

**Tier 3 (IMPLEMENT THIRD):**
- [ ] `server/src/lib/peerEarningsSignals.ts` (NEW)
- [ ] `server/src/lib/secAnalysis.ts` (ENHANCE — board + debt)

### Files to Update (all tiers)

- [ ] `server/src/lib/enrich.ts` (ADD 10 new optional fields)
- [ ] `server/src/lib/signals.ts` (ADD scoring for 10 signals)
- [ ] `server/src/lib/opportunity.ts` (ADD 15-20 new data_snapshot fields)
- [ ] `server/src/routes/radar.ts` (PASS new enrichment fields to buildRadarRow)

---

## INTEGRATION CHECKLIST

1. **Data Source Testing:**
   - [ ] Analyst revisions: Seeking Alpha scrape works
   - [ ] Float calc: Math on existing stock data
   - [ ] Buyback: SEC 10-K parsing works
   - [ ] Dividend: Data already in stock fetch
   - [ ] Reddit: r/stocks scrape works
   - [ ] IV: Yahoo options data accessible
   - [ ] Form 3/5: SEC EDGAR fetch works
   - [ ] Peer earnings: Seeking Alpha scrape works
   - [ ] Board: DEF 14A parsing works
   - [ ] Debt: 10-K Item 7 parsing works

2. **Build & Test:**
   - [ ] `npm run build` → zero errors
   - [ ] Test on known tickers with signals (PLTR, KTOS, NVDA)
   - [ ] Verify all new fields appear in `data_snapshot`
   - [ ] Check scoring integration (new signals contribute to composite score)

---

## SUCCESS CRITERIA

Each integration is complete when:

- [ ] Data source is accessible and tested
- [ ] New lib file is written and compiles
- [ ] New fields are added to `TickerEnrichment` in `enrich.ts`
- [ ] Signals are integrated into scoring in `signals.ts`
- [ ] New fields are persisted to `data_snapshot` in `opportunity.ts`
- [ ] Build passes: `npm run build` → zero errors
- [ ] Test on known ticker and verify new signals appear

---

## PRIORITY ORDER

**Week 1:** Analyst Revisions + Float Squeeze (highest alpha)
**Week 2:** Buyback + Dividend Signals (management confidence)
**Week 3:** Reddit Mentions + Options IV (crowdsourced + smart money)
**Week 4:** Insider Form 3/5 Enhancement (complement existing)
**Optional:** Peer Earnings, Board Changes, Debt Maturity (lower priority)

---

## ESTIMATED EFFORT

- Tier 1: 1-2 days (straightforward integrations)
- Tier 2: 2-3 days (web scraping, sentiment analysis)
- Tier 3: 1-2 days (SEC parsing enhancements)
- **Total: 4-7 days for all 10 signals**

---

## EXPECTED ALPHA BOOST

- **Analyst Revisions:** +8-12% accuracy (inflection leading indicator)
- **Float/Squeeze:** +6-10% accuracy (binary catalyst detection)
- **Buyback + Dividend:** +4-6% accuracy (management conviction)
- **Reddit + IV:** +5-8% accuracy (crowdsourced + smart money)
- **Form 3/5 + Peers + Board + Debt:** +2-4% cumulative

**Total expected improvement: 30-50% better early inflection detection**

---

## QUESTIONS FOR OPUS

Before starting implementation:

1. **Reddit scraping legality?** Safe to scrape r/stocks for mentions?
2. **Analyst revisions source preference?** Seeking Alpha free tier vs Yahoo Finance?
3. **Options IV priority?** How often should IV be fetched? (Daily? Weekly?)
4. **Float calculation?** Use insider ownership from existing data, or fetch separately?
5. **Parallel fetching?** Can all 10 signals be fetched in parallel in enrich.ts, or will it hit rate limits?
