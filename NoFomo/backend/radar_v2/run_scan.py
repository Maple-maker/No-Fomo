import argparse
import json
from datetime import datetime, timedelta, timezone
from typing import Callable

from radar_v2.engine.score import score_ticker
from radar_v2.signals.adapters import form4_insider, sec_8k
from radar_v2.signals.schema import Signal


AdapterFetcher = Callable[[list[str] | None, datetime], list[Signal]]


def run_scan(
    tickers: list[str],
    *,
    now: datetime | None = None,
    since: datetime | None = None,
    adapter_fetchers: list[AdapterFetcher] | None = None,
    dry_run: bool = True,
) -> dict:
    now = now or datetime.now(timezone.utc)
    since = since or now - timedelta(days=30)
    adapter_fetchers = adapter_fetchers or [sec_8k.fetch, form4_insider.fetch]

    all_signals: list[Signal] = []
    for fetcher in adapter_fetchers:
        all_signals.extend(fetcher(tickers, since))

    results = []
    for ticker in tickers:
        ticker_signals = [sig for sig in all_signals if sig.ticker.upper() == ticker.upper()]
        results.append(score_ticker(ticker, ticker_signals, now=now))

    return {"dry_run": dry_run, "results": results}


def main() -> None:
    parser = argparse.ArgumentParser(description="RADAR V2 dry-run scanner")
    parser.add_argument("--tickers", nargs="+", required=True)
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true", default=True)
    args = parser.parse_args()
    now = datetime.now(timezone.utc)
    result = run_scan(
        args.tickers,
        now=now,
        since=now - timedelta(days=args.days),
        dry_run=args.dry_run,
    )
    print(json.dumps(result, indent=2, default=str))


if __name__ == "__main__":
    main()
