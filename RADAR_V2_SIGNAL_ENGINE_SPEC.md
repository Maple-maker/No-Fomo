# Radar V2 — Unified Signal Engine, Explainable Scoring & Backtest Harness

> **Claude Code task spec.** Drop this file in the repo root. Execute sessions in order (R1 → R4).
> Sessions R1–R3 are pure backend Python + tests — **zero iOS changes** — so they are safe to run
> in parallel with the July 1 beta sprint without touching the TestFlight path.
> Session R4 touches Supabase schema + server routes and should run **after** beta submission.

---

## 0. Mission (BLUF)

Replace the scattered scraper-per-lane radar with **one unified signal engine**:

1. Every data source emits the **same `Signal` object** (one schema, many adapters).
2. A deterministic **scoring engine** fuses signals into a 0–100 RadarScore with a full,
   human-readable breakdown — *before* any LLM is called (cheap filter first, expensive AI second).
3. The AI council receives the **signal ledger** and acts as **researcher, not voter**: it verifies
   evidence, argues bull/bear, and outputs a falsifiable thesis with invalidation conditions.
4. A **backtest harness** measures, per signal class, how stocks historically moved after that
   signal fired — producing the drift curves that power the live **Reprice Gap** metric and the
   honest "historical edge" numbers for the app and marketing.

**What this is:** a catalyst *detection + repricing-lag* system with conditional base rates.
**What this is not:** a crystal ball that "reliably predicts" earnings. No system does that, and
the app must never claim it (compliance + credibility). The defensible claim is:
*"When events like this happened before, here is how similar stocks moved, with sample sizes
and confidence intervals — and here is the full reasoning chain."* That claim is provable,
explainable, and nobody else in the retail space ships it.

---

## 1. Architecture Overview

```
 ┌────────────────────────────  ADAPTERS (one file per source)  ───────────────────────────┐
 │ sec_8k · form4_insider · fmp_earnings · fmp_estimates · usaspending · openfda           │
 │ clinicaltrials · f13_flows · short_interest · analyst_actions · supply_chain_mapper     │
 │ buybacks_dilution · finnhub_news · rss_feeds · social_stub · index_events · spinoffs    │
 └───────────────────────────────────────┬─────────────────────────────────────────────────┘
                                         ▼  all emit List[Signal]
                              ┌──────────────────────┐
                              │  signals/schema.py    │   one dataclass, validated
                              └──────────┬───────────┘
                                         ▼
 ┌─────────────────────────────  ENGINE (pure functions, unit-tested)  ────────────────────┐
 │ score.py      decay → category fusion → confluence multiplier → crowdedness penalty     │
 │ reprice.py    Reprice Gap = expected drift remaining − realized move (from drift curves)│
 │ regime.py     VIX / Fed / macro → FLAGS ONLY (annotate, never filter — house rule)      │
 └───────────────────────────────────────┬─────────────────────────────────────────────────┘
                                         ▼  RadarScore ≥ 75 gate (unchanged)
                              ┌──────────────────────┐
                              │  AI COUNCIL           │  researcher, not voter
                              │  Gemini · DeepSeek ·  │  verifies ledger, bull/bear,
                              │  CIO arbiter          │  falsifiable thesis + invalidation
                              └──────────┬───────────┘
                                         ▼
                    verdict + explanation payload → Supabase → feed / push
 ┌──────────────────────────────  BACKTEST (offline)  ─────────────────────────────────────┐
 │ loader.py (point-in-time prices) → event_study.py → drift_curves.py → report.py         │
 │ outputs: per-signal hit rates, abnormal-return curves, CIs → feeds reprice.py + PDF     │
 └──────────────────────────────────────────────────────────────────────────────────────────┘
```

Directory layout (new code lives under `backend/radar_v2/` so nothing in the beta path breaks):

```
backend/radar_v2/
  signals/
    schema.py            # Signal dataclass + validation
    adapters/
      sec_8k.py          # R1
      form4_insider.py   # R1
      fmp_earnings.py    # R1
      usaspending.py     # R1
      fmp_estimates.py   # R2
      openfda.py         # R2 (port existing scraper to adapter)
      short_interest.py  # R2
      analyst_actions.py # R2
      f13_flows.py       # R2 (port from alpha-scrapers spec)
      buybacks.py        # R2
      finnhub_news.py    # R2
      supply_chain.py    # R2 (wrap existing supply_chain_mapper.py output)
      social_stub.py     # R2 (interface only — see §4.7 cost note)
  engine/
    score.py             # R2
    reprice.py           # R3 (needs drift curves)
    regime.py            # R2 (wrap existing VIX overlay — flags only)
    crowding.py          # R2
  backtest/
    loader.py            # R3
    event_study.py       # R3
    drift_curves.py      # R3
    costs.py             # R3
    report.py            # R3
  tests/
    test_schema.py  test_score.py  test_event_study.py  fixtures/
  run_scan.py            # R4 — orchestrates adapters → engine → council → Supabase
```

