"""
No FOMO — InvestingPro-style screener.

Runs each ticker through three data sources (DCF valuation, multiples/growth,
insider cluster) and filters/ranks survivors by user-supplied thresholds.

Usage:
    python3 backend/screener.py --tickers PLTR NVDA AVAV --dcf-upside-min 20 --json
    python3 backend/screener.py --dcf-upside-min 15 --rev-growth-min 10 --require-insider-cluster
    python3 backend/screener.py --help

Design rules:
  - Never crash the whole run — ticker errors are caught, ticker is skipped.
  - Readable table always printed to stderr; JSON to stdout when --json.
  - Default assumptions (growth, discount, etc.) are intentionally conservative.
  - Cap on universe size is printed if the list is truncated.

Exit codes: 0 = success (even if zero tickers pass the filter).
"""

from __future__ import annotations

import argparse
import json
import sys
import os
from typing import Optional

# ---------------------------------------------------------------------------
# Default universe — mirrors insider_scraper.py default + key asymmetric names
# ---------------------------------------------------------------------------
DEFAULT_TICKERS = [
    "PLTR", "MSTR", "RKLB", "ASTS", "OKLO",
    "NVDA", "AVAV", "KTOS", "AMD", "MRVL",
    "CEG", "VST", "COIN", "HOOD",
    "SMCI", "LUNR", "RDW", "RXRX",
]

# How many tickers we will actually process (prevents runaway yfinance calls)
UNIVERSE_CAP = 50

# ---------------------------------------------------------------------------
# DCF defaults — conservative but not punitive
# ---------------------------------------------------------------------------
DCF_GROWTH    = 0.10   # 10% FCF growth (stage 1)
DCF_DISCOUNT  = 0.09   # 9% required return
DCF_TERMINAL  = 0.025  # 2.5% perpetual growth
DCF_YEARS     = 10
DCF_MOS       = 0.25   # 25% margin of safety


# ---------------------------------------------------------------------------
# Ensure backend/ is on sys.path so sibling modules import correctly.
# This handles both `python3 screener.py` (CWD = backend/) and
# `python3 backend/screener.py` (CWD = project root) invocations.
# ---------------------------------------------------------------------------
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import valuation as _valuation_mod        # noqa: E402 — path set above
import stock_data as _stock_data_mod      # noqa: E402
import insider_scraper as _insider_mod    # noqa: E402


def _import_valuation():
    return _valuation_mod


def _import_stock_data():
    return _stock_data_mod


def _import_insider_scraper():
    return _insider_mod


# ---------------------------------------------------------------------------
# Per-ticker data gathering
# ---------------------------------------------------------------------------

def _dcf_upside(ticker: str, val_mod) -> Optional[float]:
    """Run DCF on ticker; return upside_pct or None on failure."""
    try:
        f = val_mod.fetch_fundamentals(ticker)
        if not f.complete:
            print(f"  [screener] {ticker}: DCF missing {f.missing} — skipping DCF", file=sys.stderr)
            return None
        a = val_mod.Assumptions(
            growth=DCF_GROWTH, discount=DCF_DISCOUNT,
            terminal=DCF_TERMINAL, years=DCF_YEARS,
            margin_of_safety=DCF_MOS,
        )
        v = val_mod.run_dcf(f, a)
        return v.upside_pct
    except Exception as e:
        print(f"  [screener] {ticker}: DCF error — {e}", file=sys.stderr)
        return None


def _multiples(ticker: str, sd_mod) -> Optional[dict]:
    """Fetch multiples + rev growth via stock_data.get_snapshot(); return dict or None."""
    try:
        snap = sd_mod.get_snapshot(ticker)
        if "error" in snap:
            print(f"  [screener] {ticker}: stock_data error — {snap['error']}", file=sys.stderr)
            return None
        return snap
    except Exception as e:
        print(f"  [screener] {ticker}: stock_data exception — {e}", file=sys.stderr)
        return None


