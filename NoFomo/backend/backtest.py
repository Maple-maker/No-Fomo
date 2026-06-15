"""
No FOMO — event-study backtest runner.

Wires the radar_v2/backtest modules (loader, event_study, costs, drift_curves, report)
into a single runnable CLI. Treats each ticker's signal date as the event_time and
measures abnormal return vs a benchmark over a configurable horizon.

Usage:
    python3 backend/backtest.py --tickers PLTR --start 2024-01-01 --end 2024-12-31 --horizon-days 20 --json
    python3 backend/backtest.py --tickers PLTR NVDA AVAV --start 2023-01-01 --end 2024-12-31
    python3 backend/backtest.py --help

Design rules:
  - Uses the actual function signatures from radar_v2/backtest (event_return,
    abnormal_return, spread_haircut, median_drift_curve, render_honesty_guards).
  - Event time = market open on the START date for each ticker (simplest reproducible
    event; a real run would supply actual signal timestamps from the DB).
  - Prices fetched via yfinance (same as other backend modules).
  - Never crashes the whole run — per-ticker errors are caught, ticker is skipped.
  - Sample-size warning printed when n < 30.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone, timedelta
from statistics import mean, median
from typing import Optional


# ---------------------------------------------------------------------------
# Import radar_v2/backtest modules from their real location
# ---------------------------------------------------------------------------

def _add_backtest_to_path():
    """Add the radar_v2/backtest directory to sys.path."""
    here = os.path.dirname(os.path.abspath(__file__))
    bt_path = os.path.join(here, "radar_v2", "backtest")
    if bt_path not in sys.path:
        sys.path.insert(0, bt_path)
    # Also need backend/ on path for any internal imports
    if here not in sys.path:
        sys.path.insert(0, here)


_add_backtest_to_path()

# Now we can import the real modules
from event_study import event_return, abnormal_return, LookaheadError   # noqa: E402
from costs import spread_haircut                                          # noqa: E402
from drift_curves import median_drift_curve                              # noqa: E402
from report import render_honesty_guards                                  # noqa: E402


# ---------------------------------------------------------------------------
# Price fetching via yfinance
# ---------------------------------------------------------------------------

def _fetch_prices(ticker: str, start: str, end: str) -> list[dict]:
    """
    Return a list of dicts [{date, open, close}, ...] for ticker between
    start and end (inclusive), sorted by date.

    The format matches what event_study.event_return expects:
      each row must have 'date' (YYYY-MM-DD string), 'open', and optionally 'close'.
    """
    import yfinance as yf
    # Add a buffer so we have closing prices on the last horizon day
    t = yf.Ticker(ticker)
    hist = t.history(start=start, end=end)
    if hist is None or hist.empty:
        return []
    rows = []
    for ts, row in hist.iterrows():
        # ts is a pandas Timestamp — normalise to YYYY-MM-DD string
        date_str = ts.strftime("%Y-%m-%d")
        rows.append({
            "date":  date_str,
            "open":  float(row["Open"]),
            "close": float(row["Close"]),
        })
    return sorted(rows, key=lambda r: r["date"])


def _avg_daily_value(prices: list[dict], ticker: str, start: str, end: str) -> float:
    """Estimate average daily traded value for spread_haircut."""
    try:
        import yfinance as yf
        t = yf.Ticker(ticker)
        hist = t.history(start=start, end=end)
        if hist is None or hist.empty:
            return 0.0
        adv = float((hist["Close"] * hist["Volume"]).mean())
        return adv
    except Exception:
        return 0.0


# ---------------------------------------------------------------------------
# Per-ticker event study
# ---------------------------------------------------------------------------

def _run_event(
    ticker: str,
    benchmark: str,
    start: str,
    end: str,
    horizon_days: int,
    drift_horizons: list[int],
) -> Optional[dict]:
    """
    Run one event-study observation for *ticker*.

    Event time = 09:30 ET on the start date (first session after the signal).
    Returns a result dict or None on failure.
    """
    print(f"  [backtest] {ticker}: fetching prices ({start} → {end}) ...", file=sys.stderr)

    # Fetch prices for ticker and benchmark
    ticker_prices    = _fetch_prices(ticker, start, end)
    benchmark_prices = _fetch_prices(benchmark, start, end)

    if not ticker_prices:
        print(f"  [backtest] {ticker}: no price data — skipping", file=sys.stderr)
        return None
    if not benchmark_prices:
        print(f"  [backtest] {benchmark}: no benchmark price data — skipping {ticker}", file=sys.stderr)
        return None

    # Event time = NYSE open on the start date
    event_time = datetime.fromisoformat(f"{start}T13:30:00+00:00").astimezone(timezone.utc)

    # Compute cost via spread_haircut
    adv  = _avg_daily_value(ticker_prices, ticker, start, end)
    cost = spread_haircut(adv)

    # Compute event return + benchmark return at the main horizon
    try:
        t_ret = event_return(event_time, ticker_prices, horizon_days)
        b_ret = event_return(event_time, benchmark_prices, horizon_days)
    except LookaheadError as e:
        print(f"  [backtest] {ticker}: lookahead error — {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  [backtest] {ticker}: event_return error — {e}", file=sys.stderr)
        return None

    ab_ret = abnormal_return(t_ret, b_ret, cost)

    # Compute drift curve at multiple sub-horizons for richer output
    drift_returns: dict[int, float] = {}
    for h in drift_horizons:
        if h > horizon_days:
            continue
        try:
            t_h = event_return(event_time, ticker_prices, h)
            b_h = event_return(event_time, benchmark_prices, h)
            c_h = spread_haircut(adv)
            drift_returns[h] = round(abnormal_return(t_h, b_h, c_h) * 100, 3)
        except Exception:
            pass  # skip missing horizons gracefully

    result = {
        "ticker":            ticker,
        "event_date":        start,
        "horizon_days":      horizon_days,
        "benchmark":         benchmark,
        "ticker_return_pct": round(t_ret * 100, 3),
        "bench_return_pct":  round(b_ret * 100, 3),
        "cost_pct":          round(cost * 100, 4),
        "abnormal_return_pct": round(ab_ret * 100, 3),
        "hit":               ab_ret > 0,
        "avg_daily_value":   round(adv, 0),
        "returns":           drift_returns,   # used by drift_curves.median_drift_curve
    }
    return result


# ---------------------------------------------------------------------------
# Aggregate stats
# ---------------------------------------------------------------------------

def _aggregate(events: list[dict]) -> dict:
    """Compute hit-rate, mean, median abnormal return, drift curve."""
    n = len(events)
    if n == 0:
        return {"n": 0, "hit_rate_pct": None, "mean_abnormal_return_pct": None,
                "median_abnormal_return_pct": None, "drift_curve": {}}

    ab_rets = [e["abnormal_return_pct"] for e in events]
    hits    = [e for e in events if e["hit"]]

    # Drift curve using the backtest module's median_drift_curve
    all_horizons = sorted({h for e in events for h in e.get("returns", {})})
    drift = median_drift_curve(events, all_horizons)

    return {
        "n":                         n,
        "hit_rate_pct":              round(len(hits) / n * 100, 1),
        "mean_abnormal_return_pct":  round(mean(ab_rets), 3),
        "median_abnormal_return_pct": round(median(ab_rets), 3),
        "best_pct":                  round(max(ab_rets), 3),
        "worst_pct":                 round(min(ab_rets), 3),
        "drift_curve":               drift,
        "small_sample_warning":      n < 30,
    }


# ---------------------------------------------------------------------------
# Human-readable summary
# ---------------------------------------------------------------------------

def _print_summary(events: list[dict], agg: dict, honesty: str) -> None:
    n = agg["n"]
    if n == 0:
        print("\n  No events processed.\n")
        return

    print(f"\n{'─' * 60}")
    print(f"  BACKTEST RESULTS  (n={n})")
    print(f"{'─' * 60}")
    print(f"  Hit rate          : {agg['hit_rate_pct']}%")
    print(f"  Mean abnormal ret : {agg['mean_abnormal_return_pct']:+.2f}%")
    print(f"  Median abnormal   : {agg['median_abnormal_return_pct']:+.2f}%")
    print(f"  Best              : {agg['best_pct']:+.2f}%")
    print(f"  Worst             : {agg['worst_pct']:+.2f}%")
    if agg["small_sample_warning"]:
        print(f"  ⚠  INDICATIVE ONLY — n < 30 (sample too small for statistical inference)")
    if agg["drift_curve"]:
        print(f"\n  Drift curve (median abnormal return %):")
        for h, v in sorted(agg["drift_curve"].items(), key=lambda x: int(x[0])):
            bar = "█" * int(abs(float(v)) / 2) if v else ""
            print(f"    Day {int(h):>3}: {float(v):+6.2f}%  {bar}")
    print(f"\n{'─' * 60}")
    print("  Integrity guards:")
    for line in honesty.splitlines():
        print(f"    {line}")
    print(f"{'─' * 60}\n")

    print("  Individual events:")
    for e in events:
        icon = "✓" if e["hit"] else "✗"
        print(
            f"    {icon} {e['ticker']:<8} "
            f"event={e['event_date']}  "
            f"ticker={e['ticker_return_pct']:+.1f}%  "
            f"bench={e['bench_return_pct']:+.1f}%  "
            f"abnormal={e['abnormal_return_pct']:+.2f}%"
        )
    print()


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="No FOMO event-study backtest",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--tickers",      nargs="+", required=True,
                        help="Ticker symbols to backtest")
    parser.add_argument("--start",        required=True,
                        help="Event date / window start (YYYY-MM-DD)")
    parser.add_argument("--end",          required=True,
                        help="Window end (YYYY-MM-DD) — must be > start + horizon_days")
    parser.add_argument("--horizon-days", type=int, default=20,
                        help="Return measurement window in trading days")
    parser.add_argument("--benchmark",    default="SPY",
                        help="Benchmark ticker for abnormal-return calculation")
    parser.add_argument("--json",         action="store_true",
                        help="Emit JSON to stdout (summary still printed to stderr)")
    args = parser.parse_args()

    tickers = [t.upper() for t in args.tickers]
    drift_horizons = [1, 3, 5, 10, 15, args.horizon_days]

    print(f"[backtest] Tickers   : {tickers}", file=sys.stderr)
    print(f"[backtest] Window    : {args.start} → {args.end}", file=sys.stderr)
    print(f"[backtest] Horizon   : {args.horizon_days} days", file=sys.stderr)
    print(f"[backtest] Benchmark : {args.benchmark}", file=sys.stderr)

    events: list[dict] = []
    for ticker in tickers:
        result = _run_event(
            ticker=ticker,
            benchmark=args.benchmark.upper(),
            start=args.start,
            end=args.end,
            horizon_days=args.horizon_days,
            drift_horizons=drift_horizons,
        )
        if result is not None:
            events.append(result)

    agg     = _aggregate(events)
    honesty = render_honesty_guards(delisted_coverage=False)

    if args.json:
        # Summary + honesty guards on stderr, clean JSON on stdout
        _print_summary_stderr(events, agg, honesty)
        payload = {
            "meta": {
                "tickers":      tickers,
                "start":        args.start,
                "end":          args.end,
                "horizon_days": args.horizon_days,
                "benchmark":    args.benchmark.upper(),
            },
            "aggregate": agg,
            "events":    events,
            "integrity": honesty.splitlines(),
        }
        print(json.dumps(payload, indent=2, default=str))
    else:
        _print_summary(events, agg, honesty)


def _print_summary_stderr(events: list[dict], agg: dict, honesty: str) -> None:
    """Redirect summary to stderr when --json is active."""
    import sys as _sys
    _orig = _sys.stdout
    _sys.stdout = _sys.stderr
    _print_summary(events, agg, honesty)
    _sys.stdout = _orig


if __name__ == "__main__":
    main()
