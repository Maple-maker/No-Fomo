# NoFomo Stock Selection Criteria — Current State & Improvement Ideas

## Current Selection Framework (Plain Language)

### 1. **Technical Scoring (25% weight)**
Looks for near-term trading setup signals:
- **RSI oversold** (<30): Says stock momentum is beaten down, bounce potential
- **MACD bullish**: Trend-following confirmation
- **Bollinger Band position**: Price near support (lower band) = bounce zone
- **Volume spike**: >1.5x average volume suggests accumulation/buying

**What it catches:** Short-term reversal plays, panic sellers creating entry points
**What it misses:** Structural multi-year transformations, hidden demand shifts

---

### 2. **Fundamental Scoring (30% weight)**
Analyzes analyst expectations vs. reality:
- **Analyst consensus**: Numerical rating (1=Strong Buy, 5=Strong Sell)
- **Price target upside**: Gap between current price and consensus mean target
- **Analyst coverage**: Validates thesis credibility (more analysts = more validation)
- **Short interest**: High short % (>20%) flags potential squeeze or thesis rejection

**What it catches:** Obvious mispricing consensus sees but market hasn't repriced
**What it misses:** Situations where consensus is structurally wrong (early-stage transformations, underfollowed names)

---

### 3. **Sentiment Scoring (25% weight)**
Measures narrative momentum and AI judgment:
- **Headline count**: Attention threshold (5+ headlines = moderate interest)
- **Council verdict**: DeepSeek, Gemini, Claude AI council calls bull/bear
- **WSB mentions**: Retail attention (Quiver data)

**What it catches:** Narratives gaining traction, early-stage Reddit hype
**What it misses:** Contrarian opportunities (best ideas are non-consensus by definition)

---

### 4. **Insider Scoring (20% weight)**
Flags concentrated insider buying patterns:
- **Cluster score**: 3+ insiders buying in 60 days = high credibility
- **Net sentiment**: Buy volume > Sell volume = bullish insider signal
- **Unique buyers**: Multiple insiders (vs. single large buyer) reduces single-person bias

