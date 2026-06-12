# NoFomo — Roadmap to TestFlight Beta

**Date:** 2026-06-09 · **Branch:** `fix/server-repair-jelly-signals` · **Commit:** `8cd1b9c` (pushed)

---

## 0. Where We Are Now

### What Works

| Layer | Status | Detail |
|-------|--------|--------|
| **Server** | ✅ Builds clean | `tsc` exit 0, all routes mounted, runs on `:3001` |
| **Server data** | ✅ Live | Scans, scores, enriches, persists to Supabase |
| **Supabase** | ✅ 14 companies | `jmtkygwvmrolfvwueggs` — CRDO, LUNR, RDW, SOUN, ALAB, SMR, PLTR, KTOS, OKLO, ASTS, RKLB, MSTR, VRT, TSLA |
| **iOS build** | ✅ Compiles | Builds for iPhone 17 sim, zero errors |
| **iOS Supabase** | ✅ Fixed | `SupabaseService.swift` points at correct project (was the root cause of "same 8 companies") |
| **Asymmetry decay** | ✅ Fixed | Bug where missing analyst data caused mass-pruning is patched |
| **Daily automation** | ✅ Configured | `vercel.json` cron at 15:00 UTC runs radars + persists + sweeps |
| **Kalshi foundation** | ✅ Scaffolded | Endpoint + tool exist; needs econ-market targeting to surface useful data |
| **Git** | ✅ Clean push | All code changes committed and pushed to `origin/fix/server-repair-jelly-signals` |

### What's Incomplete

| Gap | Impact | Effort |
|-----|--------|--------|
| **Detail sheet** | Tapping a company shows nothing useful | Medium |
| **Loading/error/empty states** | App is blank or crashes if Supabase is down | Small |
| **Pull to refresh** | Must kill and relaunch to see new data | Tiny |
| **Watchlist UI** | Backend exists, no frontend | Medium |
| **Push notifications** | `registerPushToken` exists, no server-side trigger wiring | Medium |
| **Auth** | No user accounts; watchlist requires user_id | Medium |
| **App icon** | No icon set configured | Small |
| **Launch screen** | Default or missing | Small |
| **App Store Connect** | Unknown bundle ID registration status | Small |
| **Server deployment** | Runs locally only; `vercel.json` exists but may not be deployed | Medium |
| **Kalshi econ targeting** | Sports-prop noise dominates; needs series-ticker approach | Small |
| **RevenueCat** | Env vars stubbed, no implementation | Medium |

### Git State

```
Branch: fix/server-repair-jelly-signals (up to date with origin)
Remote: https://github.com/Maple-maker/No-Fomo.git
Last commit: 8cd1b9c fix(ios): point SupabaseService at correct project + build fixes
```

**Uncommitted files** (all untracked — none are code):
- `SESSION_HANDOFF.md`, `ROADMAP_TO_BETA.md` — working documents
- `.opencode/`, `opencode.json`, `AGENTS.md` — parallel agent config
- `*.md` — various working notes (API_SOURCES_TODO, SIGNAL_EXPANSION_TODO, etc.)
- `.claude/` — local Claude config
- `.env.example` — template (safe to leave untracked)

---

## 1. The Path to TestFlight Beta

### Phase 1 — Core App Completeness (first, because everything else depends on it)

**Goal:** The app feels like a real app, not a scaffold.

#### 1a. Detail Sheet (highest priority)

The `Opportunity` model already carries all the fields needed for a deep-research view. The view doesn't exist yet.

**What to build:**
- `DetailSheet.swift` — a scrollable view that renders:
  - Company name, ticker, sector, tier badge, score
  - Thesis / bluf
  - AI Council verdicts (Gemini, DeepSeek, CIO) — bull/bear with reasoning
  - Buy zones (aggressive / base / conservative)
  - Bull case / bear case
  - Red flags
  - Financials table
  - Analyst consensus, price targets, recent actions
  - Insider activity, institutional flow
  - Upcoming events / catalysts
  - Tags, sources, detection lane
- Navigation from `FeedView` — tap a row → push or sheet to detail

**Files to touch:** Create `NoFomo/Views/Detail/DetailSheet.swift`, modify `NoFomo/Views/Feed/FeedView.swift`

