# No Fomo — Detail Sheet Backlog (notes for tomorrow)

**Captured:** 2026-06-14 · **Branch:** `fix/detail-sheet-ux` · **Source:** Jaiden end-of-day notes
**Also parked:** RLS leak fix is planned + awaiting go-ahead in `tasks/todo.md` (do not lose).
All items live in `NoFomo/Views/Detail/DetailSheet.swift` unless noted. Code root: `.../No-Fomo/NoFomo`.

> ⚠️ Shared dependency: items 1, 2, 5 are only as good as the data the server writes. The council
> currently runs on `owl-alpha` (Anthropic at $0 per last snapshot) and several enrichment fields
> ship empty. Fixing the UI without populating the data just renders prettier blanks. Check
> `server/src/lib/opportunity.ts` (writer) + the enrichment pipeline first for each data item.

---

## 1. Key Metrics — flesh out
- **Where:** `keyMetricsSection` (DetailSheet:1299) ← `opportunity.keyMetrics`; written `server/src/lib/opportunity.ts:284-292`.
- **Now:** only 7 fields, several default to `''` — pe_trailing, pe_forward, ev_ebitda, gross_margin, operating_margin, dividend_yield, beta. `backend/stock_data.py` already returns more (ps_ttm, pfcf, rev_growth_yoy, short_pct) that never reach `key_metrics`.
- **Done:** add the missing metrics (P/S, P/FCF, YoY rev growth, short %), wire them from enrichment so they populate, and hide rows that are genuinely empty (no blank labels).

## 2. Analyst Consensus — improve  *(needs your spec)*
- **Where:** `analystSection` (DetailSheet:633, "Analyst Consensus") ← analyst_consensus / analyst_count / avg_price_target / high / low / recent_analyst_actions.
- **Now:** consensus label + count + recent actions list + an "AI vs Analysts" contrast.
- **Open Q for you:** what does "improved" mean — more accurate data, or richer display? Candidate: a price-target **range bar** (low/avg/high vs current price) + rating distribution. **Leave a one-line note tomorrow on which.**

## 3. Chart — trend lines + technical signals on the graph
- **Where:** `priceChartSection` (DetailSheet:229-405) — today just a sparkline + horizon selector. Indicators live as *text* in "Trading Indicators" (:586).
- **Data available:** rsi_value, rsi_signal, macd_trend, support_level, resistance_level, volume_vs_avg (all in data_snapshot).
- **Done:** overlay on the chart — support/resistance horizontal lines, a trend line (SMA or linear-fit), and signal markers (RSI overbought/oversold, MACD cross). Move the signal from text-only onto the graph.

## 4. Competitive Landscape duplicates the Bull Case — ROOT-CAUSED
- **Where:** `competitiveAdvantagesSection` (DetailSheet:1205).
- **Cause:** when `competitiveAdvantages` (moat) is empty — which is the norm, server writes `competitive_advantages: ... || ''` (opportunity.ts:282) — it **falls back to the first 3 sentences of `bullCase`** (`edgeFromBull`, :1209-1220). That's the duplication.
- **Done:** feed it real moat/peer content instead of recycling the bull case. The **peer-comparison scaffolding already exists server-side** (`server/src/lib/peers.ts` → persisted to `data_snapshot.peer_comparison`, no iOS UI yet). Wire that in as the Competitive Landscape, and drop the bull-case fallback.

## 5. AI Debate section "missing" — actually ORPHANED, easy fix
- **Cause:** the redesigned debate UI **exists** — `councilSection` (DetailSheet:849, per-model panels: Gemini/DeepSeek/CIO verdict + reasoning) — but the body (:84-104) wires the *older* `councilSummarySection` (:98) instead. `councilSection` is never referenced → never renders.
- **Done:** wire `councilSection` into the body (replace or sit alongside `councilSummarySection`; likely retire the summary one). Then verify `geminiReasoning / deepseekReasoning / cioReasoning` actually populate (council reasoning persistence — confirm it flows from `server/src/routes/council.ts`). If reasoning is empty, that's a data fix, not a UI fix.

---

## Suggested order tomorrow
1. **#5 (debate)** — likely a 1-line wire-in; highest visible payoff for least effort. Verify reasoning data first.
2. **#4 (competitive)** — wire existing peer_comparison; kills the duplication.
3. **#1 (key metrics)** — data + UI, mechanical.
4. **#3 (chart overlays)** — most net-new iOS charting work.
5. **#2 (analyst)** — blocked on your spec note above.
