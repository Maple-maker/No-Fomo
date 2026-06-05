# NoFomo — Master Handoff for Hermes AI

> **Repo:** `https://github.com/Maple-maker/No-Fomo`
> **Local path:** `/Users/jaidenrabatin/NoFomo`
> **Date:** 2026-06-05
> **Target:** App Store submission by end of June 2026

---

## 0. What NoFomo Is (One Sentence)

> NoFomo scans the market for catalysts, runs a multi-AI debate to a reasoned bull/bear conclusion, and matches it to your risk profile — so retail investors get hedge-fund-style catalyst research without the terminal.

---

## 1. What's Built So Far

### iOS App (SwiftUI, iOS 17+)

| File | Status | Purpose |
|---|---|---|
| `NoFomoApp.swift` | ✅ | App entry — auth gate → `MainTabView` / `OnboardingView`. Dark mode forced globally. |
| `Models/Opportunity.swift` | ✅ | 30+ field Codable model with mock data (5 companies). Maps to `radar_opportunities` Supabase table via `CodingKeys`. Custom `init(from:)` with `decodeIfPresent` fallbacks for every field. |
| `Models/User.swift` | ✅ | `AppUser` + `SubscriptionTier` enum (free/pro/annual) with quota logic. |
| `Services/AuthService.swift` | ✅ | `@MainActor` singleton. Apple + email/password auth. Stores token to `UserDefaults`. |
| `Services/SupabaseService.swift` | ✅ | REST client against Supabase project `lmgphebvungyqsnqitcg`. Handles feed fetch, watchlist CRUD, push token registration, seed, and auth headers. |
| `ViewModels/FeedViewModel.swift` | ✅ | Feed state management. |
| `Views/MainTabView.swift` | ✅ | Feed / Watchlist / Settings tabs. |
| `Views/Feed/FeedView.swift` | ✅ | Scrollable opportunity feed. |
| `Views/Feed/OpportunityCard.swift` | ✅ | Card UI per opportunity. |
| `Views/Detail/OpportunityDetailView.swift` | ✅ | Full detail sheet with bull/bear, council verdicts, buy zones, red flags. |
| `Views/Detail/CouncilDebateView.swift` | ✅ | Multi-model verdict display. |
| `Views/Detail/BuyZoneView.swift` | ✅ | Aggressive/base/conservative buy zones. |
| `Views/Detail/FinancialsView.swift` | ✅ | Financial metrics table. |
| `Views/Detail/SourceView.swift` | ✅ | Source citations. |
| `Views/Watchlist/WatchlistView.swift` | ✅ | User watchlist. |
| `Views/Settings/SettingsView.swift` | ✅ | App settings. |
| `Views/Onboarding/OnboardingView.swift` | ✅ | First-run onboarding flow. |
| `Components/DesignSystem.swift` | ✅ | Colors, typography, spacing, radius. `Verdict` and tier helpers. Dark-only palette. |
| `Components/ScoreGauge.swift` | ✅ | Visual score gauge. |

### Design System

```
Background:   #0A0A0F (deep void black)
Card:         #12121A (subtle lift)
Elevated:     #1A1A26 (hover/active)
Bull:         #00FF88 (electric mint)
Bear:         #FF3B5C (clean red)
Tier 1:       #FFD700 (gold)
Tier 2:       #00BFFF (electric blue)
Accent/AI:    #7B61FF (purple)
Text Primary: #FFFFFF
Text Second:  #8888AA
Text Muted:   #565676
Border:       white @ 0.06 opacity
Border Strong:white @ 0.14 opacity

Typography:
  - Financial figures: SF Mono, semibold (DS.Font.mono)
  - Headlines: SF Pro, bold/medium (DS.Font.displayBold/Medium)
  - Body: SF Pro, regular, 15pt (DS.Font.body)

Corners: cards 18pt, small items 8pt, pills 99pt
Spacing: cards 17pt inner, compact 14pt, screen 20pt
```

### Backend (Supabase)

| Table | Purpose |
|---|---|
| `radar_opportunities` | Main feed. Columns: `id`, `ticker`, `tier`, `overall_score`, `thesis`, `gemini_analysis`, `data_snapshot` (JSONB with nested council, buy_zones, financials, red_flags) |
| `user_watchlist` | Per-user watchlist: `user_id`, `opportunity_id`, `ticker` |
| `push_tokens` | APNs token storage: `user_id`, `apns_token` |

**Supabase project ref:** `lmgphebvungyqsnqitcg`
**Anon key:** In `Services/SupabaseService.swift` (safe — anon tier only)

