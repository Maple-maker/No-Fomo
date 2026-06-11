# NoFomo Scoring Model v1.2 — Asymmetric Opportunity Detection

## Composite Score Formula

```
Composite (0-100) = 
  Technical (20%) +
  Fundamental (25%) +
  Sentiment (15%) +
  Insider (20%) +
  Contrarian (20%) ← NEW: Non-consensus weighting
```

Each dimension is independently scored 0-100 based on sub-signals, then weighted into the composite.

---

## Dimension Breakdowns

### 1. Technical (20%)
**Measures:** Short-term entry setup and momentum confirmation

**Sub-Signals:**
- **RSI 14:** <30 (oversold) = 80pts | <45 = 60 | 45-55 = 50 | 55-70 = 40 | >70 = 20
- **MACD Trend:** Bullish = 70 | Bearish = 30
- **Bollinger Position:** <25% of range (support) = 70 | 25-75% = 50 | >75% (resistance) = 30
- **Volume Ratio:** >1.5x avg = 70 | 1.0-1.5x = 55 | 0.5-1.0x = 45 | <0.5x = 35

**Caveat:** Decays in importance for contrarian ideas (noise without thesis)

---

### 2. Fundamental (25%)
**Measures:** Earnings quality, growth trajectory, analyst expectations

**Sub-Signals:**
- **Analyst Consensus (FLIPPED):**
  - 0 analysts = 95 (mystery discount) ← CHANGED: was penalty
  - 1-2 analysts = 80
  - 3-5 analysts = 60
  - 6-10 analysts = 50
  - >10 analysts = 40 (consensus = lower alpha)

- **Price Target Upside:** >30% = 85 | 10-30% = 65 | 0-10% = 50 | Negative = 25

- **Revenue Acceleration (NEW):**
  - >5% YoY growth acceleration = 90
  - >0% (growth reaccelerating) = 70
  - -5% to 0% = 50
  - <-5% (decelerating) = 30

- **GAAP Quality (NEW):**
  - OCF > NI × 1.5 (high quality) = 80
  - OCF > NI (good quality) = 65
  - NI > OCF (neutral) = 50
  - NI >> OCF (accruals concern) = 30

- **Earnings Miss Count (NEW):**
  - 0 recent misses = 70
  - 1 miss = 55
  - 2 misses = 45
  - 3+ misses = 25

- **Short Interest:**
  - >20% = 75 (squeeze potential)
  - 10-20% = 60
  - 5-10% = 50
  - <5% = 40

---

### 3. Sentiment (15%, reduced)
**Measures:** Narrative momentum and AI perspective

**Sub-Signals:**
- **Headline Count:** ≥5 recent = 60 | <5 = 40
- **AI Snapshot Present:** Yes = 55 | No = 0
- **Council Verdict:** BULL = 65 | BEAR = 35
- **WSB Mentions:** >10/week = 55 | <10 = 0

**Why Reduced?** Sentiment is noisiest dimension. Real asymmetry is invisible to narrative.

---

### 4. Insider (20%)
**Measures:** Smart money conviction and alignment

**Sub-Signals:**
- **Cluster Score (Form 4):**
  - ≥7 (3+ insiders buying in 60d) = 70-100 (proportional)
  - 4-6 = 50
  - 1-3 = 30
  - 0 = 0

- **Net Insider Sentiment:**
  - Bullish (buys > sells) = 75
  - Neutral (mixed) = 50
  - Bearish (sells > buys) = 25

- **Founder Alignment (NEW):**
  - Insiders own >10% = 90 bonus
  - Insiders own 5-10% = 75 bonus
  - Insiders own 2-5% = 55 bonus

---

### 5. Contrarian (20%, NEW) — THE ASYMMETRY ENGINE
**Measures:** Non-consensus positioning and market mispricing

**Sub-Signals (prioritized):**

**A. AI vs. Wall Street Divergence (HIGHEST CONVICTION):**
```
Council says BULL + Analyst coverage ≤3  = 95 pts
Council says BULL + Consensus = SELL     = 85 pts
Council says BULL + Coverage ≤2          = 80 pts
Council says BULL + Coverage general     = 60 pts
Council says BEAR                        = 40 pts
```