---

## 2. The Signal Schema (the whole point)

Every adapter returns `List[Signal]`. Nothing else enters the engine.

```python
# backend/radar_v2/signals/schema.py
from dataclasses import dataclass, field
from datetime import datetime, timezone

# The 8 categories. Confluence only counts ACROSS categories, never within one.
CATEGORIES = [
    "INSIDER_SMART_MONEY",    # Form 4 clusters, 13F adds, activist stakes, buybacks
    "GOVERNMENT_REGULATORY",  # contracts, FDA/FAA/FCC/NRC, grants, export licenses
    "COMMERCIAL_DEALS",       # partnerships, hyperscaler capex flow-through, offtake/supply
    "FUNDAMENTALS_INFLECTION",# revenue accel, first profit, margin turn, surprise, guidance
    "STREET_POSITIONING",     # analyst actions, estimate revisions, coverage init, short interest
    "PRICE_VOLUME_STRUCTURE", # momentum, volume anomaly, valuation gap (P/E, PEG vs sector)
    "NARRATIVE_SENTIMENT",    # headlines, RSS, social  → weight-capped, fast decay
    "CONTEXT_REGIME",         # VIX, Fed, macro         → weight 0.0 — flags only (house rule)
]

@dataclass
class Signal:
    ticker: str
    signal_type: str          # e.g. "insider_cluster_buy", "gov_contract_award"
    category: str             # one of CATEGORIES
    direction: int            # +1 bullish, -1 bearish
    magnitude: float          # 0.0–1.0, normalized WITHIN the signal_type (see adapter docs)
    confidence: float         # 0.0–1.0, source reliability x verification status
    event_time: datetime      # when it became PUBLIC (UTC). Point-in-time. Non-negotiable.
    half_life_days: float     # decay speed — set per signal_type (table in §3)
    source_url: str           # primary source link (filing, award page, article)
    evidence: str             # ONE plain-English sentence a user could read
    raw: dict = field(default_factory=dict)  # original payload for audit

    def validate(self) -> None:
        assert self.category in CATEGORIES, f"bad category {self.category}"
        assert self.direction in (-1, 1)
        assert 0.0 <= self.magnitude <= 1.0
        assert 0.0 <= self.confidence <= 1.0
        assert self.event_time.tzinfo is not None, "event_time must be timezone-aware UTC"
        assert self.half_life_days > 0
        assert len(self.evidence) > 0
```

**Adapter contract (every adapter, no exceptions):**

- `def fetch(tickers: list[str] | None, since: datetime) -> list[Signal]`
- `event_time` = the public timestamp (SEC acceptance datetime, award post date, article time).
  Never the internal event date. An 8-K filed at 17:42 ET is tradeable next session — the
  backtest enforces this with an embargo (§6).
- `magnitude` normalization rule documented in the adapter docstring (e.g. insider cluster:
  `min(1.0, total_buy_usd / 1_000_000) * min(1.0, n_distinct_insiders / 3)`).
- Idempotent: re-running over the same window emits identical signals (dedupe key =
  `ticker + signal_type + source_url`). Same upsert discipline as `supply_chain_mapper.py`.
- Network errors return `[]` and log a warning. One dead source never kills a scan.

---

## 3. Signal Catalog — sources, half-lives, weights

This maps Jaiden's idea list onto the schema, fills the gaps, and fixes one taxonomy bug
(P/E and PEG are **valuation fundamentals**, not technical analysis — they live in
PRICE_VOLUME_STRUCTURE as a *valuation gap vs. sector*, computed not scraped).

