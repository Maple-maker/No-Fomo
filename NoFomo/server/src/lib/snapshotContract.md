# data_snapshot Field Contract — Valuation + Wall-Street Analysis

**Frozen 2026-06-15 (Phase 0).** Backend (WP-D) populates; iOS (WP-E) decodes. Do not change the shape without updating both sides.

The TypeScript source of truth is `ValuationSnapshot` + `WallStreetSnapshot` in `server/src/lib/opportunity.ts` (top of file). They are written into `data_snapshot` via the `enrichment.valuation` / `enrichment.wallStreet` passthrough already wired in `buildRadarRow`.

## Keys added to `data_snapshot`

```jsonc
{
  "valuation": {
    "dcf": {                          // null when FCF<=0 or fundamentals missing
      "intrinsic": 42.10,             // intrinsic per-share (runDCF intrinsicPerShare)
      "upsidePct": 31.5,              // (intrinsic/price - 1) * 100
      "verdict": "undervalued",       // 'undervalued' | 'fairly_valued' | 'overvalued'
      "buyBelow": 31.58,              // intrinsic * (1 - marginOfSafety)
      "bear": 28.0, "base": 42.1, "bull": 58.4,   // scenario per-share (growth -/0/+ 10pts)
      "growthUsed": 0.08
    },
    "relative": {
      "vs_peers":  { "percentile": 22, "verdict": "cheap_growth" },     // from peers.ts (exists)
      "vs_sector": { "percentile": 35, "medianPs": 6.1, "medianEvEbitda": 18.0 },  // NEW (WP-D)
      "vs_market": { "percentile": 48, "medianPe": 23.5 }               // NEW (WP-D)
    },
    "composite_verdict": "undervalued" // 'undervalued' | 'fair' | 'overvalued'
  },

  "wall_street": {
    "moat_score": 8,                  // 1-10
    "upside_score": 7,
    "market_condition_score": 6,
    "comp_adv_score": 8,
    "moat_rationale": "Sole-source DoD contracts + proprietary data flywheel rivals can't replicate in 3-5y.",
    "upside_rationale": "...",
    "market_condition_rationale": "...",
    "comp_adv_rationale": "...",
    "thesis": "One-paragraph Wall-Street synthesis grounded in the valuation numbers."
  }
}
```

## Already-persisted keys iOS must ALSO surface (no new backend write needed)
- `peer_comparison: PeerCompany[]` — head-to-head table (target first). Currently has **no iOS UI**.
- `peer_percentile_rank: number`, `peer_verdict: string`.

## Rules
- **Null-safe, never fabricated.** Thin data → `null`/omitted, not a fake 5 or $0. Mirror the existing `?? 0` / `?? null` discipline and the rationale-gate philosophy already in the repo.
- **Independence.** The Wall-Street analyst reads the same dossier as the CIO, not the CIO's output (no anchoring).
- **No new model cost.** Route the analyst through `callClaude` → inherits `CIO_MODEL=openrouter/owl-alpha`. Anthropic stays untouched.
- **iOS mirror:** add matching optional Swift props + `CodingKeys` (snake_case: `valuation`, `wall_street`, `peer_comparison`, `peer_percentile_rank`, `peer_verdict`) to `NoFomo/Models/Opportunity.swift`; decode in `RadarRow.Snapshot` + `toOpportunity()`.