This catches the widest gaps: AI bullish where Street is blind or negative

**B. Underfollowed + Volume Accumulation (SMART MONEY DISCOVERY):**
```
≤2 analysts + Volume >1.3x avg = 90 pts
0 analysts (complete mystery)   = 85 pts
```

Signals early discovery by informed traders

**C. Peer Valuation Discount (VALUE + GROWTH):**
```
Bottom quintile percentile (<20)  = 90 pts
Bottom 40% percentile (<40)       = 70 pts
Fair (40-60)                      = 50 pts
Expensive (60-80)                 = 30 pts
Top quintile (>80)                = 20 pts
```

Uses PEG score (P/S ÷ RevGrowth) for growth-adjusted valuation rank

**D. Structural Tailwind (SECULAR DEMAND):**
```
Theme = Defense & GovTech           = 65 pts
Theme = AI & Data Infrastructure    = 65 pts
Theme = Energy Transition          = 55 pts
Theme = Commercial Space           = 55 pts
Other themes                        = 0 pts
```

Differentiates cyclical vs. structural repricing catalysts

**E. Founder Alignment (LONG-TERM THINKING):**
```
CEO/Founder owns >10%  = 90 pts
CEO/Founder owns 5-10% = 75 pts
CEO/Founder owns 2-5%  = 55 pts
```

Signals long-horizon capital allocation discipline

**F. Insider Cluster Buying (CONVICTION CORROBORATION):**
```
Cluster score ≥7 (3+ buying in 60d) = 80 pts
```

Confirms insiders see same asymmetry you do

**Composite within Contrarian Dimension:**
Average of all applicable sub-signals = Contrarian Score 0-100

---

## Practical Example: Scoring a Stock

### Scenario: Small-cap AI infrastructure company, underfollowed, profitable

**Technical (20%): 55**
- RSI 38 (slightly oversold) → 60
- MACD neutral → 50
- Bollinger upper band → 30
- Volume elevated → 70
- **Average: 55**

**Fundamental (25%): 72**
- Analyst count: 1 → 80 (underfollowed boost)
- Price target: 45% upside → 85
- Revenue acceleration: +12% → 90
- GAAP quality: OCF > NI × 1.2 → 65
- Earnings: 0 misses → 70
- **Average: 72**

**Sentiment (15%): 48**
- Headlines: 2 recent → 40
- AI Snapshot: Yes → 55
- Council: BULL → 65
- WSB: 3 mentions → 0
- **Average: 48**

**Insider (20%): 65**
- Cluster: Score 5 → 50
- Sentiment: Bullish (3 buys, 0 sells) → 75
- Founder: CEO owns 8% → 75
- **Average: 67**

**Contrarian (20%): 82**
- AI bullish + 1 analyst → 95
- 1 analyst + 1.8x volume → 90
- Peer percentile: 18th (cheap_growth) → 90
- Theme: AI & Data Infrastructure → 65
- CEO owns 8% → 75
- **Average: 83**

---

## Final Composite Calculation

```
Composite = (55 × 0.20) + (72 × 0.25) + (48 × 0.15) + (67 × 0.20) + (83 × 0.20)
          = 11 + 18 + 7.2 + 13.4 + 16.6
          = 66.2 ≈ 66
```

**Score 66** = Moderate Signal (but weighted toward underfollowed growth + AI vision)

**Key Insight:** If fundamental and contrarian are both 70+, and analyst count is ≤2, this would be flagged as **"mystery growth at a discount with founder alignment"** — classic PLTR/AMD pre-consensus setup.

---

## Tier Classification (from CIO Arbiter)

Based on composite score:

| Composite | Tier | Council Mode | Notification? |
|-----------|------|--------------|---------------|
| ≥80 | 1 | Full (Gemini+DeepSeek+Grok+Claude) | Yes, immediate |
| 65-79 | 2 | Speed (Gemini+DeepSeek+Claude) | If catalyst ≥8 |
| <65 | 3 | Budget (DeepSeek+Claude) | No |