#### 1b. Loading, Error, and Empty States

**What to build:**
- `LoadingView` — shimmer/skeleton rows while `fetchFeed()` is in flight
- `ErrorView` — "Unable to load opportunities" with a Retry button
- `EmptyView` — "No opportunities found. Check back soon." with illustration or icon
- Wire these into `FeedViewModel` states (`isLoading`, `error`, `opportunities.isEmpty`)

**Files to touch:** `NoFomo/ViewModels/FeedViewModel.swift`, `NoFomo/Views/Feed/FeedView.swift`

#### 1c. Pull to Refresh

- Add `.refreshable { await viewModel.fetchFeed() }` to the feed List/ScrollView
- Ensure `fetchFeed` is properly marked `async` and updates published state

### Phase 2 — User Features

**Goal:** Watchlist + notifications make the app sticky.

#### 2a. Watchlist UI

Backend is ready (`get_watchlist` RPC, `user_watchlist` table, `SupabaseService.addToWatchlist/removeFromWatchlist`).

**What to build:**
- Star/bookmark button on each feed row and detail sheet
- Watchlist tab or section showing bookmarked companies
- Toggle add/remove with optimistic UI update

#### 2b. Auth (lightweight)

Watchlist needs a `user_id`. Options:
- **Anonymous auth** — generate a UUID on first launch, store in `UserDefaults`, use as `user_id`. Zero friction, no account creation.
- **Apple Sign In** — proper auth, but more work. Can be added later.

**Recommendation:** Start with anonymous (1 hour of work) and add Apple Sign In post-beta.

#### 2c. Push Notifications

**What exists:** `SupabaseService.registerPushToken(token, userId)` posts to `push_tokens` table. Server has notification infrastructure from the research pipeline.

**What needs doing:**
- Request notification permission in the app (`UNUserNotificationCenter`)
- Register for remote notifications (`UIApplication.shared.registerForRemoteNotifications`)
- Wire the APNs token into `SupabaseService.registerPushToken`
- Server side: add a notification trigger when a new Tier 1 opportunity is scanned (check `tier=1` after each scan, push via APNs to all registered tokens)
- **Important:** APNs needs a key (.p8) from App Store Connect → `Apple Push Notifications service (APNs)` key — this is an account-level setup, not code

### Phase 3 — App Store Connect & Distribution

**Goal:** A build that can go to TestFlight.

#### 3a. App Store Connect Checklist

