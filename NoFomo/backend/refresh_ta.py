"""
Refreshes TA + price data for all radar tickers via stock_data.py -> JSON.
Outputs to backend/ta_data.json for consumption by the app or server.

Usage:
    python3 backend/refresh_ta.py                    # all default tickers
    python3 backend/refresh_ta.py --tickers PLTR MSTR # specific tickers
    python3 backend/refresh_ta.py --pretty            # pretty-print to stdout
"""

import argparse
import json
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from backend.stock_data import get_snapshot

WATCHLIST = ["PLTR", "MSTR", "RKLB", "ASTS", "OKLO",
             "NVDA", "AVGO", "KTOS", "RXRX", "SMR"]

OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "ta_data.json")


def refresh(tickers: list[str]) -> list[dict]:
    """Fetch fresh TA data for all tickers, including price history."""
    results = []
    for t in tickers:
        try:
            snap = get_snapshot(t)
            if "error" not in snap:
                # Fetch 90-day price history for sparkline charts
                import yfinance as yf
                try:
                    hist = yf.Ticker(t).history(period="3mo")
                    snap["price_history"] = [round(float(x), 2) for x in hist["Close"].dropna().tolist()[-90:]]
                except Exception:
                    snap["price_history"] = []
                results.append(snap)
            else:
                print(f"  ⚠️ {t}: {snap['error']}", file=sys.stderr)
        except Exception as e:
            print(f"  ❌ {t}: {e}", file=sys.stderr)
    return results


def main():
    parser = argparse.ArgumentParser(description="Refresh TA data for radar tickers")
    parser.add_argument("--tickers", nargs="*", help="Ticker symbols")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print to stdout")
    args = parser.parse_args()

    tickers = args.tickers if args.tickers else WATCHLIST
    data = refresh(tickers)

    output = {
        "refreshed_at": datetime.now().isoformat(),
        "tickers": data,
    }

    if args.pretty:
        print(json.dumps(output, indent=2, default=str))
    else:
        os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
        with open(OUTPUT_PATH, "w") as f:
            json.dump(output, f, indent=2, default=str)
        print(f"✅ {len(data)} tickers written to {OUTPUT_PATH}", file=sys.stderr)


if __name__ == "__main__":
    main()