**Triple Signal Trigger:** tier=1 OR score≥80 OR tripleSignal=true (insider cluster + 6mo catalyst + score≥80)

---

## Key Design Decisions

### 1. Contrarian Gets 20% Weight
**Why:** Asymmetric opportunities are non-consensus by definition. Consensus stocks are already priced. The market reprices contrarian ideas when it finally sees them.

### 2. Analyst Count Is Flipped
**Why:** Coverage = risk factor in efficient markets. Lack of coverage = potential alpha. An AI council bullish on a 0-analyst stock is a strong signal consensus has missed it.

### 3. Sentiment Is Lowest Weight
**Why:** Most public signal (everyone sees headlines, analyst ratings). Real asymmetry is less visible. Reduce noise dependency.

### 4. GAAP Quality Penalizes Accruals
**Why:** Growing companies that report earnings through accounting magic (options expensing, channel stuffing, reserves) often hit execution wall. Cash > GAAP earnings = sustainable.

### 5. Revenue Acceleration Is Binary
**Why:** A company that stops declining and starts growing again is a repricing catalyst. Reaccelerating growth = inflection point.

### 6. Founder Alignment Boosts Insider Score
**Why:** CEO insider buying is different from CFO. CEO buying means CEO sees the mispricing too and is willing to bet personal wealth.

---

## Scoring in Action: Three Types of Opportunities

### Type A: "Already-Consensus"
- High analyst count (20+)
- Price already at target
- Low contrarian score

**Example:** NVDA post-2023 AI explosion
- Analyst count: 40+ → 40pts (not exotic)
- Consensus aligns with AI council → 50pts (no divergence)
- Contrarian score: ~40

**Verdict:** Good stock but not asymmetric. Lower on radar.

---

### Type B: "Emerging Narrative"
- Moderate analyst count (5-10)
- Clear catalyst (new contract, inflection)
- Moderate contrarian score

**Example:** TSLA 2019 (path to profitability becoming real)
- Analyst count: 8 → 60pts
- Council bullish, consensus hold → 70pts divergence
- Revenue acceleration visible → 90pts
- Contrarian score: ~65

**Verdict:** Thesis is becoming visible but not fully priced. Medium-term asymmetry.

---

### Type C: "Pre-Consensus Asymmetry" ← TARGET
- Low analyst count (0-3)
- AI council bullish, Street skeptical
- Founder-aligned, profitable, accelerating
- High contrarian score

**Example:** PLTR 2019-2020 (pre-mainstream recognition)
- Analyst count: 2 → 80pts (underfollowed boost)
- Council bullish, consensus unsure → 90pts divergence
- Founder (Karp) owns stake → 75pts bonus
- Revenue acceleration obvious to insiders, invisible to analysts → 90pts
- Contrarian score: ~82

**Verdict:** Market will reprice over 12-36 months. 3-10x upside likely.

**That's the target. That's the system.**

---

## Refinements Coming Later

1. **Patent Filing Velocity** (USPTO API integration) — R&D pipeline signal
2. **Spinoff/Corporate Action Scanner** (8-K parsing) — forced selling opportunity
3. **Regulatory Approval Pipeline** (FDA, FCC, FAA, NRC) — binary catalysts
4. **Earnings Surprise Drift** (rolling % of beats) — management credibility
5. **Institutional Ownership Changes** (quarterly 13-F deltas) — early institutional discovery

These will further increase granularity in the fundamental and contrarian dimensions.

---

## How to Read Your Score

**Score 80+:** Tier 1 asymmetry. High confidence non-consensus position. Act with urgency.

**Score 65-79:** Tier 2. Clear thesis, reasonable catalyst, acceptable risk. Good conviction.

**Score 50-64:** Tier 3 / Watchlist. Interesting but missing 1-2 criteria. Monitor.

**Score <50:** Not asymmetric yet. Too consensus or too risky.

---

**Built to find:** The next PLTR before Karp. The next AMD before Zen. The next MU before NAND recovery.

**The systems buys what the system hasn't priced yet.**
