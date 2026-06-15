# Evidence Links — Spec

**Principle (Jaiden, 2026-06-14):** "When you say signal — you need to have a link."
Every displayed signal must cite a verifiable source the user can tap. A claim with
no source is an assertion, not a signal.

## Current state (verified against live data + code)

The source URLs already exist upstream — they're collected, then thrown away at
persist time (the same "computed-but-not-persisted" bug class as the confidence
columns and peer metrics):

- `radar.ts:464-473` builds `allSources` (web + quiver/SEC/SAM.gov + headlines,
  deduped by URL) — but it runs **after** the row is inserted (`:439`) and is only
  returned in the HTTP response. It is **never written to `data_snapshot`**.
- `data_snapshot.sources` is empty on all 17 rows. iOS (`RadarRow.Snapshot.sources`)
  already decodes a `sources` field — the server just never sends it.
- Per-signal source text is empty too: `smart_money_signal` / `government_signal`
  are `''` on every row.

Upstream URL availability (confirmed):
- **Insider / Smart Money** → SEC EDGAR Form 4/3/5 (`tools/insider.ts`) — filing URLs.
- **Government** → SAM.gov `uiLink` (`tools/sam.ts`) — opportunity URLs.
- **Catalyst / news** → headlines carry `url` (`radar.ts:331`, `enrich.ts:206`).
- **Thesis research** → `allSourceUrls` / `webSources` (`radar.ts:186, 465`).

Secondary blocker: scans must actually capture data. Brave `count=50→422` is fixed;
Yahoo 429 and the remaining Brave 422 (likely the `site:` query operators in
shortReports/transcript) still thin the evidence and need a look.

## Signal → source mapping

| Signal | Source | Confidence |
|---|---|---|
| Smart Money | SEC Form 4 filing URL(s) | deterministic |
| Gov | SAM.gov `uiLink` contract URL(s) | deterministic |
| Catalyst | the catalyst's headline/filing URL | deterministic |
| Asymmetry / Conviction / Mgmt | top dossier sources (thesis-level list) | best-effort |

Per-claim attribution for the 3 LLM dimensions is unreliable — link them to the
thesis-level Sources list rather than faking a per-line citation.

## Plan

### Phase 1 — deterministic links (no LLM citation)
**Server**
1. Move the `allSources` build above `buildRadarRow`; add `sources: allSources`
   to `data_snapshot` (type + write in `opportunity.ts`). One move + one field.
2. Persist per-signal source arrays in `data_snapshot`:
   - `smart_money_sources: {label,url}[]` ← insider Form 4 filing URLs
   - `government_sources: {label,url}[]` ← SAM.gov `uiLink`s
   - `catalyst_source: {label,url}` ← the chosen catalyst's headline URL
3. Populate the empty `smart_money_signal` / `government_signal` text while here
   (one-line human summary alongside the score).

**iOS**
4. Decode the new fields in `RadarRow.Snapshot` + `Opportunity` (mirror the
   rationale plumbing already added).
5. In `DetailSheet` scorecard inline panel: render a tappable **"Source ›"** row
   per signal when a URL exists (opens `SFSafariViewController`).
6. Restore/!ensure a thesis-level **Sources** list (the `sourcesSection` exists but
   renders nothing because `sources` was never sent).

### Phase 2 — council citations (optional, later)
7. Feed the dossier to the CIO as a numbered source list; have each dimension
   rationale return the source index it leans on; persist `*_source_idx`.
   Gate on reliability — only show when the index resolves to a real URL.

## Files
- `server/src/routes/radar.ts` — move allSources up; route per-signal URLs
- `server/src/lib/opportunity.ts` — `data_snapshot` type + writes
- `server/src/tools/insider.ts`, `tools/sam.ts` — expose filing/opportunity URLs if not already returned
- `NoFomo/Models/Opportunity.swift`, `Services/SupabaseService.swift` — decode
- `NoFomo/Views/Detail/DetailSheet.swift` — link rows + Sources list

## Verify
- Re-scan one ticker with insider activity (e.g. KTOS/PLTR) → confirm
  `data_snapshot.sources` + `smart_money_sources` populated with real URLs.
- iOS: tap a signal → "Source ›" opens the SEC/SAM.gov/news page.

## Risk / honesty
- A signal with no available source must show **no** link (never a fabricated one)
  and ideally not claim to be a signal — same discipline as the rationale-gate.
- Don't ship Phase 2 LLM citations until index→URL resolution is verified, or it
  reintroduces "false results."