| signal_type | Category | Source / API | Cost | half_life | Notes |
|---|---|---|---|---|---|
| `sec_8k_material` | varies by item | SEC EDGAR submissions | free | 10d | Item 1.01 deals→COMMERCIAL, 5.02 mgmt→FUNDAMENTALS, etc. |
| `insider_cluster_buy` | INSIDER | EDGAR Form 4 | free | 30d | ≥2 distinct insiders, open-market, non-10b5-1, 14-day window |
| `insider_sale_unplanned` | INSIDER (bearish) | EDGAR Form 4 | free | 30d | direction = −1; feeds bear annotation |
| `buyback_announce` | INSIDER | 8-K / press | free | 45d | repurchase authorizations |
| `f13_elite_add` | INSIDER | EDGAR 13F | free | 45d | per alpha-scrapers spec; 45-day staleness noted in evidence |
| `activist_stake` | INSIDER | 13D/13G | free | 60d | Elliott/Starboard/etc. = catalyst in itself |
| `gov_contract_award` | GOVERNMENT | USAspending / SAM.gov | free | 21d | magnitude = award $ / market cap |
| `fda_decision` / `fda_designation` | GOVERNMENT | openFDA + ClinicalTrials.gov | free | 14d / 60d | PDUFA calendar = *upcoming* catalyst flag |
| `partnership_deal` | COMMERCIAL | 8-K + Finnhub + Exa | mixed | 21d | hyperscaler/prime flow-through |
| `supply_chain_flow` | COMMERCIAL | supply_chain_mapper.py | built | 30d | existing service, wrapped as adapter |
| `earnings_surprise` | FUNDAMENTALS | FMP | paid | 15d | SUE z-score → magnitude (PEAD is real, see PDF §6) |
| `guidance_change` | FUNDAMENTALS | FMP / 8-K | paid | 20d | raise +1 / cut −1 |
| `revenue_inflection` | FUNDAMENTALS | FMP fundamentals | paid | 60d | accel ≥ 2 quarters, first profit, margin turn |
| `estimate_revision` | STREET | FMP estimates | paid | 20d | revision *momentum* — one of the most robust documented effects |
| `analyst_action` | STREET | FMP / Finnhub | paid | 10d | initiation > upgrade > target bump |
| `coverage_initiation` | STREET | FMP | paid | 30d | esp. 0→1 analyst on underfollowed names |
| `short_interest_shift` | STREET | FINRA (bi-monthly, free) | free | 14d | spike = squeeze setup OR bear signal — direction by context |
| `momentum_12_1` | PRICE_VOL | Polygon aggregates | have | 30d | classic 12-month-minus-last-month |
| `volume_anomaly` | PRICE_VOL | Polygon | have | 5d | 3σ volume on no news = something brewing |
| `valuation_gap` | PRICE_VOL | computed (FMP + Polygon) | have | 90d | P/E, PEG, EV/EBITDA vs sector median z-score |
| `overreaction_reversal` | PRICE_VOL | computed + LLM classify | mixed | 20d | **the "overlooked" idea, formalized — see §3.1** |
| `news_velocity` | NARRATIVE | Finnhub + RSS | have | 3d | capped weight; mostly feeds crowding (§5.3) |
| `social_buzz` | NARRATIVE | Stocktwits/Reddit (X deferred) | cheap | 2d | see §4.7 — X API ≈ $200/mo for weak read access; defer |
| `vix_regime` / `fed_event` / `macro_regime` | CONTEXT | existing VIX overlay + FRED | free | n/a | **weight 0.0 — annotation flags only** |
| `index_inclusion` | STREET | S&P/Russell announcements | free | 10d | effect has shrunk over the years — modest weight, honest |
| `spinoff_separation` | FUNDAMENTALS | 8-K / Form 10 | free | 90d | forced-selling mispricing window |

### 3.1 The "overlooked opportunity" signal, formalized

Jaiden's instinct ("bad short-term news, price mismatch") is a real documented effect
(overreaction → reversal). Make it computable:

```
overreaction_reversal fires when ALL of:
  1. price dropped ≥ 12% within 5 trading days
  2. an LLM classifier labels the triggering news TRANSITORY
     (one-off: guidance timing, single contract slip, sector sympathy, legal noise)
     vs THESIS-BREAKING (fraud, customer loss >25% rev, going-concern, CRL on lead drug)
  3. fundamentals trajectory unchanged (no estimate cuts > 5% in the window)
magnitude = min(1.0, drop_pct / 30%)   confidence = classifier confidence × 0.8 cap
```

The classifier prompt + its output are stored in `raw` so the council (and the user) can audit
*why* the engine thought the news was transitory. If classified THESIS-BREAKING → no signal,
and a bearish annotation is attached instead.

---