### Agent Architecture (Hermes + 6 sub-agents)

| Agent | File | Role |
|---|---|---|
| **Hermes** | `.opencode/agent/hermes.md` | Orchestrator — dispatches, sequences, synthesizes. Does NOT write code directly. |
| `ios-shipper` | `.opencode/agent/ios-shipper.md` | iOS build, StoreKit 2, TestFlight, push, signing, App Store Connect. |
| `deep-research` | `.opencode/agent/deep-research.md` | Single-ticker catalyst engine — news, filings, partnerships, regulation. Produces evidence dossier. |
| `market-brief` | `.opencode/agent/market-brief.md` | Daily macro context — indices, rates, VIX, sector rotation. |
| `sector-scanner` | `.opencode/agent/sector-scanner.md` | Capex deployment screen — finds sectors and category captains. |
| `whale-tracker` | `.opencode/agent/whale-tracker.md` | Smart-money footprint — 13F shifts, Form 4 insider clusters, options flow. |
| `risk-audit` | `.opencode/agent/risk-audit.md` | Downside engine — leverage, dilution, lockups, customer concentration. |

**OpenCode config:** `opencode.json` — default agent = `hermes`. MCPs configured for Supabase, Brave Search, Polygon, SEC EDGAR, Playwright, Context7, GitHub.

### Product Tiers

| Tier | Price | Tickers/24h | Delivery | Council | Watchlist | Push |
|---|---|---|---|---|---|---|
| Free | $0 | 1 | 4h delayed | teaser only | 3 tickers | off |
| Pro | $9.99/mo | unlimited | real-time | full bull/bear | unlimited | on |
| Annual | $79.99/yr | unlimited | real-time | full bull/bear | unlimited | on |

StoreKit 2 product IDs: `nofomo.pro.monthly`, `nofomo.pro.annual`

### Mock Data (5 companies in-app)

1. **CRVO** (Tier 1) — Corvus Therapeutics, FDA accelerated approval, insider cluster buy
2. **MRDN** (Tier 1) — Meridian Energy, DOE loan guarantee, C-suite insider buying
3. **HDRN** (Tier 2) — Hadrian Defense Systems, $890M IDIQ Army counter-UAS
4. **AETH** (Tier 2) — Aether Compute, hyperscaler custom silicon qualification, Gem/CIO bull, DeepSeek bear
5. **SOLS** (Tier 2) — Solstice Materials, binding EV battery offtake, resource upgrade

---

## 2. Dev Roadmap (Priority Order)

### BLOCKERS (this week)

1. **StoreKit 2 paywall** — wired into the detail sheet, gating the multi-model debate, real-time delivery, full watchlist, and push. `ios-shipper` owns this.
2. **Server-side quota enforcement** — Supabase RPC `consume_ticker_quota(user_id)` + RLS on `radar_opportunities_detail`. Free tier = 1 ticker/24h enforced server-side.
3. **Sign in with Apple** — Supabase `auth/v1/token?grant_type=id_token` flow. Also Google OAuth (required by Apple if Google sign-in is offered).
4. **Build clean for archive** — no warnings, all entitlements correct, ready for TestFlight.

### FEATURES (before App Store)

5. **Real stock prices** — API integration (Twelve Data free tier → FMP/Finnhub paid). Pull price + RSI/MACD per ticker.
6. **SEC EDGAR scanner** — `efts.sec.gov` full-text search for catalyst keywords in 8-Ks. Free, no API key.
7. **AI council backend** — Gemini + DeepSeek + CIO arbiter debate engine. Runs as Supabase edge function or scheduled job. Persists verdicts to `radar_opportunities`.
8. **Push notifications** — APNs via `SupabaseService.registerPushToken`, triggered by council verdicts.
9. **Redis caching** — cache stock prices (30-60s TTL), AI debates (per ticker+day), SEC lookups (permanent). Cache-aside pattern.
10. **Per-user rate limiting** — token-bucket in Redis, tier-based quotas, global budget circuit-breaker.
11. **RLS on Supabase** — users only see their own watchlists, usage, and alerts.

### POLISH (pre-submission)

12. SwiftLint wired
13. `NoFomoTests` target
14. Error tracking (Sentry or similar)
15. Load testing (k6)

---

## 3. Marketing & Content Engine

### Value Proposition
> NoFomo scans the market for catalysts, runs a multi-AI debate to a reasoned bull/bear conclusion, and matches it to your risk profile — so retail investors get hedge-fund-style catalyst research without the terminal.

