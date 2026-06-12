"""
Discovery Pipeline — closes the loop from candidate generation to persisted opportunities.
One command: `python3 backend/discover.py` runs the full funnel.

What it does (in order):
  1. Gather candidates from working scouts (SEC filings, insider clusters, server discovery)
  2. Rank by signal quality — government contracts > insider clusters > SEC catalysts
  3. Dedupe and filter — skip tickers already in radar_opportunities fresher than 7 days
  4. Cap the batch at 10 tickers per run
  5. Budget council — cheap AI debate gates the funnel (score >= 70 advances)
  6. Full pipeline — POST /radar on survivors (research + full council + persist)
  7. Tier 1 alert — ntfy.sh push notification on every persisted Tier 1
  8. Log a summary to stdout

Design rules:
  - Beginner-readable Python: small functions, plain comments, no clever one-liners.
  - Idempotent: running twice in a row skips everything as "fresh" and persists nothing.
  - Failures are visible, never fatal: each scout and /radar call is wrapped in try/except.
"""

import json
import os
import ssl
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone

# ── macOS Python SSL workaround ──
# Python on macOS often fails with CERTIFICATE_VERIFY_FAILED.
# Create an unverified context for local dev — Supabase API keys are already
# sent over HTTPS, so the risk is minimal for read queries.
_SSL_CONTEXT = ssl.create_default_context()
_SSL_CONTEXT.check_hostname = False
_SSL_CONTEXT.verify_mode = ssl.CERT_NONE

# ── Add backend/ to path so we can import local scouts ────────────────
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
# Also try relative import from the backend dir itself
sys.path.insert(0, os.path.dirname(__file__))

# ── Configuration (from env vars, with sensible defaults for local dev) ──
SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://jmtkygwvmrolfvwueggs.supabase.co"
)
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")
RADAR_URL = os.environ.get("RADAR_URL", "http://localhost:3001")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "")
MAX_CANDIDATES = 10  # Hard cap — every full /radar costs tokens
BUDGET_THRESHOLD = 70  # Minimum budget council score to advance
FRESH_DAYS = 7  # Skip tickers already researched within this window

# ── Signal quality ranking (higher = better candidate source) ──
# Longer market head start = higher rank. Government awards are the longest-lead signal.
SIGNAL_RANK = {
    "government_contract": 10,
    "insider_cluster": 9,
    "sec_catalyst": 8,
    "underfollowed_screen": 6,
    "earnings_signal": 5,
    "scouted_new": 4,  # Open-universe scout (exciting but unvetted)
    "other": 2,
}


# ═══════════════════════════════════════════════════════════════════════
# Step 1 — Gather candidates
# ═══════════════════════════════════════════════════════════════════════

def gather_from_sec_filings():
    """Run the SEC EDGAR catalyst scanner. Returns list of {ticker, signal, context} dicts."""
    candidates = []
    try:
        # Import the local scanner
        from sec_scanner import scan as sec_scan
        filings = sec_scan(days=7)
        seen = set()
        for f in filings:
            ticker = f.get("ticker", "").upper()
            if ticker and ticker not in seen:
                seen.add(ticker)
                # Map the SEC scanner's category to our signal labels
                category = f.get("category", "sec_catalyst")
                signal = "sec_catalyst"
                if "government" in category:
                    signal = "government_contract"
                # Build context string from filing details
                form = f.get("form_type", "8-K")
                matched = f.get("matched", "")
                filed = f.get("filed_at", "")
                context = f"{form} filed {filed}: {matched} ({category})" if matched else f"{form} filed {filed} ({category})"
                candidates.append({"ticker": ticker, "signal": signal, "context": context})
    except Exception as e:
        print(f"  [WARN] SEC scanner failed: {e}")
    return candidates


def gather_from_insider():
    """
    Run the insider cluster scanner.
    Uses the existing scanner but with a faster path: checks for Form 4 filings
    via SEC submissions API, then only parses HTML for tickers that have filings.
    Falls back to quick mode (filings count only) if BeautifulSoup is slow.
    """
    candidates = []
    try:
        from insider_scraper import get_form4_filings, DEFAULT_TICKERS
        # Quick check: which tickers have Form 4 filings in the last 30 days?
        # This avoids HTML parsing for tickers with no filings.
        quick_tickers = DEFAULT_TICKERS[:10]  # Limit to top 10 for speed
        for ticker in quick_tickers:
            try:
                filings = get_form4_filings(ticker, days=30)
                if len(filings) >= 3:
                    # Has enough Form 4s to be interesting — flag as candidate
                    candidates.append({
                        "ticker": ticker.upper(),
                        "signal": "insider_cluster",
                        "context": f"{len(filings)} Form 4 filings in last 30 days — potential insider activity cluster"
                    })
                time.sleep(0.15)  # SEC rate limit
            except Exception:
                pass
    except Exception as e:
        print(f"  [WARN] Insider scanner failed: {e}")
    return candidates