## 4. Scoring Engine — `engine/score.py`

Pure functions. No I/O. Beginner-friendly: small functions, plain comments, no clever one-liners.

### 4.1 Per-signal decayed score

```python
import math
from datetime import datetime, timezone

def signal_score(sig, now: datetime) -> float:
    """One signal's contribution, melting over time like an ice cube."""
    age_days = (now - sig.event_time).total_seconds() / 86400
    decay = math.exp(-math.log(2) * age_days / sig.half_life_days)  # halves every half_life
    return sig.direction * sig.magnitude * sig.confidence * decay
```

### 4.2 Category fusion (diminishing returns within a category)

Five insider buys are not 5× one insider buy. Use a saturating sum so the 2nd and 3rd signal
in the same category add less than the 1st:

```python
def category_score(scores: list[float]) -> float:
    """Combine same-category signals with diminishing returns. Output in [-1, 1]."""
    bulls = sorted((s for s in scores if s > 0), reverse=True)
    bears = sorted((abs(s) for s in scores if s < 0), reverse=True)

    def saturate(vals):
        total, weight = 0.0, 1.0
        for v in vals:
            total += v * weight
            weight *= 0.5          # each additional signal counts half as much
        return min(1.0, total)

    return saturate(bulls) - saturate(bears)
```

### 4.3 Category weights (initial — backtest will retune in R3)

```python
WEIGHTS = {
    "INSIDER_SMART_MONEY":     0.22,
    "GOVERNMENT_REGULATORY":   0.18,
    "COMMERCIAL_DEALS":        0.16,
    "FUNDAMENTALS_INFLECTION": 0.18,
    "STREET_POSITIONING":      0.12,
    "PRICE_VOLUME_STRUCTURE":  0.10,
    "NARRATIVE_SENTIMENT":     0.04,   # hard-capped: stories follow signals, not vice versa
    "CONTEXT_REGIME":          0.00,   # HOUSE RULE: flags annotate, never filter or rank
}
```

### 4.4 Confluence multiplier (tripleSignal, generalized)

The edge is *temporal clustering of independent evidence*. Count distinct **non-narrative,
non-context** categories with `category_score ≥ 0.25` inside the live window:

```python
def confluence_multiplier(category_scores: dict) -> float:
    eligible = [c for c, s in category_scores.items()
                if s >= 0.25 and c not in ("NARRATIVE_SENTIMENT", "CONTEXT_REGIME")]
    k = len(eligible)
    return min(2.0, 1.0 + 0.25 * max(0, k - 1))   # 1 cat → 1.0x … 5+ cats → 2.0x
```

`tripleSignal` becomes a *derived* flag: `k >= 3` — same UI badge, now mechanically defined.

### 4.5 Crowdedness penalty — `engine/crowding.py`

Protects the house rule "ignore consensus picks, ignore whatever CNBC is covering":

```
crowding ∈ [0,1] from three z-scores (vs the ticker's own 90-day baseline):
  news article count · social mention count · realized 5-day move vs event-class norm
final = base_score × confluence × (1 − 0.5 × crowding)
```

A great catalyst already up 40% on 8× news volume is *late* — it should score lower than the
same catalyst nobody has noticed. This is the mathematical encoding of the app's name.

### 4.6 Output: the score breakdown object (explainability, part 1)

`score_ticker()` returns not just a number but the full ledger:

```json
{
  "ticker": "KTOS",
  "radar_score": 83,
  "category_scores": {"GOVERNMENT_REGULATORY": 0.71, "INSIDER_SMART_MONEY": 0.44, ...},
  "confluence": {"k": 3, "multiplier": 1.5, "triple_signal": true},
  "crowding": {"value": 0.12, "penalty_applied": 0.94},
  "signals": [
    {"type": "gov_contract_award", "evidence": "$48M Army C-UAS award, 2.1% of market cap",
     "decayed_score": 0.58, "age_days": 3, "source_url": "https://..."}
  ],
  "regime_flags": ["VIX_ELEVATED"],
  "reprice_gap": {"expected_drift_remaining_pct": 6.2, "window_elapsed_pct": 18}
}
```

This object goes to the council, to Supabase, and (rendered) to the user. **Every number on
screen traces to a primary source.** That is the moat.

### 4.7 Cost reality checks (decide before building)

- **X/Twitter API:** basic tier ≈ $200/mo for limited reads. Sentiment alpha is weak and decays
  in hours-days. **Defer.** Ship `social_stub.py` (interface + Stocktwits/Reddit public JSON
  fillers) so the slot exists when it's worth paying for.
