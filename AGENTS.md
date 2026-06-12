# NoFomo — Repo Context

> Loaded into every opencode session. Keep terse. Source of truth for stack, mission, and conventions.

## Mission

Ship NoFomo to the iOS App Store **by end of June 2026**. NoFomo surfaces high-conviction equity opportunities the market has not yet repriced, using a multi-model AI council (Gemini + DeepSeek + arbiter CIO) that debates each thesis.

## Product surface

- **Free tier**: 1 ticker per 24h, delayed by 4h, redacted financials.
- **Pro — $9.99/mo**: unlimited tickers, real-time delivery, full multi-model bear/bull debate, watchlist, push alerts.
- **Annual — $79.99/yr**: Pro features, annual billing (already wired in `Models/User.swift`; confirm with stakeholder if a third differentiated tier was intended).

Quota enforcement is **server-side** (Supabase RPC + RLS), never client-only.

## Stack

| Layer       | Tech                                                              |
| ----------- | ----------------------------------------------------------------- |
| App         | SwiftUI, iOS 17+, `@MainActor` services, dark-only color scheme   |
| Auth        | Sign in with Apple → Supabase `auth/v1/token?grant_type=id_token` |
| Backend     | Supabase project `lmgphebvungyqsnqitcg` (`radar_opportunities`, `user_watchlist`, `push_tokens`) |
| Payments    | StoreKit 2 (planned) — wrap behind RevenueCat if cross-platform later |
| Push        | APNs token registered via `SupabaseService.registerPushToken`     |
| AI council  | Gemini, DeepSeek, arbiter CIO model — verdicts persisted as `Verdict` enum |
| Research    | Python 3.11+, `backend/stock_data.py` (prices + TA), `backend/sec_scanner.py` (SEC catalyst scan) |

## File map

```
NoFomoApp.swift              app entry — auth gate → MainTabView / OnboardingView
Models/
  Opportunity.swift          core data model + Supabase Codable mapping + mocks
  User.swift                 AppUser + SubscriptionTier enum
Services/
  AuthService.swift          @MainActor singleton, Apple + email/password
  SupabaseService.swift      REST client (radar_opportunities, watchlist, push, seed)
ViewModels/FeedViewModel.swift
Views/
  MainTabView.swift          Feed / Watchlist / Settings tabs
  Feed/FeedView.swift
  Detail/DetailSheet.swift   bull/bear, council verdicts, buy zones, red flags
  Watchlist/WatchlistView.swift
  Settings/SettingsView.swift
  Onboarding/OnboardingView.swift
Components/
  DesignSystem.swift         colors, typography, spacing
  OpportunityCard.swift
  ScoreGauge.swift
backend/
  stock_data.py              price + RSI/MACD/Bollinger via yfinance (free spike)
  sec_scanner.py             SEC EDGAR catalyst scanner (free, no API key)
  requirements.txt           yfinance, pandas, requests
```

## Conventions

- **No new files** without checking the existing module first — `Models/Opportunity.swift` already carries a ~30-field model with full Supabase Codable + mock data. Extend, don't fork.
- **Codable**: every model owns a custom `init(from:)` with `decodeIfPresent` fallbacks. Match this pattern when adding fields.
- **Naming**: Swift = `camelCase`; Postgres columns = `snake_case`; the `CodingKeys` enum bridges them.
- **Singletons**: services are `@MainActor final class … { static let shared }`. `AuthService` and `SupabaseService` already exist.
- **Async**: every network call is `async throws`. Errors map to `AppError`.
- **Dark mode only** (`.preferredColorScheme(.dark)` is set globally). Do not introduce light-mode-only assets.
- **No comments** in code unless asked.
- **Secrets**: Supabase anon key currently lives in-source — acceptable for anon-tier only. Service-role and any third-party API keys must come from env vars / `.xcconfig`, never committed.

## Verification

- **Build**: `xcodebuild -scheme NoFomo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
- **Lint**: SwiftLint is not yet wired (recommend adding before App Store submission).
- **Test**: no test target yet — `ios-shipper` agent owns adding `NoFomoTests` before submission.

## Active agent crew

Hermes orchestrates. Five research subagents feed it intel; one shipping subagent handles iOS/App Store work. See `.opencode/agent/*.md`.
