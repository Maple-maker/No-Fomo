# NoFomo Alpha Sources — Implementation Checklist

**Status:** 🎯 High-Priority Integration (Free Data Sources)
**Owner:** Hermes
**Goal:** Add 6 new contrarian signal sources to improve early inflection detection

---

## TIER 1: IMMEDIATE (Highest Alpha Impact)

### [ ] 1. Patent Filing Velocity + Citations (USPTO)

**What it does:** Detects R&D acceleration 12-24 months before earnings inflection

**Setup:**
1. Go to: [USPTO PatentsView API](https://www.patentsview.org/apis/intro)
2. No API key required (free public API)
3. Add to `.env` files:
   ```bash
   # .env and server/.env (optional, for reference)
   USPTO_API_BASE=https://api.patentsview.org/patents/query
   ```

**Create new file:** `server/src/lib/patents.ts`
- Function: `getPatentAcceleration(ticker: string, companyName: string): Promise<PatentSignal>`
- Calculate: (patents filed Q4 2025) vs (patents filed Q4 2024) = YoY acceleration %
- Track: Citation count (other patents citing theirs) = moat strength
- Return: `{ acceleration: number, citationDensity: number, totalFilings: number }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `patentAcceleration?: number` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreFundamental()` → Add patent signal (>20% acceleration = +75pts)
- `server/src/lib/opportunity.ts` → `RadarRow.data_snapshot` → Add `patent_acceleration`

**Testing:**
```bash
# Test USPTO API for Intel
curl "https://api.patentsview.org/patents/query?q={\"inventor_last_name\":\"Intel\"}" | jq .
```

---

### [ ] 2. Job Posting Acceleration (Indeed/LinkedIn scraping)

**What it does:** Hiring growth signals management confidence 3-6 months before revenue

**Setup:**
1. **Indeed:** Limited free tier available at [Indeed Open](https://opensource.indeedeng.io/api-documentation/)
   - No API key needed for public job scraping
2. **LinkedIn:** Can scrape via public profile URLs (legally gray area, use cautiously)
   - Alternative: Use free tier of [JazzHR API](https://www.jazzhr.com/api/) if focusing on specific company pages

**Create new file:** `server/src/lib/jobPosting.ts`
- Function: `getJobAcceleration(ticker: string, companyName: string): Promise<JobSignal>`
- Track job postings by company on Indeed
- Calculate: (current month postings) vs (same month prior year) = YoY growth %
- Segment by: Engineering, Sales, Operations, R&D (to detect strategy)
- Return: `{ acceleration: number, postingCount: number, departmentBreakdown: Record<string, number> }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `jobAcceleration?: number` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreFundamental()` → Add job signal (>30% hiring acceleration = +70pts)
- `server/src/lib/opportunity.ts` → `RadarRow.data_snapshot` → Add `job_acceleration`

**Testing:**
```bash
# Scrape Indeed jobs for "Palantir Technologies"
curl "https://www.indeed.com/jobs?q=Palantir+Technologies" | grep -o 'title="[^"]*"' | wc -l
```

---

### [ ] 3. SEC EDGAR Advanced Parsing (Enhanced)

**What it does:** Flag management changes, accounting shifts, risk factor updates = strategy inflection

**Setup:**
1. Already using SEC EDGAR via existing tools
2. Enhance parsing in new file: `server/src/lib/secAnalysis.ts`
3. No new API key needed

**Create new file:** `server/src/lib/secAnalysis.ts`
- Function: `parseEDGARForInflection(ticker: string, cik: string): Promise<SECSignal>`
- Parse 10-K/10-Q for:
  - **Management changes:** CEO/CFO/Chairman turnover (Item 10 or 8-K)
  - **Accounting changes:** New auditor, restatements, accounting policy shifts (Item 9/9A)
  - **Risk factor removals:** If company removes risk factor it had before = problem solved
  - **Going concern notes:** Going concern absence = financial stabilization
  - **Material contracts:** New major contracts (8-K Item 1.01)
- Return: `{ managementChanges: Change[], accountingChanges: Change[], riskFactorDeltas: string[], materialContracts: Contract[] }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `secAnalysis?: SECSignal` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreContrarian()` → Management changes = +30pts (new CEO = strategy shift)
- `server/src/lib/opportunity.ts` → `RadarRow.data_snapshot` → Add `sec_management_changes`, `sec_risk_removals`

**Testing:**
```bash
# Query SEC for PLTR Form 8-K filings (management changes)
curl "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=1321655&type=8-K&dateb=&owner=exclude&count=10&output=json" | jq .
```

---

## TIER 2: HIGH PRIORITY (Strong Signals, Low Implementation Cost)

### [ ] 4. Earnings Call Transcript Sentiment Analysis

**What it does:** Management tone reveals bullishness before stock price reprices

**Setup:**
1. Transcripts are free from:
   - [Seeking Alpha](https://seekingalpha.com/) (no auth needed)
   - [TranscriptMe](https://transcriptme.com/) (free)
   - Company investor relations pages
2. No API key needed

**Create new file:** `server/src/lib/transcriptAnalysis.ts`
- Function: `analyzeTranscriptSentiment(ticker: string, transcriptText: string): Promise<TranscriptSignal>`
- Tokenize transcript, search for:
  - **Confidence words:** "confident", "optimistic", "accelerating", "strong" = bullish
  - **Uncertainty words:** "cautious", "challenged", "uncertain", "headwinds" = bearish
  - **Guidance tone:** "we expect" vs "we hope" vs "we're targeting"
  - **New product mentions:** Products not mentioned before = catalyst
  - **Competitive threat acknowledgment:** "competition intensifying" = market shift
- Compare YoY to detect inflection (tone improving despite stock down = contrarian signal)
- Return: `{ sentimentScore: number, confidenceLevel: number, newProducts: string[], competitiveThreats: string[] }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `transcriptSentiment?: TranscriptSignal` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreContrarian()` → Tone improving but stock down = +60pts
- `server/src/lib/opportunity.ts` → `RadarRow.data_snapshot` → Add `transcript_sentiment_score`

**Testing:**
```bash
# Fetch PLTR latest earnings call (from Seeking Alpha)
curl "https://seekingalpha.com/article/4700000-palantir-technologies-inc-pltr-q1-2026-earnings-call-transcript" | grep -i "confident\|optimistic\|challenging" | head -5
```

---

### [ ] 5. Short Seller Report Aggregation

**What it does:** Contrarian signal when shorts attack beaten-down stocks with improving fundamentals

**Setup:**
1. Reports are freely published by:
   - Hindenburg Research (website)
   - Citron Research (Twitter)
   - J Capital Research (website)
   - Reddit r/stocks, r/investing threads
2. No API key needed (web scraping)

**Create new file:** `server/src/lib/shortReports.ts`
- Function: `getShortReports(ticker: string): Promise<ShortReport[]>`
- Scrape Hindenburg website for published reports
- Scrape Reddit for short theses in relevant subreddits
- Parse Citron Twitter posts (if public API available)
- Return: `{ report: string, source: string, date: string, mainThesis: string, url: string }`

**Integrate into:**
- `server/src/lib/enrich.ts` → Add `shortReports?: ShortReport[]` to `TickerEnrichment`
- `server/src/lib/signals.ts` → `scoreContrarian()` → If short report exists BUT insider buying + patents up = **-40pts to short thesis credibility** (they're wrong)
- `server/src/lib/opportunity.ts` → `RadarRow.data_snapshot` → Add `short_report_found`, `short_thesis_contradicted`

**Testing:**
```bash
# Check if Hindenburg has report on company
curl "https://hindenburgresearch.com" | grep -i "TICKER"
```

---

### [ ] 6. Insider Trading Confidence Scoring (Enhanced)

**What it does:** CEO/Founder personal buys trump trust/option exercises (highest conviction signal)

**Setup:**
1. Already collecting Form 4 data
2. Enhance in: `server/src/tools/insider.ts`
3. No new API key needed

**Enhance existing file:** `server/src/tools/insider.ts`
- Refine `analyzeInsider()` to distinguish:
  - **CEO personal open-market buy** = 10x more meaningful than director buy
  - **Founder owns >5% and buying more** = ultimate conviction
  - **Option exercises vs. grants** = exercise = bullish, grant = comp
  - **Selling under 10b5-1 plan** = less bearish than ad-hoc sales
  - **Cross-company insider buying in theme** = sector inflection (multiple defense CEOs buying = DoD inflection)
- Return enhanced: `{ clusterScore: number, ceoPersonalBuyingScore: number, founderAlignment: boolean }`

**Integrate into:**
- `server/src/lib/signals.ts` → `scoreInsider()` → CEO personal buy = 95pts (vs. 70pts for cluster)
- `server/src/lib/signals.ts` → `scoreContrarian()` → Founder + CEO buying beaten-down stock = +85pts

**Testing:**
```bash
# Check PLTR Form 4 for CEO/Founder (Karp) insider buys
curl "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=1321655&type=4&dateb=&owner=only&count=40&output=json" | jq '.filings[] | select(.form_type=="4")'
```

---

## TIER 3: OPTIONAL (Nice-to-Have, Only if Time/Budget Allows)

### [ ] 7. Analyst Estimate Revisions Tracking

**What it does:** Real-time detection of analyst inflection points = repricing begins

**Setup:**
1. Free tier available at:
   - [Seeking Alpha](https://seekingalpha.com/) (shows estimate changes)
   - [Zacks](https://www.zacks.com/research) (free tier)
2. Or scrape Yahoo Finance estimate history

**Create new file:** `server/src/lib/analystRevisions.ts`
- Function: `trackAnalystRevisions(ticker: string): Promise<RevisionSignal>`
- Track: Earnings estimate changes over 90 days
- Signal: 3+ upward revisions in 30 days = inflection
- Return: `{ revisionMomentum: number, revisionsUp: number, revisionsDown: number }`

**Integrate into:**
- `server/src/lib/signals.ts` → `scoreFundamental()` → 3+ upward revisions = +60pts

---

### [ ] 8. Stock Buyback Tracking

**What it does:** Management capital allocation confidence signal

**Setup:**
1. Free from SEC 10-Q/10-K disclosures
2. No API key needed

**Enhance:** `server/src/lib/secAnalysis.ts` → Add buyback parsing
- Track: Buyback authorization dates, execution pace
- Compare buyback price to current stock price (buying at lows = smart allocation)
- Return: `{ buybackActive: boolean, sharesRepurchased: number, averagePrice: number, confidence: number }`

---

### [ ] 9. Regulatory Event Calendar

**What it does:** Binary catalysts (FDA approvals, FCC spectrum, FAA certifications)

**Setup:**
1. APIs available:
   - [FDA.gov API](https://www.fda.gov/drugs/development-approval-process-drugs) (free)
   - [FCC.gov API](https://www.fcc.gov/) (free, some scraping)
   - [FAA.gov](https://www.faa.gov/) (free scraping)
2. No API key needed

**Create new file:** `server/src/lib/regulatoryEvents.ts`
- Function: `getRegulatoryEvents(ticker: string, companyName: string): Promise<RegulatoryEvent[]>`
- Check FDA for pending drug approvals
- Check FCC for spectrum auction participation
- Check FAA for certification progress
- Return: `{ eventType: string, date: string, status: string, impact: "binary" }`

---

## .ENV FILE UPDATES

Add these to both `.env` and `server/.env`:

```bash
# TIER 1
USPTO_API_BASE=https://api.patentsview.org/patents/query
INDEED_API_BASE=https://www.indeed.com/jobs

# TIER 2
SEC_EDGAR_BASE=https://www.sec.gov/cgi-bin/browse-edgar
SEEKING_ALPHA_BASE=https://seekingalpha.com
HINDENBURG_BASE=https://hindenburgresearch.com

# TIER 3
FDA_API_BASE=https://api.fda.gov
FCC_API_BASE=https://www.fcc.gov
FAA_API_BASE=https://www.faa.gov
```

---

## INTEGRATION CHECKLIST

### Code Files to Create/Modify

- [ ] `server/src/lib/patents.ts` (NEW)
- [ ] `server/src/lib/jobPosting.ts` (NEW)
- [ ] `server/src/lib/secAnalysis.ts` (NEW)
- [ ] `server/src/lib/transcriptAnalysis.ts` (NEW)
- [ ] `server/src/lib/shortReports.ts` (NEW)
- [ ] `server/src/tools/insider.ts` (ENHANCE)
- [ ] `server/src/lib/enrich.ts` (UPDATE — add all new signal fields)
- [ ] `server/src/lib/signals.ts` (UPDATE — integrate signals into scoring)
- [ ] `server/src/lib/opportunity.ts` (UPDATE — add fields to RadarRow)

### Files to Update (Config)

- [ ] `.env` (add USPTO, Indeed, SEC, FDA, FCC, FAA bases)
- [ ] `server/.env.example` (document new bases)
- [ ] `.env.example` (document new bases)

### Integration Points

1. **`enrich.ts`** → Call each new lib function in parallel with existing enrichment
2. **`signals.ts`** → Add signals to `scoreFundamental()` and `scoreContrarian()` dimensions
3. **`opportunity.ts`** → Add new fields to `RadarRow.data_snapshot` for Supabase persistence
4. **`radar.ts`** → Pass new enrichment fields through to buildRadarRow()

---

## PRIORITY ORDER (If Doing Sequentially)

1. **Week 1:** SEC EDGAR Advanced Parsing (highest signal, lowest code complexity)
2. **Week 2:** Patent Filing Velocity (highest alpha, medium complexity)
3. **Week 3:** Job Posting Acceleration (strong signal, medium complexity)
4. **Week 4:** Earnings Call Sentiment (real-time insight, medium complexity)
5. **Week 5:** Enhanced Insider Scoring (improve existing, low complexity)
6. **Week 6:** Short Report Aggregation (contrarian signal, medium complexity)
7. **Optional:** Analyst Revisions, Buyback Tracking, Regulatory Events

---

## SUCCESS CRITERIA

Each integration is complete when:

- [ ] API/data source is accessible and tested (curl command succeeds)
- [ ] New `lib/` or enhanced `tools/` file is written and compiles
- [ ] New fields are added to `TickerEnrichment` in `enrich.ts`
- [ ] Signals are integrated into `scoreFundamental()` or `scoreContrarian()` in `signals.ts`
- [ ] New fields are persisted to `RadarRow.data_snapshot` in `opportunity.ts`
- [ ] Build passes: `npm run build` → zero errors
- [ ] Test on a known ticker (PLTR or KTOS) and verify new signals appear in radar response

---

## QUESTIONS FOR HERMES

Before starting, clarify:

1. **Scraping limits:** Any restrictions on scraping Indeed/LinkedIn? (Legal clearance needed)
2. **Transcript source preference:** Use Seeking Alpha free tier or build scraper for company IRs?
3. **Short report frequency:** Update daily, weekly, or on-demand?
4. **Parallel vs. sequential:** Build all 6 in parallel (risky, need 6 devs) or sequential (safer, slower)?

---

**Estimated effort (for one dev):** 4-6 weeks for all TIER 1 + TIER 2 integrations
**Expected alpha boost:** 25-40% improvement in early inflection detection (patent + job + mgmt signals)