def _insider_cluster(ticker: str, ins_mod) -> Optional[dict]:
    """Fetch insider signal for a single ticker; return cluster dict or None."""
    try:
        results = ins_mod.scan(tickers=[ticker], days=30)
        if results:
            r = results[0]
            return {
                "signal": r.get("cluster_signal", "none"),
                "buy_count": r.get("buy_count_30d", 0),
                "net_value": r.get("net_value_30d", 0),
                "ceo_buy": r.get("ceo_buy", False),
            }
        # No Form 4 activity found — signal is effectively "none"
        return {"signal": "none", "buy_count": 0, "net_value": 0, "ceo_buy": False}
    except Exception as e:
        print(f"  [screener] {ticker}: insider error — {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Composite rank score (tie-break when DCF upside is equal)
# ---------------------------------------------------------------------------

def _composite_score(row: dict) -> float:
    """
    Weighted composite for ranking. DCF upside is the primary sort key (handled
    externally); this score is used as a tie-break and printed for transparency.

      40% — DCF upside (normalised to 0-100 over a 0-100% range)
      30% — revenue growth YoY (normalised to 0-100 over a 0-50% range)
      20% — insider cluster (strong=1, weak=0.5, none=0)
      10% — RSI signal (oversold bonus)
    """
    dcf      = max(0.0, min(row.get("dcf_upside_pct", 0), 100)) / 100
    rev_g    = max(0.0, min(row.get("rev_growth_yoy", 0) or 0, 50)) / 50
    insider  = {"strong": 1.0, "weak": 0.5, "none": 0.0}.get(row.get("insider_signal", "none"), 0.0)
    rsi_val  = row.get("rsi_14") or 50
    rsi_b    = 1.0 if rsi_val < 30 else (0.5 if rsi_val < 45 else 0.0)

    return round((0.40 * dcf + 0.30 * rev_g + 0.20 * insider + 0.10 * rsi_b) * 100, 1)


# ---------------------------------------------------------------------------
# Core screener
# ---------------------------------------------------------------------------

def screen(
    tickers: list[str],
    dcf_upside_min: float = 0.0,
    rev_growth_min: Optional[float] = None,
    max_pe: Optional[float] = None,
    require_insider_cluster: bool = False,
) -> list[dict]:
    """
    Screen *tickers* and return ranked list of dicts that pass all filters.

    Each dict has:
      ticker, company, price, dcf_upside_pct, intrinsic_per_share,
      rev_growth_yoy, pe_trailing, pe_forward, ps_ttm, pfcf, ev_ebitda,
      gross_margin, rsi_14, insider_signal, insider_buy_count,
      insider_net_value, ceo_buy, composite_score, pass_reason
    """
    # Enforce universe cap
    if len(tickers) > UNIVERSE_CAP:
        print(f"[screener] NOTE: universe capped at {UNIVERSE_CAP} tickers "
              f"(provided {len(tickers)}; first {UNIVERSE_CAP} used).", file=sys.stderr)
        tickers = tickers[:UNIVERSE_CAP]

    print(f"[screener] Universe: {len(tickers)} tickers", file=sys.stderr)
    print(f"[screener] Filters  : DCF upside >= {dcf_upside_min}%"
          + (f"  rev_growth >= {rev_growth_min}%" if rev_growth_min is not None else "")
          + (f"  PE <= {max_pe}" if max_pe is not None else "")
          + ("  require insider cluster" if require_insider_cluster else ""),
          file=sys.stderr)

    # Load modules once
    val_mod = _import_valuation()
    sd_mod  = _import_stock_data()
    ins_mod = _import_insider_scraper()

    results = []

    for i, ticker in enumerate(tickers):
        ticker = ticker.upper()
        print(f"  [{i+1}/{len(tickers)}] {ticker} ...", file=sys.stderr)

        # --- DCF -------------------------------------------------------
        dcf_upside = _dcf_upside(ticker, val_mod)
        if dcf_upside is None:
            # We can still screen on multiples; DCF filter below will gate
            dcf_upside = float("-inf")

        # Apply DCF filter early to skip multiples + insider fetch when unneeded
        if dcf_upside < dcf_upside_min:
            print(f"    {ticker}: DCF upside {dcf_upside:.1f}% < {dcf_upside_min}% — filtered out", file=sys.stderr)
            continue

        # --- Multiples / growth ----------------------------------------
        snap = _multiples(ticker, sd_mod)
        if snap is None:
            print(f"    {ticker}: no market data — skipping", file=sys.stderr)
            continue

        rev_growth = snap.get("rev_growth_yoy")
        pe_trailing = snap.get("pe_trailing")

        if rev_growth_min is not None and (rev_growth is None or rev_growth < rev_growth_min):
            print(f"    {ticker}: rev growth {rev_growth}% < {rev_growth_min}% — filtered out", file=sys.stderr)
            continue

        if max_pe is not None and pe_trailing is not None and pe_trailing > max_pe:
            print(f"    {ticker}: P/E {pe_trailing} > {max_pe} — filtered out", file=sys.stderr)
            continue

        # --- Insider cluster -------------------------------------------
        insider = _insider_cluster(ticker, ins_mod)
        insider_signal   = insider.get("signal", "none") if insider else "none"
        insider_buy_count = insider.get("buy_count", 0) if insider else 0
        insider_net_value = insider.get("net_value", 0) if insider else 0
        ceo_buy           = insider.get("ceo_buy", False) if insider else False

        if require_insider_cluster and insider_signal != "strong":
            print(f"    {ticker}: insider signal '{insider_signal}' (require strong) — filtered out", file=sys.stderr)
            continue

        # --- Passed all filters ----------------------------------------
        row = {
            "ticker":              ticker,
            "company":             snap.get("company", ticker),
            "sector":              snap.get("sector", ""),
            "price":               snap.get("price"),
            "dcf_upside_pct":      round(dcf_upside, 1),
            "rev_growth_yoy":      rev_growth,
            "pe_trailing":         pe_trailing,
            "pe_forward":          snap.get("pe_forward"),
            "ps_ttm":              snap.get("ps_ttm"),
            "pfcf":                snap.get("pfcf"),
            "ev_ebitda":           snap.get("ev_ebitda"),
            "gross_margin":        snap.get("gross_margin"),
            "rsi_14":              snap.get("rsi_14"),
            "rsi_signal":          snap.get("rsi_signal"),
            "beta":                snap.get("beta"),
            "short_pct":           snap.get("short_pct"),
            "analyst_count":       snap.get("analyst_count"),
            "market_cap":          snap.get("market_cap"),
            "insider_signal":      insider_signal,
            "insider_buy_count":   insider_buy_count,
            "insider_net_value":   insider_net_value,
            "ceo_buy":             ceo_buy,
        }
        row["composite_score"] = _composite_score(row)
        results.append(row)
        print(f"    {ticker}: PASS  DCF={dcf_upside:.1f}%  rev={rev_growth}%  insider={insider_signal}  composite={row['composite_score']}", file=sys.stderr)

    # Sort: primary = DCF upside desc, tie-break = composite_score desc
    results.sort(key=lambda r: (-(r["dcf_upside_pct"] or 0), -(r["composite_score"] or 0)))

    print(f"\n[screener] {len(results)} tickers passed all filters.", file=sys.stderr)
    return results


# ---------------------------------------------------------------------------
# Human-readable table (stdout when not --json, always printed to stderr when --json)
# ---------------------------------------------------------------------------

def _print_table(results: list[dict]) -> None:
    if not results:
        print("\n  No tickers passed the filters.\n")
        return

    header = f"\n{'#':<4} {'TICKER':<8} {'PRICE':>8} {'DCF UPS':>9} {'REV GRW':>9} {'P/E':>7} {'INSIDER':<10} {'SCORE':>7}"
    print(header)
    print("─" * len(header))
    for i, r in enumerate(results, 1):
        print(
            f"{i:<4} {r['ticker']:<8} "
            f"{'$'+str(r['price']):>8} "
            f"{str(r['dcf_upside_pct'])+'%':>9} "
            f"{str(r['rev_growth_yoy'])+'%' if r['rev_growth_yoy'] is not None else 'N/A':>9} "
            f"{str(r['pe_trailing']) if r['pe_trailing'] is not None else 'N/A':>7} "
            f"{r['insider_signal']:<10} "
            f"{r['composite_score']:>7}"
        )
    print()


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="No FOMO screener — DCF + multiples + insider filter",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--tickers", nargs="+",
        help="Ticker symbols to screen (default: built-in watchlist)",
    )
    parser.add_argument(
        "--dcf-upside-min", type=float, default=20.0,
        help="Minimum DCF upside %% to pass (e.g. 20 = +20%%)",
    )
    parser.add_argument(
        "--rev-growth-min", type=float, default=None,
        help="Minimum revenue growth YoY %% (e.g. 10)",
    )
    parser.add_argument(
        "--max-pe", type=float, default=None,
        help="Maximum trailing P/E ratio (e.g. 50)",
    )
    parser.add_argument(
        "--require-insider-cluster", action="store_true",
        help="Only pass tickers with a strong insider cluster (3+ buys in 30 days)",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Emit ranked JSON array to stdout (table still printed to stderr)",
    )
    args = parser.parse_args()

    tickers = args.tickers if args.tickers else DEFAULT_TICKERS

    results = screen(
        tickers=tickers,
        dcf_upside_min=args.dcf_upside_min,
        rev_growth_min=args.rev_growth_min,
        max_pe=args.max_pe,
        require_insider_cluster=args.require_insider_cluster,
    )

    # Always print the table (to stderr when --json so stdout stays parseable)
    if args.json:
        _print_table_stderr(results)
        print(json.dumps(results, indent=2, default=str))
    else:
        _print_table(results)


def _print_table_stderr(results: list[dict]) -> None:
    """Same as _print_table but goes to stderr (used when --json is active)."""
    if not results:
        print("\n  No tickers passed the filters.\n", file=sys.stderr)
        return

    header = f"\n{'#':<4} {'TICKER':<8} {'PRICE':>8} {'DCF UPS':>9} {'REV GRW':>9} {'P/E':>7} {'INSIDER':<10} {'SCORE':>7}"
    print(header, file=sys.stderr)
    print("─" * len(header), file=sys.stderr)
    for i, r in enumerate(results, 1):
        print(
            f"{i:<4} {r['ticker']:<8} "
            f"{'$'+str(r['price']):>8} "
            f"{str(r['dcf_upside_pct'])+'%':>9} "
            f"{str(r['rev_growth_yoy'])+'%' if r['rev_growth_yoy'] is not None else 'N/A':>9} "
            f"{str(r['pe_trailing']) if r['pe_trailing'] is not None else 'N/A':>7} "
            f"{r['insider_signal']:<10} "
            f"{r['composite_score']:>7}",
            file=sys.stderr,
        )
    print(file=sys.stderr)


if __name__ == "__main__":
    main()
