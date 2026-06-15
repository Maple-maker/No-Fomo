# No Fomo — Fix the Pro-Data RLS Leak

**Status:** PLANNED, awaiting go-ahead · **Branch:** `fix/detail-sheet-ux` (local-only)
**Decided 2026-06-14:** chosen over the full StoreKit paywall and evidence-links Phase 1 as the only *live* security/revenue hole.

## The leak (corrected from the ship-audit)
- Audit blamed `opportunity_feed` — wrong table. It's empty (0 rows) and already gated (`is_premium=false OR authenticated`).
- **Real leak:** the app reads **`radar_opportunities`** with `select=*` (SupabaseService:27,54). Its RLS policy is `Allow public read access = true`, so the **anon key** (embedded in the app binary) mass-downloads every column incl. the full `data_snapshot` JSONB.
- **Paid field today = Buy Zones only.** That's the sole thing the UI gates (LockBadge/blur in `OpportunityCard.buyZonesFooter`/`BuyZoneCards` and `DetailSheet:910-911`). Everything else (bull/bear/red flags/rationales) is already shown free. The "full report" (`data_snapshot.full_report_md`, top-level `report_html/md/url`) is Pro and never shown to free.
- Entitlement is real Supabase Auth (`auth.role()='authenticated'` works for logged-in JWTs) but **tier is not enforced server-side** (login hardcodes `.free`, no StoreKit). So this closes the *anonymous* leak; *revenue* enforcement (logged-in-but-unpaid) is the later paywall job.

## DECISION (default chosen; say the word to widen)
Redaction boundary for the anon/free projection:
- **[DEFAULT] Buy zones + full report** — strip `data_snapshot -> 'buy_zones'` and `'full_report_md'`; null `report_html/md/url`. Zero visual regression (already locked/absent for free).
- [WIDER] Whole brief Pro — also strip bull_case/bear_case/red_flags/rationales; free gets teaser only. Bigger UX change (needs lock UI on those sections) -> edges into paywall work.

## Plan (safe sequence — never blanks the live feed)

### 1. DB — additive, non-breaking (Supabase MCP)
- [ ] Create view `radar_feed_public` = `radar_opportunities` with `data_snapshot - 'buy_zones' - 'full_report_md'` and `report_html/md/url` nulled. `GRANT SELECT TO anon, authenticated`.
- [ ] Verify (curl + anon key): view returns rows **without** `buy_zones`; base table still readable (not locked yet).

### 2. iOS client (Swift)
- [ ] `SupabaseService.fetchFeed` / `fetchOpportunity`: if real Supabase JWT held -> GET `radar_opportunities` w/ bearer (`addCommonHeaders`); else GET `radar_feed_public` w/ anon (`addPublicHeaders`). Add `isRealAuthSession` helper.
- [ ] Buy-zone lock guard: locked when `!isPro` **OR** buy zones are all-zero/absent — prevents broken `$0.00` unblur on the free path. (`BuyZoneCards` call sites: card + DetailSheet.)
- [ ] `xcodebuild` compile-check green.

### 3. Jaiden verifies rebuilt app
- [ ] Feed loads via the view (anon/dev session) — buy zones show locked, no `$0` flash.
- [ ] Signed-in real account -> buy zones present. (Note: dev `forceDevSession`/anon will NOT show buy zones by design now.)

### 4. DB — the lock (breaking; do LAST, after step 3 confirms)
- [ ] Replace `radar_opportunities` SELECT policy -> `USING (auth.role() = 'authenticated')`; `REVOKE SELECT ... FROM anon`.
- [ ] Verify leak closed (curl + anon key): `radar_opportunities?select=*` -> `[]`; `radar_feed_public` -> rows, no buy zones. `get_advisors(security)` clean.

## Out of scope (later / paywall fork)
- StoreKit purchase + server entitlements table (authenticated->*paid*), quota RPC, aps-environment/teamID.
- Unlock CTA routing to a real paywall (currently a local `isPro` toggle).

## Review (2026-06-15)

**RLS leak — step 1 DONE, step 4 STAGED (not applied):**
- View `radar_feed_public` created in Supabase (`SELECT *`, no field stripping — everything is free this beta) and `GRANT SELECT TO anon, authenticated`. Verified via curl + anon key (returns rows: CRVO, OKLO). Works via Postgres SECURITY DEFINER view semantics — anon reads the view even after the base table is locked.
- iOS `SupabaseService` now reads `radar_feed_public` for both `fetchFeed` and `fetchOpportunity` (all reads, regardless of auth — simpler than the anon/JWT split since nothing is Pro).
- The breaking lock (revoke anon SELECT on `radar_opportunities`) is written to `/supabase_rls_lock.sql` but **NOT applied**. Apply it only AFTER Jaiden ⌘R-confirms the rebuilt app reads fine — applying before the new build ships breaks the live anon app.

**Bonus security findings (get_advisors) — follow-ups, not done:** `push_tokens` is anon-writable (`USING(true)`); `notify_ntfy` RPC is anon-callable; `pg_net` in public schema; `reports` bucket public-listable. Post-beta hardening.

**This was step 1 of a larger 7-package session** (valuation engine, Wall-Street AI analyst, push notifications, screener+backtest, UI/UX polish). See `~/.claude/plans/concurrent-mixing-marble.md` for the full plan and the session memory for outcomes.