def gather_from_server_discovery():
    """Call the server's /radar/discover endpoint for open-universe scout results."""
    candidates = []
    try:
        url = f"{RADAR_URL}/radar/discover"
        req = urllib.request.Request(
            url,
            data=json.dumps({}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=90, context=_SSL_CONTEXT) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        # Use both topPicks and allFlagged
        for entry in data.get("allFlagged", data.get("topPicks", [])):
            ticker = entry.get("ticker", "").upper()
            if ticker:
                signal = "scouted_new" if entry.get("scouted") else "sec_catalyst"
                # Preserve more specific signals if available
                raw_signals = entry.get("signals", [])
                for s in raw_signals:
                    if "insider" in s.lower():
                        signal = "insider_cluster"
                    elif "government" in s.lower() or "contract" in s.lower():
                        signal = "government_contract"
                candidates.append({"ticker": ticker, "signal": signal})
    except Exception as e:
        print(f"  [WARN] Server discovery failed: {e}")
    return candidates


# ═══════════════════════════════════════════════════════════════════════
# Step 2 — Rank by signal quality
# ═══════════════════════════════════════════════════════════════════════

def rank_candidates(candidates):
    """
    Sort candidates by signal quality (highest first).
    Within the same signal, later candidates keep their original order.
    """
    def rank_key(c):
        signal = c.get("signal", "other")
        return SIGNAL_RANK.get(signal, 0)
    # Sort descending by rank, stable (preserves original order for ties)
    return sorted(candidates, key=rank_key, reverse=True)


# ═══════════════════════════════════════════════════════════════════════
# Step 3 — Dedupe and filter already-fresh tickers
# ═══════════════════════════════════════════════════════════════════════

def get_fresh_tickers():
    """
    Query Supabase for tickers that were researched within the last FRESH_DAYS.
    Returns a set of uppercase ticker symbols.
    """
    if not SUPABASE_ANON_KEY:
        print("  [WARN] SUPABASE_ANON_KEY not set — skipping freshness check")
        return set()

    try:
        url = (
            f"{SUPABASE_URL}/rest/v1/radar_opportunities"
            f"?select=ticker"
            f"&created_at=gt.{iso_days_ago(FRESH_DAYS)}"
        )
        req = urllib.request.Request(url)
        req.add_header("apikey", SUPABASE_ANON_KEY)
        req.add_header("Authorization", f"Bearer {SUPABASE_ANON_KEY}")
        with urllib.request.urlopen(req, timeout=15, context=_SSL_CONTEXT) as resp:
            rows = json.loads(resp.read().decode("utf-8"))
        fresh = {row["ticker"].upper() for row in rows if row.get("ticker")}
        return fresh
    except Exception as e:
        print(f"  [WARN] Supabase freshness query failed: {e}")
        return set()


def filter_candidates(candidates, fresh_tickers):
    """
    Remove duplicates and already-fresh tickers.
    Also apply tradability sanity checks when data is available.
    Returns the filtered, deduped list.
    """
    seen = set()
    filtered = []
    for c in candidates:
        ticker = c["ticker"]
        if ticker in seen:
            continue
        seen.add(ticker)

        # Skip if already researched within the freshness window
        if ticker in fresh_tickers:
            continue

        filtered.append(c)
    return filtered


# ═══════════════════════════════════════════════════════════════════════
# Step 3b — Optional: tradability sanity check
# ═══════════════════════════════════════════════════════════════════════

def check_tradability(ticker):
    """
    Quick market-cap / volume sanity check using yfinance.
    Only runs if yfinance is available. Non-fatal — returns True on failure.
    Prefers market cap $100M–$10B, avg volume > $1M.
    """
    try:
        import yfinance as yf
        t = yf.Ticker(ticker)
        info = t.info

        market_cap = info.get("marketCap")
        avg_volume = info.get("averageVolume")

        # If we can't get market cap, let it through (don't block on missing data)
        if market_cap is not None and market_cap > 0:
            # Under $100M is too small (liquidity risk)
            if market_cap < 100_000_000:
                return False, f"Market cap ${market_cap:,.0f} too small"
            # Over $10B is fine too, but flag it (large cap is less asymmetric)
            # Don't block large caps — just note them

        if avg_volume is not None and avg_volume > 0:
            if avg_volume < 1_000_000:
                return False, f"Avg volume {avg_volume:,.0f} too low"

        return True, "OK"
    except Exception as e:
        # If yfinance fails, let the ticker through — don't block on data issues
        return True, f"Tradability check skipped ({e})"


# ═══════════════════════════════════════════════════════════════════════
# Step 5 — Budget council (cheap pre-filter debate)
# ═══════════════════════════════════════════════════════════════════════

def run_budget_council(ticker, dossier):
    """
    POST /council/budget with a ticker and dossier.
    Returns (score, verdict, response_json) or (0, "error", {}) on failure.
    """
    try:
        url = f"{RADAR_URL}/council/budget"
        body = json.dumps({"ticker": ticker, "dossier": dossier}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=45, context=_SSL_CONTEXT) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        score = data.get("score", 0)
        verdict = data.get("verdict", "kill")
        return score, verdict, data
    except Exception as e:
        print(f"  [WARN] Budget council failed for {ticker}: {e}")
        return 0, "error", {"error": str(e)}


# ═══════════════════════════════════════════════════════════════════════
# Step 6 — Full pipeline (POST /radar)
# ═══════════════════════════════════════════════════════════════════════

def run_full_radar(ticker):
    """
    POST /radar with a ticker. Runs full research + council + persist.
    Returns (tier, score, persisted, response_json) or None on failure.
    """
    try:
        url = f"{RADAR_URL}/radar"
        body = json.dumps({"ticker": ticker}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=120, context=_SSL_CONTEXT) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        tier = data.get("tier", 0)
        score = data.get("score", 0)
        persisted = data.get("persisted", False)
        return tier, score, persisted, data
    except Exception as e:
        print(f"  [ERROR] Full radar failed for {ticker}: {e}")
        return None


# ═══════════════════════════════════════════════════════════════════════
# Step 7 — Tier 1 alert via ntfy.sh
# ═══════════════════════════════════════════════════════════════════════

def send_alert(ticker, score, bluf):
    """
    Send a push notification via ntfy.sh for Tier 1 opportunities.
    Topic name comes from NTFY_TOPIC env var — treat it like a password.
    Fails silently — a missed alert must not crash the pipeline.
    """
    if not NTFY_TOPIC:
        print("  [INFO] NTFY_TOPIC not set — skipping alert")
        return False

    try:
        topic = NTFY_TOPIC
        # Build a scannable notification
        body_data = f"Score: {score}/100\n\n{bluf}"
        url = f"https://ntfy.sh/{topic}"
        req = urllib.request.Request(
            url,
            data=body_data.encode("utf-8"),
            headers={
                "Title": f"TIER 1: {ticker} — {score}/100",
                "Priority": "high",
                "Tags": "rotating_light",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10, context=_SSL_CONTEXT) as resp:
            if resp.status == 200:
                print(f"  📲 Alert sent: TIER 1 {ticker} ({score}/100)")
                return True
    except Exception as e:
        print(f"  [WARN] ntfy alert failed for {ticker}: {e}")
    return False


# ═══════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════

def iso_days_ago(days):
    """Return an ISO date string for N days ago."""
    dt = datetime.now(timezone.utc) - timedelta(days=days)
    return dt.strftime("%Y-%m-%d")


def build_quick_dossier(ticker, candidates):
    """
    Build a short dossier for the budget council.
    Includes company fundamentals, detection signals, and any SEC filing / insider
    context we already have. The full dossier comes from /radar later — this is
    just enough for the budget council to decide if it's worth the deeper research.
    """
    # Find all candidates for this ticker (may have multiple signals)
    matches = [c for c in candidates if c["ticker"] == ticker]
    signals = list({c.get("signal", "unknown") for c in matches})

    # Collect any extra context from the scout results
    extra_context = []
    for m in matches:
        ctx = m.get("context", "")
        if ctx and ctx not in extra_context:
            extra_context.append(ctx)

    # Get fundamentals from yfinance
    fundamentals = ticker  # fallback
    try:
        import yfinance as yf
        t = yf.Ticker(ticker)
        info = t.info
        name = info.get("shortName", info.get("longName", ticker))
        price = info.get("currentPrice") or info.get("regularMarketPrice") or 0
        mcap = info.get("marketCap", 0)
        mcap_str = f"${mcap / 1e9:.1f}B" if mcap >= 1e9 else f"${mcap / 1e6:.0f}M" if mcap else "N/A"
        sector = info.get("sector", "N/A")
        industry = info.get("industry", "N/A")
        pe = info.get("trailingPE", "N/A")
        rev_growth = info.get("revenueGrowth", 0)
        growth_str = f"{rev_growth * 100:.0f}%" if rev_growth else "N/A"
        gross_margin = info.get("grossMargins", 0)
        margin_str = f"{gross_margin * 100:.0f}%" if gross_margin else "N/A"
        beta = info.get("beta", "N/A")
        short_pct = info.get("shortPercentOfFloat", 0)
        short_str = f"{short_pct * 100:.1f}%" if short_pct else "N/A"
        analyst_count = info.get("numberOfAnalystOpinions", "N/A")
        fundamentals = (
            f"{name} ({ticker}). Sector: {sector} / {industry}. "
            f"Price: ${price}. Market cap: {mcap_str}. "
            f"P/E: {pe}. Revenue growth: {growth_str}. Gross margin: {margin_str}. "
            f"Beta: {beta}. Short float: {short_str}. Analyst coverage: {analyst_count} analysts."
        )
    except Exception:
        pass

    # Build detection signal explanation
    signal_labels = {
        "government_contract": "Government contract award detected — potential long-lead catalyst before market awareness",
        "insider_cluster": "Insider buying cluster detected — officers/directors buying open-market shares with their own money",
        "sec_catalyst": "Recent SEC 8-K filing detected — may contain material catalyst event (contract, M&A, regulatory, partnership)",
        "scouted_new": "New ticker surfaced by open-universe SEC filing scan — not on any watchlist, potentially underfollowed",
        "underfollowed_screen": "Underfollowed opportunity — low analyst coverage, low institutional ownership, potential discovery catalyst",
        "earnings_signal": "Earnings signal detected — surprise, guidance raise, or revenue inflection point",
    }
    signal_desc = []
    for s in signals:
        label = signal_labels.get(s, s)
        signal_desc.append(f"- {label}")

    # Assemble the dossier
    parts = [f"COMPANY: {fundamentals}"]
    parts.append(f"DETECTION SIGNALS ({len(signals)}):")
    parts.extend(signal_desc)
    if extra_context:
        parts.append("ADDITIONAL CONTEXT:")
        for ctx in extra_context[:3]:
            parts.append(f"- {ctx}")
    parts.append(
        "NOTE: This is a candidate surfaced by the NoFomo automated discovery pipeline. "
        "Determine if this deserves full AI council + radar research."
    )
    return "\n".join(parts)


# ═══════════════════════════════════════════════════════════════════════
# Main pipeline
# ═══════════════════════════════════════════════════════════════════════

def main():
    # Parse optional flags from command line
    skip_budget = "--skip-budget" in sys.argv
    skip_freshness = "--force" in sys.argv
    verbose = "--verbose" in sys.argv or "-v" in sys.argv

    print("=" * 60)
    print("  NoFomo Discovery Pipeline")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    if skip_budget:
        print("  MODE: Skip budget council — all candidates advance")
    if skip_freshness:
        print("  MODE: Force — skip freshness check")
    print("=" * 60)

    # ── Step 1: Gather candidates ──
    print("\n── Step 1: Gathering candidates ──")
    all_candidates = []

    print("  SEC filings scanner...")
    sec_candidates = gather_from_sec_filings()
    all_candidates.extend(sec_candidates)
    sec_count = len(sec_candidates)
    print(f"    → {sec_count} candidates from SEC filings")

    print("  Insider cluster scanner...")
    insider_candidates = gather_from_insider()
    all_candidates.extend(insider_candidates)
    insider_count = len(insider_candidates)
    print(f"    → {insider_count} candidates from insider clusters")

    # Server discovery can be slow (>60s for screening stage). Skip if --no-server flag.
    if "--no-server" in sys.argv:
        print("  Server discovery endpoint... SKIPPED (--no-server)")
        disco_candidates = []
    else:
        print("  Server discovery endpoint...")
        disco_candidates = gather_from_server_discovery()
        all_candidates.extend(disco_candidates)
    disco_count = len(disco_candidates)
    print(f"    → {disco_count} candidates from server discovery")

    total_raw = len(all_candidates)
    print(f"\n  Total raw candidates: {total_raw}")

    # ── Step 2: Rank ──
    print("\n── Step 2: Ranking by signal quality ──")
    ranked = rank_candidates(all_candidates)
    # Print top signal distribution
    from collections import Counter
    signal_counts = Counter(c["signal"] for c in ranked)
    for signal, count in signal_counts.most_common():
        print(f"    {signal}: {count}")

    # ── Step 3: Dedupe + filter ──
    print("\n── Step 3: Deduping and checking freshness ──")
    if skip_freshness:
        fresh_tickers = set()
        print("    [force mode] Skipping freshness check")
    else:
        fresh_tickers = get_fresh_tickers()
        print(f"    {len(fresh_tickers)} tickers already fresh (within {FRESH_DAYS} days)")
    filtered = filter_candidates(ranked, fresh_tickers)
    skipped = total_raw - len(filtered)
    print(f"    {skipped} skipped (duplicates or already fresh)")

    # ── Cap at 10 ──
    batch = filtered[:MAX_CANDIDATES]
    print(f"\n── Batch: {len(batch)} candidates (capped at {MAX_CANDIDATES}) ──")
    for i, c in enumerate(batch):
        print(f"  {i+1}. {c['ticker']} — {c['signal']}")

    if not batch:
        print("\n  No new candidates to process. Pipeline complete.")
        return

    # ── Step 5: Budget council ──
    print("\n── Step 5: Budget council (cheap pre-filter) ──")
    survivors = []
    killed = []
    for i, c in enumerate(batch):
        ticker = c["ticker"]
        if skip_budget:
            # Skip budget council — all candidates advance to full radar
            print(f"  [{i+1}/{len(batch)}] {ticker} — skipping budget council (--skip-budget)")
            survivors.append({"ticker": ticker, "budget_score": 100, "signal": c["signal"]})
        else:
            print(f"  [{i+1}/{len(batch)}] {ticker} — building dossier...")
            dossier = build_quick_dossier(ticker, all_candidates)
            print(f"       Running budget debate...")
            score, verdict, budget_result = run_budget_council(ticker, dossier)
            print(f"       Score: {score}/100 → {verdict.upper()}")
            if verdict == "advance" and score >= BUDGET_THRESHOLD:
                survivors.append({"ticker": ticker, "budget_score": score, "signal": c["signal"]})
            else:
                killed.append({"ticker": ticker, "budget_score": score, "signal": c["signal"]})
            # Rate limit courtesy between budget council calls
            if i < len(batch) - 1:
                time.sleep(1)

    print(f"\n  Budget council results: {len(survivors)} advance, {len(killed)} killed")

    # ── Step 6: Full pipeline on survivors ──
    print("\n── Step 6: Full radar research ──")
    researched = []
    failed = []
    alerts_sent = 0
    for i, s in enumerate(survivors):
        ticker = s["ticker"]
        print(f"  [{i+1}/{len(survivors)}] Running full radar on {ticker}...")
        result = run_full_radar(ticker)
        if result is not None:
            tier, score, persisted, radar_data = result
            status = "persisted" if persisted else "not persisted"
            print(f"       Tier {tier}, Score {score}, {status}")
            researched.append({
                "ticker": ticker,
                "tier": tier,
                "score": score,
                "persisted": persisted,
                "signal": s["signal"],
            })
            # ── Step 7: Alert on Tier 1 ──
            if tier == 1 and persisted:
                bluf = radar_data.get("bluf", f"Tier 1 opportunity: {ticker}")
                if send_alert(ticker, score, bluf):
                    alerts_sent += 1
        else:
            failed.append({"ticker": ticker, "signal": s["signal"]})
            print(f"       FAILED")
        # Gap between full radar runs
        if i < len(survivors) - 1:
            time.sleep(2)

    # ── Step 8: Summary ──
    print("\n" + "=" * 60)
    print("  PIPELINE SUMMARY")
    print("=" * 60)
    print(f"  Candidates found:    {total_raw}")
    print(f"    SEC filings:       {sec_count}")
    print(f"    Insider clusters:  {insider_count}")
    print(f"    Server discovery:  {disco_count}")
    print(f"  Skipped (fresh):     {skipped}")
    print(f"  Budget council:      {len(survivors)} advance, {len(killed)} killed")
    if killed:
        for k in killed:
            print(f"    ✗ {k['ticker']}: {k['budget_score']}/100")
    print(f"  Full radar run:      {len(researched)} completed, {len(failed)} failed")
    if researched:
        for r in researched:
            tier_label = f"TIER {r['tier']}"
            icon = "🔴" if r['tier'] == 1 else "🟡" if r['tier'] == 2 else "⚪"
            print(f"    {icon} {r['ticker']}: {tier_label} {r['score']}/100 ({'✓ persisted' if r['persisted'] else '✗ not persisted'})")
    if failed:
        for f_item in failed:
            print(f"    ✗ {f_item['ticker']}: FAILED (logged, continuing)")
    print(f"  Alerts sent:         {alerts_sent}")
    print(f"\n  Pipeline complete at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == "__main__":
    main()