- **Daily short borrow data:** expensive. FINRA bi-monthly short interest is free — start there.
- **Council cost:** the deterministic gate runs on *every* candidate; the council runs only on
  gate-passers. Keep the existing Redis content-keyed debate cache and the global daily spend
  circuit-breaker in front of it. Non-negotiable.

---

## 5. AI Council Integration — researcher, not voter (R4)

The council does **not** generate scores. The engine scores; the council *interrogates*.

Council input = the score breakdown object (§4.6) + the radar dossier.
Required output schema (extends current `CouncilVerdict`):

```json
{
  "verdict": "BULL",
  "thesis": "one falsifiable sentence",
  "reasoning_chain": ["fact → inference", "fact → inference", "..."],
  "signals_cited": ["gov_contract_award", "insider_cluster_buy"],
  "signals_challenged": [{"type": "valuation_gap", "objection": "peer set is wrong because ..."}],
  "bear_case": "best honest counter-argument",
  "invalidation_conditions": ["contract protest filed", "Q3 revenue < $X"],
  "what_would_change_my_mind": "specific, checkable",
  "sizing_annotation": "bear case severity → suggested position-size band"
}
```

House rules carried forward:
- **Bear cases are sizing annotations, not ranking inputs.**
- **Regime flags attach to the card; they never filter or rerank.**
- The CIO arbiter may **veto** a gate-passer if a council member finds the evidence is wrong
  (e.g. the "contract" is an IDIQ ceiling, not an award) — vetoes are logged with reasons.
  Veto ≠ vote: it is evidence falsification, the one thing LLMs are allowed to kill a card for.

---

## 6. Backtest Harness (R3) — how "proof" gets generated honestly

**Purpose:** measure, per `signal_type`, the distribution of *abnormal* returns after the signal
became public. Outputs power (a) the live Reprice Gap, (b) weight retuning, (c) the results
appendix of the architecture PDF, (d) the "historical edge" stat behind the Pro Max paywall tease.

### 6.1 Method — event study, plain version

For every historical signal occurrence:
1. **Entry:** open of the first regular session *after* `event_time` (after-hours filing →
   next morning). This embargo is the #1 lookahead-bias killer.
2. **Horizons:** +1, +5, +21, +63, +126 trading days.
3. **Abnormal return** = ticker return − sector-ETF return (XLK/XLI/XBI/... mapped by sector)
   over the same window. Subtracting the sector strips out "the market went up anyway."
4. Aggregate per signal_type: median + mean abnormal return per horizon, hit rate
   (% positive at +63d), and a **bootstrap 95% confidence interval** (resample events 2,000×).
5. **Costs:** subtract a spread haircut by liquidity bucket (`backtest/costs.py`):
   ADV > $10M → 10 bps, $1–10M → 35 bps, < $1M → 75 bps, round trip ×2.

### 6.2 Honesty guards (hard requirements — the report must print all of these)

```
□ Point-in-time assertion: every event_time < entry_time, embargo respected (unit test)
□ Sample size per signal_type printed next to every stat; n < 30 → labeled "INDICATIVE ONLY"
□ Survivorship note: if the Polygon tier lacks delisted tickers, print the warning banner —
  results are optimistic by construction and the report must say so
□ No in-sample weight tuning leakage: tune WEIGHTS on 2019–2023, report on 2024–2026 holdout
□ Multiple-comparisons caution: testing ~25 signal types means ~1 will look great by luck;
  flag any "winner" whose CI includes zero
□ Regime split: report each signal in high-VIX vs low-VIX halves (annotation, per house rule)
```

### 6.3 Drift curves → Reprice Gap (`engine/reprice.py`)

`drift_curves.py` saves, per signal_type, the median abnormal-return *path* (day 0 → 126).
Live scoring then computes:

```
expected_total   = drift_curve[signal_type][horizon=63]
expected_so_far  = drift_curve[signal_type][days_elapsed]
reprice_gap_pct  = expected_total − realized_abnormal_move_since_event
window_elapsed   = days_elapsed / 63
```

High gap + early window + verified evidence + low crowding = the top of the feed. This is the
"before the market reprices" value proposition turned into a number a user can see and audit —
*"events like this historically drifted +9% over 3 months; this one has moved +1% in 6 days."*

### 6.4 Why no backtest numbers ship inside this spec