**The pain:** missing the move (the name IS the pain point).
**The differentiator:** multi-LLM debate → defensible conclusion, not just another data dashboard.

### Content Format
Faceless slideshow Reels/TikToks → email list → waitlist conversion.

**Repeatable series:**
- "Catalyst of the day" — one stock, the filing, the AI's bull/bear take
- "3 SEC filings that dropped today you'd have missed"
- "We made 4 AIs debate $TICKER. Here's the verdict."

**Hook formula:** tension + specificity + curiosity gap
Example: *"This 8-K dropped at 4:01pm and nobody noticed."*

**Funnel:** every post → "free weekly catalyst report, link in bio" → email capture (waitlist).

### Monetization

**Desire-paywall moments** (gate AFTER the user feels the value):
- Blurred verdict — "4 AIs reached a verdict: strong signal" — lock conclusion
- Catalyst count — "3 new catalysts on your watchlist" — names hidden
- Lag reveal — "Pro Max users were alerted 14 min ago"
- Watchlist cap — upgrade prompt at limit
- Backtest tease — lock historical-edge stat

**Paywall microcopy is ready** in the gameplan doc (see `nofomo_gameplan_today.md` §8).

**Upsells:** à la carte credits, usage-triggered nudges, Founders/Insider badge, annual @ 2 months off.

**Compliance:** frame everything as educational/informational. "Not financial advice" disclaimer everywhere. Never manufacture fake urgency.

---

## 4. Today's Gameplan (2026-06-05)

From `nofomo_gameplan_today.md`. Realistic scope for one day:

### 0. UNBLOCK (5 min) ✅ DONE
- [x] Repo URL: `https://github.com/Maple-maker/No-Fomo`
- [x] One-sentence description delivered

### 1. Orchestrator + Sub-agents
- [x] Agent definitions exist in `.opencode/agent/`
- [x] `opencode.json` configured with default agent `hermes`
- [ ] Install OpenCode terminal harness
- [ ] Get OpenRouter key (one key for Opus + DeepSeek + Hermes + Kimi)
- [ ] Route table: planner→Opus, coding→DeepSeek V4, cheap→DeepSeek Flash, escalation→Opus
- [ ] Prove the pipeline: run ONE real task through plan→code→review→merge

### 2. Stock Price Spike
- [ ] Get Twelve Data or Alpha Vantage API key
- [ ] Pull one ticker's price + RSI/MACD, print it
- [ ] Wrap in caching

### 3. SEC Scanner Spike
- [ ] Search recent 8-Ks via `efts.sec.gov` for catalyst keyword
- [ ] Return company + filing date

### 4. Content Engine (plan only today)
- [ ] Pick the ONE series to start
- [ ] Set up email capture waitlist page

### 5. Value Prop + Pricing (draft done ✅)
- [x] Value prop drafted
- [x] Pricing tiers drafted
- [x] Paywall microcopy ready

---

## 5. Conventions (Non-Negotiable)

- **iOS 17+, SwiftUI, dark only.** `.preferredColorScheme(.dark)` is set globally. No light-mode assets.
- **Extend, don't fork.** `Models/Opportunity.swift` is the single source of truth. Add fields via `decodeIfPresent` defaults.
- **Codable pattern:** every model gets custom `init(from:)` with `decodeIfPresent` fallbacks. `CodingKeys` bridges camelCase ↔ snake_case.
- **Singletons:** `@MainActor final class … { static let shared }`.
- **Async:** every network call is `async throws`. Errors map to `AppError`.
- **Financial figures use monospaced font** (`DS.Font.mono`).
- **No comments** in code unless explicitly asked.
- **Secrets:** anon key is fine in-source. Service-role keys, API keys, RevenueCat keys → env vars / `.xcconfig`.
- **No `git commit` or `git push`** without explicit user approval.
- **Server-side quotas only.** Client-side checks are belt-and-suspenders, never the only check.

---

## 6. Verification Commands

```bash
# iOS build
xcodebuild -scheme NoFomo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Lint (not yet wired)
# swiftlint

# Tests (not yet wired)
# xcodebuild -scheme NoFomo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test
```

---

## 7. Guardrails for "Autopilot"

- Human approves every merge to `main` (branch-per-task, PR review).
- Secrets live in env vars / vault — **never** pasted into an agent's context.
- Agents run against dev branch + test DB, never prod.
- "Stuck twice → escalate to Opus, don't keep flailing."
- Rate limiting and budget circuit-breakers protect API spend.