**What it catches:** Smart money putting money where mouth is
**What it misses:** Timing (insiders don't have perfect alpha), derivative transactions (options exercises ≠ conviction)

---

### 5. **Screening Route**
Lightweight pre-filter on 75-ticker watchlist:
```
Score = RSI signal + Volume signal + Short signal + Revenue growth + FwdPE + Analyst upside
```
Returns top 50 candidates sorted by composite score.

**Strength:** Fast, free, catches mean-reversion setups
**Weakness:** Mechanical, crowded, misses visionary narratives

---

## What the Current System Gets Right ✓

1. **Multi-dimensional scoring** — combines technical, fundamental, sentiment, insider signals
2. **AI council debate** — three independent model perspectives (bull, bear, neutral arbiter)
3. **Free SEC EDGAR parsing** — taps insider Form 4 filings directly (no API cost)
4. **Quiver integration** — government contracts + Congressional trading + WSB sentiment
5. **Analyst divergence** — spots where AI council disagrees with Wall Street consensus
6. **Live web search** — DeepSeek research with Brave + Exa neural search before dossier writing

---

## Critical Gaps & Improvement Ideas

### **Gap 1: Too Short-Term / Technical**
Current system is tuned for 4-8 week bounce trades, not 18-36 month structural inflections.

**Improvement ideas:**
- Add **"Narrative Velocity" detector**: Track velocity of theme mentions over time (AI contract awards accelerating month-over-month = structural trend, not noise)
- Add **"Market Cap Inflection" scan**: Companies that crossed $1B market cap in last 12 months (often re-rated higher after hitting index inclusion threshold)
- Add **"Revenue inflection detection"**: Identify quarters where YoY growth inflected upward (first quarter positive, accelerating from prior quarter)

---

### **Gap 2: Missing Government Contract Catalysts**
System collects government contracts via Quiver but doesn't proactively scan SAM.gov for EMERGING contract awards.

**Improvement ideas:**
- **Systematic SAM.gov crawler**: Monitor DoD, DARPA, NASA, DOE new awards weekly; flag sole-source contracts and multi-year task orders
- **NDAA/Congressional budget scanner**: Tie defense contractor awards to NDAA authorizations and congressional budget justifications
- **Contract value + runway calculator**: If company wins $50M contract and run rate is $200M revenue, automatically flag the accretion and years of visibility
- **Prime vs. subcontractor mapper**: Distinguish between direct awards (company is prime) and indirect exposure (company supplies to prime contractor)

---

### **Gap 3: Consensus-Averse Screening**
Current system *reads* analyst consensus, but doesn't systematically hunt for non-consensus theses.

**Improvement ideas:**
- **"Underfollowed" filter**: Tier stocks by analyst count: 0–2 (severely underfollowed) vs. 3–5 (underfollowed) vs. 10+ (well-followed)
- **"AI council vs. Wall Street divergence" score**: When Gemini/DeepSeek/Claude rate bullish but analyst consensus is "hold" or "reduce," flag as highest-conviction contrarian setup
- **"No ETF home" detector**: Companies with high institutional ownership but NOT in any major ETF = mispriced due to structural exclusion
- **"Sector rotation trade" scan**: When a stock's sector sells off 20%+ but company beats estimates, flag as sector dislocation victim with low institutional float

---

### **Gap 4: No Management/Capital Allocation Quality Scoring**
Insider buying is tracked, but no systematic way to gauge CEO quality, track record, capital allocation discipline, or skin-in-the-game strength.

**Improvement ideas:**
- **"Founder-led" boost**: If CEO/founder is CEO + still owns >5% = automatic 15% upside adjustment to conviction scoring
- **"CEO/CFO insider purchases" filter**: Flag open-market purchases by C-suite (not just options exercises, not 10b5-1 plan sales)
- **"Management tenure score"**: Newly appointed CEO (<6 months) = higher execution risk; long-tenure CEO (10+ years) = potentially stale
- **"Free cash flow allocation track record"**: Compare FCF generated vs. capital deployment (buyback discipline, acquisition returns, debt reduction)

---

### **Gap 5: Missing Spinoff / Corporate Action Catalysts**
No systematic scanning for forced sellers, misunderstood separations, or carve-outs.

**Improvement ideas:**
- **"SEC event trigger" scanner**: 8-K filings flagging M&A, spinoffs, major divestitures, regulatory approvals
- **"Index rebalancing impact"**: When company enters Russell 2000 or leaves S&P 500, it forces algorithmic flows; track these dates
- **"Activist investor emergence"**: Form 13D flings flagging 5%+ stakes taken by activist funds
- **"Bankruptcy emergence": Track companies exiting bankruptcy proceedings (debt restructuring often creates extreme value)

---

### **Gap 6: No Disclosure Quality / Red Flag Scoring**
System doesn't systematically hunt for deteriorating fundamentals being masked by adjusted metrics.

**Improvement ideas:**
- **"GAAP vs. non-GAAP gap detector"**: Calculate (Non-GAAP earnings - GAAP earnings) / GAAP earnings YoY; widening gap = earnings quality deterioration
- **"Guidance cut frequency"**: Track 10-K guidance changes quarter-over-quarter; repeated cuts = execution risk
- **"Accounts receivable growth > revenue growth"**: Aging receivables can signal weak sales or channel stuffing
- **"Inventory/COGS ratio anomaly"**: Inventory growth significantly outpacing COGS = potential write-down risk
- **"Stock-based comp as % of revenue"**: Growing dilution relative to revenue = management confidence deteriorating

---

### **Gap 7: Patent / IP Strength Not Systematized**
No automated patent filing tracking or intellectual property moat assessment.

**Improvement ideas:**
- **"Patent filing velocity"**: Monitor USPTO filings in key technology categories; acceleration in patent applications = R&D pipeline activity
- **"Patented revenue %"**: Estimate share of revenue protected by exclusive patents (high-risk if patents expiring soon)
- **"Technology citation score"**: Track how often company's patents are cited by competitors (proxy for innovation significance)
- **"Trade secret risk"**: Flag companies heavily reliant on trade secrets (vs. patents) = higher key-person risk

---

### **Gap 8: Missing Secular Trend Beneficiaries**
Current AI detection is Quiver-based and headline-driven; no systematic thematic screening.

**Improvement ideas:**
- **"Defense/Space/AI spending beneficiary" tagger**: Automatically classify companies by their exposure to:
  - Defense tech modernization (NDAA funding growth)
  - Commercial space buildout (SpaceX, Blue Origin ecosystem)
  - AI infrastructure (model training, inference chips, data centers)
  - Energy transition (battery, grid, EV supply chain)
- **"Customer concentration risk vs. revenue"**: DoD companies winning $50M contracts but total revenue $300M = 17% revenue exposure; flag if >15% (concentration risk) but also flag when contract extends to <5% (upside optionality)
- **"Total addressable market growth"**: Segment TAM by geography/use case; companies with TAM expanding 2x+ faster than guidance = underpenetrated

---

### **Gap 9: No Valuation Context vs. Growth Peer Cohort**
Current system uses absolute metrics (P/E, P/S) but no peer-relative "value trap vs. cheap growth" sorting.

**Improvement ideas:**
- **"PEG Score"**: P/E ÷ Revenue Growth % — lower = better value relative to growth (0.5–1.0 = attractive, 2.0+ = overvalued)
- **"Peer cohort positioning"**: For every opportunity, compute 25th/50th/75th percentile multiples across 3–5 comparable peers; flag if trading at bottom quartile despite same growth profile
- **"Free cash flow multiple"**: Price/FCF is more resilient than P/E for companies managing earnings via accounting (harder to fake cash)
- **"Enterprise Value vs. Revenue"**: EV/Revenue insulates from balance sheet noise; companies with sub-2.0x EV/Revenue and 15%+ growth = potential value trap resolution

---

### **Gap 10: No Qualtrim-Style Competitive Analysis Automation**
Current dossier requests competitive advantages, but no systematic moat scoring.

**Improvement ideas:**
- **"Cost structure advantage"**: Flag companies with 200+ bps gross margin advantage vs. peers (harder to copy than brand)
- **"Customer switching cost measurement"**: Score likelihood of customer switching based on:
  - Contractual lock-in (multi-year agreements in 10-K)
  - Integration depth (APIs, custom builds = higher switching cost)
  - Customer concentration (few large customers = higher retention value)
- **"Proprietary data moat"**: Flag companies with exclusive data (insurance loss runs, clinical trial data, infrastructure topology maps)
- **"Pricing power trajectory"**: Track average selling price (ASP) vs. inflation; if ASP growing 2x faster than inflation = pricing power

---

## Prioritized Implementation Roadmap

### **Tier 1 (Quick Wins — 1 week)**
These unlock massive signal quality improvement with minimal code:

1. **"Underfollowed" filter**: Add analyst count buckets (0–2, 3–5, 10+) to screening route
2. **"AI vs. Wall Street divergence" score**: When council is bullish + analysts <3 = +20 points to conviction
3. **"Revenue inflection" detector**: Identify quarters where YoY growth flipped positive or accelerated
4. **"Management quality" boost**: +15 conviction if founder-led + >5% ownership

### **Tier 2 (High Impact — 2 weeks)**
Systemic improvements with meaningful edge:

5. **SAM.gov contract crawler**: Weekly scan of new DoD/DARPA/NASA/DOE awards; auto-flag companies winning $20M+
6. **GAAP vs. non-GAAP gap detector**: Add to 10-K scraper; flag if ratio widening
7. **Guidance change frequency**: Track 10-K guidance revisions YoY; repeated cuts = execution risk

### **Tier 3 (Structural — 4 weeks)**
Differentiation from wall street consensus:

8. **Patent filing velocity**: USPTO monitoring for acceleration in key tech areas
9. **Secular theme tagger**: Auto-classify by defense/space/AI/energy exposure with TAM scoring
10. **Peer cohort positioning**: PEG scores, EV/Revenue percentile ranks vs. 3–5 comps

---

## Scoring Adjustment Proposal

Current weights (arbitrary):
- Technical 25% + Fundamental 30% + Sentiment 25% + Insider 20%

**Proposed for asymmetric hunting:**
- **Contrarian positioning** 25% (underfollowed + AI divergence + sector dislocation)
- **Catalyst strength** 25% (government contracts + revenue inflection + earnings inflection)
- **Moat durability** 20% (management quality + cost advantage + competitive positioning)
- **Valuation** 20% (PEG + EV/Revenue vs. peers + FCF multiple)
- **Insider conviction** 10% (cluster score, but weighted lower because timing is hard)

This rebalancing **privileges non-consensus narrative + near-term catalyst triggers** over short-term technical bounces.

---

## Source Integrity Checks (Already Enforced)

✓ All SEC filings link to sec.gov/Archives direct URLs  
✓ Government contracts link to sam.gov award pages  
✓ Brave Search returns clickable primary sources  
✓ Insider Form 4 data fetched directly from EDGAR (no intermediary)  
✓ Quiver data has date stamps; Quiverquant aggregates from official sources  

**Key discipline:** If a source URL doesn't resolve, the conviction score is zero. No fabrication.

---

## Final Thought

The current system is *solid for efficient-market detection* (finding where consensus is slightly wrong). To hunt **true asymmetry**, it needs to:

1. **Systematically scan for non-consensus narratives** (underfollowed, undifferentiated AI council vs. Street)
2. **Automate government/regulatory catalysts** (SAM.gov, NDAA, FCC/FDA approvals)
3. **Distinguish cheap from undervalued** (GAAP quality, peer positioning, moat durability)
4. **Reward high-conviction management** (founder-led, skin-in-game, capital discipline)

These aren't tweaks — they're architectural shifts toward **finding what the market hasn't priced in** rather than what it's slightly misprice.
