"""
Earnings Calendar Scraper — uses yfinance for earnings dates (free).
Fetches upcoming earnings dates, historical surprise data, and next report estimates.

Usage:
    python3 backend/earnings_scraper.py                    # default watchlist
    python3 backend/earnings_scraper.py --tickers AAPL MSFT  # specific tickers
    python3 backend/earnings_scraper.py --json              # JSON output
    python3 backend/earnings_scraper.py --upcoming-only     # only future earnings
"""

import argparse
import json
import math
import sys
from datetime import datetime, timedelta

import yfinance as yf

DEFAULT_TICKERS = [
    "PLTR", "MSTR", "RKLB", "ASTS", "OKLO",
    "NVDA", "AVGO", "KTOS", "SMR", "RXRX",
]


def get_earnings(ticker: str) -> dict | None:
    """Fetch earnings data for a ticker via yfinance."""
    try:
        t = yf.Ticker(ticker)
        info = t.info

        next_date = info.get("earningsDate")
        if isinstance(next_date, list) and next_date:
            next_date = datetime.fromtimestamp(next_date[0]).strftime("%Y-%m-%d")
        elif next_date:
            next_date = str(next_date)

        return {
            "ticker": ticker.upper(),
            "company": info.get("shortName", info.get("longName", ticker)),
            "next_earnings_date": next_date,
            "earnings_quarterly_growth": info.get("earningsQuarterlyGrowth"),
            "earnings_per_share": info.get("trailingEps"),
            "revenue_per_share": info.get("revenuePerShare"),
            "earnings_calendar": _get_calendar(t),
            "scraped_at": datetime.now().isoformat(),
        }
    except Exception as e:
        return {"ticker": ticker.upper(), "error": str(e)}


def _get_calendar(ticker: yf.Ticker) -> list[dict]:
    """Get earnings calendar from yfinance."""
    try:
        cal = ticker.earnings_dates
        if cal is None or cal.empty:
            return []
        events = []
        for dt, row in cal.head(6).iterrows():
            events.append({
                "date": dt.strftime("%Y-%m-%d") if hasattr(dt, "strftime") else str(dt),
                "eps_estimate": _safe_float(row.get("EPS Estimate")),
                "reported_eps": _safe_float(row.get("Reported EPS")),
                "surprise_pct": _safe_float(row.get("Surprise(%)")),
            })
        return events
    except Exception:
        return []


def _safe_float(val) -> float | None:
    try:
        f = float(val)
        return None if math.isnan(f) or math.isinf(f) else round(f, 2)
    except (TypeError, ValueError):
        return None


def scan(tickers: list[str] | None = None) -> list[dict]:
    """Scan all tickers for earnings data."""
    if tickers is None:
        tickers = DEFAULT_TICKERS
    results = []
    print(f"📅 Fetching earnings data for {len(tickers)} tickers...", file=sys.stderr)
    for t in tickers:
        data = get_earnings(t)
        if data and "error" not in data:
            results.append(data)
    results.sort(key=lambda r: r.get("next_earnings_date") or "9999")
    return results


def format_terminal(results: list[dict]) -> str:
    """Pretty-print earnings calendar."""
    lines = ["\n📅 Earnings Calendar\n"]
    for r in results:
        next_date = r.get("next_earnings_date") or "TBD"
        growth = r.get("earnings_quarterly_growth")
        growth_str = f" {growth:+.1%}" if growth else ""
        lines.append(f"  ${r['ticker']:<6} {r['company'][:35]:<35} Next: {next_date}{growth_str}")
        for ev in r.get("earnings_calendar", [])[:3]:
            surprise = ev.get("surprise_pct")
            surprise_str = f" [surprise: {surprise:+.1f}%]" if surprise is not None else ""
            eps = ev.get("reported_eps") or ev.get("eps_estimate") or ""
            lines.append(f"           {ev['date']}  EPS: {eps}{surprise_str}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Earnings Calendar Scraper (yfinance)")
    parser.add_argument("--tickers", nargs="*", help="Ticker symbols")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    tickers = args.tickers if args.tickers else DEFAULT_TICKERS
    results = scan(tickers=tickers)

    if args.json:
        print(json.dumps(results, indent=2, default=str))
    else:
        print(format_terminal(results))


if __name__ == "__main__":
    main()