- [ ] Bundle ID registered (`com.nofomo.app` or whatever's in the Xcode project)
- [ ] App record created in App Store Connect
- [ ] Distribution certificate (if not using auto-signing)
- [ ] App Store provisioning profile
- [ ] TestFlight Internal Testing group configured
- [ ] Privacy labels filled out (App Store Connect → App Privacy)
- [ ] Export compliance (uses no encryption beyond OS-provided TLS)

#### 3b. App Assets

- [ ] App icon — all sizes (1024x1024 base, Xcode generates derivatives)
- [ ] Launch screen — `LaunchScreen.storyboard` or SwiftUI launch screen
- [ ] App display name, subtitle, category (Finance or News)

#### 3c. Build & Upload

- [ ] Archive build: `xcodebuild archive -scheme NoFomo -archivePath ...`
- [ ] Upload to App Store Connect: `xcodebuild -exportArchive ...` or Xcode Organizer
- [ ] Submit for TestFlight review (first build always needs manual review; subsequent builds are faster)

### Phase 4 — Server Productionization

**Goal:** The server runs reliably, not just on localhost.

#### 4a. Deploy

The `vercel.json` already exists at `NoFomo/server/vercel.json`. Options:
- **Vercel** — easiest path, Node/Express works natively in Fluid Compute. `vercel deploy` from `NoFomo/server/`.
- **Railway** — also easy, git-push deploy.
- **Fly.io** — more control, more setup.

**Recommendation:** Vercel (config already exists, free tier, 300s timeout).

#### 4b. Observability

- Add basic request logging (morgan or similar)
- Set up Vercel Logs or a simple healthcheck endpoint
- Verify cron (`GET /radar/cron` at 15:00 UTC) fires and succeeds

#### 4c. Server-side notifications

- After each radar scan, check for new Tier 1 opportunities
- If found, push to all registered APNs tokens via APNs HTTP/2 API
- APNs auth: JWT signed with the .p8 key from App Store Connect

---

## 2. Immediate Next Actions (ranked)

These are the exact next steps, in order, for the next session:

### Step 1 — Audit the iOS codebase
Read every Swift file. Understand the current navigation structure, what views exist, what's half-built. Check:
- `NoFomo/Views/` — all view files
- `NoFomo/ViewModels/` — all view models
- `NoFomo/Models/` — all models
- `NoFomo/Services/` — SupabaseService, any other networking
- `NoFomo/NoFomoApp.swift` — the app entry point
- `project.yml` — the XcodeGen spec

### Step 2 — Build the Detail Sheet
This is the single biggest UX gap. The model has the data; the view doesn't render it. Start here.

### Step 3 — Add loading/error/empty states
These are small changes that dramatically improve the feel of the app.

### Step 4 — Pull to refresh
One modifier on the feed list.

### Step 5 — Anonymous auth + watchlist
Low-effort, high-reward. Gets the watchlist working without building full auth.

### Step 6 — Deploy the server
Get it off localhost so the app works on real devices without a local server.

### Step 7 — App Store Connect setup + archive upload
Get a build into TestFlight, even if it's rough. "Testable" means testers can install it.

### Step 8 — Push notifications
The last "real app" feature. Requires APNs key setup in App Store Connect.

---

## 3. Known Gotchas

- **xcodeproj is generated.** After adding Swift files, run `xcodegen generate` or the new files won't be in the build.
- **Don't commit `.env`.** The gitignore covers it, but double-check before any `git add .`.
- **opencode parallel agent.** There's another AI agent (`opencode`) that works on this repo. It rewrote the iOS layer recently. If it has an active PR or branch, coordinate. Commit and push promptly — it has a history of deleting untracked files.
- **Kalshi is noisy.** The `/markets` firehose is dominated by untraded sports props. To get useful econ/Fed data, target specific series tickers (e.g. `KXFED`) or use `/events?category=`. Don't spend time on Kalshi until after the core app is solid.
- **Yahoo returns 401/429 from dev IPs.** Data enrichment uses Brave + SEC EDGAR as reliable free sources.
- **Reddit hard-blocks (403).** Don't rely on Reddit for data.
- **The server must stay running** for the iOS app to get fresh scans, but the app can read from Supabase directly (feed is cached in `radar_opportunities`). Server downtime = no new discoveries, but existing data still loads.
- **First TestFlight build needs manual App Review.** Budget 24-48 hours for the first approval. Subsequent builds with the same bundle ID are usually faster.

---

## 4. Reference

| Resource | Path/URL |
|----------|----------|
| Research methodology | `NoFomo/NoFomo/CLAUDE.md` |
| Supabase project | `jmtkygwvmrolfvwueggs` (URL + keys in `/Users/jaidenrabatin/NoFomo/.env`) |
| Server env | `NoFomo/server/.env` |
| GitHub | `https://github.com/Maple-maker/No-Fomo.git` |
| Current branch | `fix/server-repair-jelly-signals` |
| Vercel config | `NoFomo/server/vercel.json` |
| iOS XcodeGen spec | `NoFomo/project.yml` |

---

## 5. Fable 5 Prompt

For the 2-week free Fable 5 window, paste the prompt below into a fresh session:

```
You are picking up the NoFomo iOS app to get it from its current state to a testable
TestFlight beta. Read ROADMAP_TO_BETA.md at the repo root first — it has the full
current-state assessment and ordered next steps.

Your job: execute Phase 1 (Core App Completeness) and Phase 2 (User Features) from
that document, building and verifying at each checkpoint.

Key rules:
- Read files before editing them
- Run xcodegen generate after adding Swift files
- Build with: xcodebuild -project NoFomo.xcodeproj -scheme NoFomo -destination
  'platform=iOS Simulator,name=iPhone 17' build
- Never commit .env files
- Keep files under 500 lines
- Verify the build succeeds before claiming anything is done

Start by reading ROADMAP_TO_BETA.md, then audit every Swift file in NoFomo/,
then produce a specific implementation order and execute it.
```
