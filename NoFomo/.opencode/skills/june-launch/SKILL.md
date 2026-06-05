---
name: june-launch
description: Use when the NoFomo launch sprint is in scope — App Store submission, paywall wiring, TestFlight, signing, the 3-tier quota enforcement, or any "what's left to ship by end of June" question. Loads the launch checklist, the day-by-day countdown, the iOS verification command, and the paywall entitlement map. Load BEFORE dispatching ios-shipper on a launch-tied task.
---

# NoFomo — June Launch Playbook

This skill is loaded by Hermes whenever the request touches the launch deadline (end of June 2026), the App Store submission, the paywall, or the 3-tier quota enforcement. Read this before dispatching `ios-shipper` on a launch-tied task.

## What "done" looks like on June 30

1. App is **live on the App Store**, signed with a Distribution provisioning profile, primary category "Finance", secondary "Business".
2. The **3-tier model is enforced server-side**: Free = 1 ticker / 24h, Pro = $9.99/mo unlimited + full bear/bull debate, Annual = $79.99/yr Pro features. Supabase RLS + RPC back the entitlements. Client-side checks are belt-and-suspenders, not the only check.
3. The **AI council** (Gemini + DeepSeek + CIO arbiter) produces verdicts persisted to `Opportunity.council` and rendered in the detail sheet for Pro and Annual tiers; Free sees the `bluf` + redacted financials only.
4. The app **builds clean** on `xcodebuild -scheme NoFomo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build` with zero warnings treated as errors.
5. **APNs** is wired: token registered on first launch, push for Pro and Annual on watchlist triggers.
6. **Crash-free rate** > 99% in the first 48h post-launch (no obvious ship-blocker).

## Countdown (working backwards from June 30, 2026)

| Day       | Milestone                                                                                    |
| --------- | -------------------------------------------------------------------------------------------- |
| **Jun 1** | All 3 tier entitlements working locally with StoreKit 2 sandbox. Server-side RPC + RLS live. |
| **Jun 8** | TestFlight external beta (50 users). Crash-free > 99% in the first 48h of beta.              |
| **Jun 15**| App Store Connect metadata final: title, subtitle, keywords, screenshots, privacy answers.  |
| **Jun 22**| Submit to App Review. (Apple typically takes 24-48h; pad for a rejection and a resubmit.)    |
| **Jun 25**| If still in review, escalate via the App Store Connect API for an expedited review.         |
| **Jun 30**| Live.                                                                                        |

Adjust dates weekly based on actual progress; the constraint is "live by end of June", not "submitted by end of June".

## The iOS verification command

Run before any submission, after any change to entitlements, and on every PR that touches `Services/` or `Views/`:

```
xcodebuild -scheme NoFomo \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -quiet \
  build
```

Add `-enableCodeCoverage YES` once a `NoFomoTests` target exists (ios-shipper owns that).

## The 3-tier entitlement map

Where the tier is enforced, for every Pro-only feature:

| Feature                       | Free                          | Pro               | Annual            | Server enforcement                          |
| ----------------------------- | ----------------------------- | ----------------- | ----------------- | ------------------------------------------- |
| Tick per 24h                  | 1                             | unlimited         | unlimited         | Supabase RPC `consume_ticker_quota`         |
| Delivery delay                | 4h                            | real-time         | real-time         | Supabase RLS on `radar_opportunities_detail`|
| `bull_case`, `bear_case`      | redacted                      | full              | full              | RLS on `radar_opportunities_detail`         |
| `buy_zones`                   | hidden                        | shown             | shown             | RLS on `radar_opportunities_detail`         |
| `red_flags`                   | count only, no text           | full              | full              | RLS on `radar_opportunities_detail`         |
| Council verdicts (3 models)   | teaser (CIO only)             | full (Gemini/DS/CIO) | full           | RLS on `radar_opportunities_detail`         |
| Watchlist size                | 3                             | unlimited         | unlimited         | RLS on `user_watchlist` (count constraint)  |
| Push alerts                   | off                           | on                | on                | Server-side filter on `push_tokens.tier`    |
| Restore purchases             | n/a                           | required          | required          | StoreKit 2 `Transaction.currentEntitlements`|