Real numbers require real market data (Polygon/FMP keys) and delisted-ticker coverage. Claude
Code generates them by running `backtest/report.py` against live APIs. **Never publish a
backtest stat that this harness did not produce and that a human did not audit.** Synthetic or
assumed numbers in user-facing copy are how fintech apps die. Compliance framing everywhere:
educational/informational, hypothetical past performance ≠ future results, not financial advice.

---

## 7. Build Sessions

### Session R1 — Schema + free adapters *(parallel-safe with beta sprint)*
Build: `signals/schema.py`, adapters for `sec_8k`, `form4_insider`, `fmp_earnings`,
`usaspending`, `tests/test_schema.py`, fixtures.
**Acceptance criteria:**
- [ ] `pytest backend/radar_v2/tests/ -q` green
- [ ] Each adapter run twice over the same window → identical signal sets (idempotency)
- [ ] `python -m radar_v2.signals.adapters.sec_8k --tickers KTOS RKLB --days 30 --json`
      prints valid `Signal` JSON with timezone-aware `event_time`
- [ ] Every emitted signal passes `validate()`; every `evidence` string reads as one sentence
- [ ] Zero modifications outside `backend/radar_v2/` (verify with `git diff --stat`)

### Session R2 — Scoring engine + remaining adapters
Build: `engine/score.py`, `engine/crowding.py`, `engine/regime.py` (wrap VIX overlay, flags
only), adapters: `fmp_estimates`, `openfda`, `short_interest`, `analyst_actions`, `f13_flows`,
`buybacks`, `finnhub_news`, `supply_chain` (wrap existing mapper), `social_stub`.
**Acceptance criteria:**
- [ ] `test_score.py`: decay halves at exactly `half_life_days`; category saturation
      (2nd same-category signal adds ≤ 50% of 1st); confluence k=1→1.0x, k=3→1.5x, k=6→2.0x
- [ ] CONTEXT_REGIME signals provably cannot change `radar_score` (dedicated unit test)
- [ ] NARRATIVE weight cap test: a ticker with *only* narrative signals cannot pass the 75 gate
- [ ] Score breakdown JSON matches §4.6 schema; golden-file test with fixture signals

### Session R3 — Backtest harness + drift curves
Build: `backtest/loader.py` (Polygon, splits-adjusted, sector-ETF benchmark map),
`event_study.py`, `drift_curves.py`, `costs.py`, `report.py`, `engine/reprice.py`.
**Acceptance criteria:**
- [ ] Synthetic fixture test: planted +10% drift events recover ≈ +10% (±0.5%) — proves the
      math before real data touches it
- [ ] Lookahead unit test: an event timestamped after entry raises `LookaheadError`
- [ ] `python -m radar_v2.backtest.report --since 2019-01-01 --holdout 2024-01-01` produces
      `backtest_report.md` + PNG drift curves with every §6.2 honesty-guard line printed
- [ ] `drift_curves.json` written; `reprice.py` consumes it and returns the §4.6 reprice block

### Session R4 — Council explainability + pipeline integration *(post-beta-submission)*
Build: `run_scan.py`, council prompt update to §5 schema, Supabase migration
(`radar_opportunities` + `score_breakdown jsonb`, `reprice_gap jsonb`, `council_explanation
jsonb`, `regime_flags text[]`), server route wiring, Redis cache keys unchanged.
**Acceptance criteria:**
- [ ] `python -m radar_v2.run_scan --tickers KTOS --dry-run` prints: signals → breakdown →
      gate decision → (if passed) council payload, end to end
- [ ] Council JSON parse failure → safe fallback row, never a crash (test with garbage reply)
- [ ] CIO veto path logs reason and sets `vetoed=true` (test with planted false evidence)
- [ ] Existing iOS feed renders rows that *lack* the new jsonb fields (backward compat) —
      `xcodebuild ... build` green, no Swift changes required for old rows

---

## 8. Out of Scope (scope discipline — protect July 1)

- ❌ X/Twitter paid API (stub only)
- ❌ Options flow / unusual-activity data (expensive; Phase 2 candidate)
- ❌ Any iOS UI work for breakdown rendering (post-beta polish)
- ❌ Retuning the 75 gate before the R3 holdout report exists
- ❌ Replacing the existing 8-lane radar agent before R4 ships and runs in shadow mode for
      ≥ 2 weeks alongside it (compare outputs in a journal — military AAR style — then cut over)