**The free-tier redaction happens at the Supabase layer, not the Swift layer.** The client should never receive a redacted field in a successful response — the server should omit it. If you find yourself hiding columns in `FeedView`, that is a bug; fix the RLS policy.

## App Store Connect metadata — first draft

- **App name**: NoFomo
- **Subtitle**: AI-Council Equity Alpha
- **Category**: Finance (primary), Business (secondary)
- **Keywords**: ai stocks, equity research, smart money, insider trading, stock alerts, market brief
- **Description** (first 3 lines are the only ones visible without tapping "more"):
  > Surfacing high-conviction equity opportunities the market has not yet repriced.
  > Our AI council (Gemini + DeepSeek + arbiter CIO) debates every thesis in plain English.
  > Free: 1 ticker / 24h. Pro: unlimited + full bear/bull debate. Annual: Pro, billed yearly.
- **Privacy**: collect APNs token, sign-in email, watchlist, in-app subscription status. No third-party SDKs that track. Configure App Tracking Transparency prompt = "no tracking".
- **Support URL**: required.
- **Privacy policy URL**: required (host on a static page; Supabase Edge Function or GitHub Pages both work).

## Pre-submission checklist (run this verbatim)

- [ ] `xcodebuild` build green on iPhone 15 Pro simulator
- [ ] Three StoreKit 2 products configured in App Store Connect with the right price points and availability
- [ ] `EntitlementsService` reads `Transaction.currentEntitlements` on launch and after every purchase
- [ ] Free-tier quota enforced by a Supabase RPC, not just the client
- [ ] Free-tier field redaction enforced by Supabase RLS, not by hiding columns in SwiftUI
- [ ] Sign in with Apple configured, Supabase `auth/v1/token?grant_type=id_token` round-trip tested
- [ ] APNs token registered on first launch; push for Pro / Annual only
- [ ] No service-role keys, no Polygon key, no Tavily key, no RevenueCat key in source
- [ ] No comments in committed code (matches repo convention)
- [ ] Privacy policy and Support URLs reachable
- [ ] App icon set in `Assets.xcassets` (no placeholder)
- [ ] Launch screen storyboard or SwiftUI launch screen set
- [ ] `Info.plist` has the right usage descriptions (none required for current feature set; confirm when push is added)
- [ ] Build version (`CFBundleVersion`) and short version (`CFBundleShortVersionString`) set
- [ ] TestFlight beta submitted, crash-free > 99% in 48h

## Common rejection causes to dodge

- **Guideline 2.1 — App Completeness**: dead links, placeholder text, no live data. Mitigate: real opportunities seeded in `radar_opportunities` for at least 5 tickers before submission.
- **Guideline 3.1.1 — In-App Purchase**: paywall must use StoreKit / IAP, not a web checkout. Mitigate: StoreKit 2 is the only purchase path; no external links to subscriptions.
- **Guideline 4.0 — Design**: minimum iOS version mismatch, broken layouts on small devices. Mitigate: test on iPhone SE (3rd gen) and iPhone 15 Pro Max simulators both.
- **Guideline 5.1.1 — Privacy**: claiming data collection you don't disclose, or vice versa. Mitigate: App Store privacy questionnaire matches actual `Info.plist` and Supabase schema.

## What to do on a rejection

1. Read the full rejection text. Apple is specific. Map every cited guideline to the exact line that triggers it.
2. Patch in the smallest change that satisfies the guideline. Do not refactor.
3. Resubmit. If it's a hard rejection (Guideline 2.1 binary), escalate via the App Review Board contact form before resubmitting.

## What to delegate, never do yourself

- iOS code, build, signing, paywall → `ios-shipper`
- AI council verdicts, catalyst evidence → `deep-research` + the council backend
- Macro context for the home-screen brief → `market-brief`
- Sector screens for new thesis generation → `sector-scanner`
- Smart-money evidence per ticker → `whale-tracker`
- Downside audits per ticker → `risk-audit`
