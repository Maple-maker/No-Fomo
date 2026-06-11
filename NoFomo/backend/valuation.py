"""
No FOMO — valuation engine.

Auto-fetches the five "look-up" fundamentals for a ticker, then values it with a
discounted-cash-flow model using the three "judgment" inputs you supply.

Design goal: framework-agnostic. fetch_fundamentals() and run_dcf() return plain
dataclasses, so this drops into Streamlit, FastAPI, a CLI, or your screener with
no changes. The data source (yfinance, free, no API key) lives behind one
function — swap fetch_fundamentals() for a paid API later without touching the math.

Quick start:
    python valuation.py AAPL --growth 0.08 --discount 0.09
Or import it:
    from valuation import fetch_fundamentals, run_dcf, Assumptions
    f = fetch_fundamentals("AAPL")
    v = run_dcf(f, Assumptions(growth=0.08, discount=0.09))
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


# ---------------------------------------------------------------------------
# Data containers
# ---------------------------------------------------------------------------

@dataclass
class Fundamentals:
    """The five look-up numbers. Dollar fields are absolute dollars."""
    ticker: str
    price: Optional[float] = None     # current share price
    fcf: Optional[float] = None       # latest annual free cash flow
    cash: Optional[float] = None      # cash & equivalents
    debt: Optional[float] = None      # total interest-bearing debt
    shares: Optional[float] = None    # diluted shares outstanding
    missing: list = field(default_factory=list)   # fields we could not fetch
    notes: list = field(default_factory=list)

    @property
    def complete(self) -> bool:
        return not self.missing


@dataclass
class Assumptions:
    """The three judgment calls (plus sensible defaults you can override)."""
    growth: float                 # stage-1 annual FCF growth, e.g. 0.10 = 10%
    discount: float               # required return / discount rate, e.g. 0.09
    terminal: float = 0.025       # perpetual growth — keep near long-run GDP
    years: int = 10
    margin_of_safety: float = 0.25


@dataclass
class Valuation:
    intrinsic_per_share: float
    price: float
    upside_pct: float
    verdict: str
    buy_below: float
    implied_growth: Optional[float]   # reverse DCF: growth the price assumes
    pv_fcf: float
    pv_terminal: float
    equity_value: float


# ---------------------------------------------------------------------------
# 1. Auto-fetch the five look-up numbers
# ---------------------------------------------------------------------------

def fetch_fundamentals(ticker: str) -> Fundamentals:
    """Pull price, FCF, cash, debt, and shares from yfinance.

    Anything that can't be found is recorded in `.missing` so the caller can
    ask the user to type it in — never silently substitute a wrong/zero value.
    """
    import yfinance as yf

    f = Fundamentals(ticker=ticker.upper())
    tk = yf.Ticker(ticker)

    # `.info` is the most consistent single source; statements are the fallback.
    try:
        info = tk.info or {}
    except Exception as e:
        info = {}
        f.notes.append(f"Could not load .info: {e}")

    def from_info(*keys):
        for k in keys:
            v = info.get(k)
            if v not in (None, 0):
                return float(v)
        return None

    f.price  = from_info("currentPrice", "regularMarketPrice")
    f.fcf    = from_info("freeCashflow")
    f.cash   = from_info("totalCash")
    f.debt   = from_info("totalDebt")
    f.shares = from_info("sharesOutstanding")

    if f.price is None:                       # price backstop
        try:
            f.price = float(tk.fast_info["last_price"])
        except Exception:
            pass

    if f.fcf is None:                         # FCF fallback from statements
        f.fcf = _fcf_from_statements(tk, f)

    for name in ("price", "fcf", "cash", "debt", "shares"):
        if getattr(f, name) is None:
            f.missing.append(name)

    if f.debt == 0:
        f.notes.append("Total debt fetched as 0 — worth verifying on the balance sheet.")
    return f


def _fcf_from_statements(tk, f) -> Optional[float]:
    """FCF = Operating Cash Flow - |Capital Expenditure|, from the cash flow statement."""
    try:
        cf = tk.cashflow
        if cf is None or cf.empty:
            return None
        col = cf.columns[0]                   # most recent reporting period

        def row(*labels):
            for lab in labels:
                if lab in cf.index:
                    val = cf.loc[lab, col]
                    if val == val:            # filters out NaN
                        return float(val)
            return None

        direct = row("Free Cash Flow")
        if direct is not None:
            return direct
        ocf = row("Operating Cash Flow", "Total Cash From Operating Activities")
        capex = row("Capital Expenditure", "Capital Expenditures")
        if ocf is not None and capex is not None:
            return ocf - abs(capex)
    except Exception as e:
        f.notes.append(f"Cash-flow-statement fallback failed: {e}")
    return None


# ---------------------------------------------------------------------------
# 2. The DCF — fundamentals + assumptions -> per-share value
# ---------------------------------------------------------------------------

def _intrinsic(fcf, cash, debt, shares, growth, discount, terminal, years):
    """Core math. Returns (per_share, pv_fcf_sum, pv_terminal, equity_value)."""
    if discount <= terminal:
        raise ValueError("Discount rate must be greater than the perpetual growth rate.")
    pv_fcf = 0.0
    for t in range(1, years + 1):
        cash_flow = fcf * (1 + growth) ** t
        pv_fcf += cash_flow / (1 + discount) ** t
    fcf_final = fcf * (1 + growth) ** years
    terminal_value = fcf_final * (1 + terminal) / (discount - terminal)
    pv_terminal = terminal_value / (1 + discount) ** years
    equity = pv_fcf + pv_terminal + cash - debt
    return equity / shares, pv_fcf, pv_terminal, equity


def run_dcf(f: Fundamentals, a: Assumptions) -> Valuation:
    if not f.complete:
        raise ValueError(
            f"Missing fundamentals: {', '.join(f.missing)}. Supply them before valuing."
        )
    per_share, pv_fcf, pv_term, equity = _intrinsic(
        f.fcf, f.cash, f.debt, f.shares,
        a.growth, a.discount, a.terminal, a.years,
    )
    upside = (per_share / f.price - 1) * 100
    return Valuation(
        intrinsic_per_share=per_share,
        price=f.price,
        upside_pct=upside,
        verdict=_verdict(upside),
        buy_below=per_share * (1 - a.margin_of_safety),
        implied_growth=reverse_dcf(f, a),
        pv_fcf=pv_fcf,
        pv_terminal=pv_term,
        equity_value=equity,
    )


def _verdict(upside_pct: float) -> str:
    if upside_pct > 10:
        return "Undervalued"
    if upside_pct < -10:
        return "Overvalued"
    return "Fairly valued"


# ---------------------------------------------------------------------------
# 3. Reverse DCF — what growth is the current price assuming?
# ---------------------------------------------------------------------------

def reverse_dcf(f: Fundamentals, a: Assumptions) -> Optional[float]:
    """Solve for the stage-1 growth rate that makes intrinsic value == price.

    This is the 'what do I have to believe?' number, usually more useful than
    the forward value. Returns a decimal (0.18 == 18%/yr) or None if the price
    implies growth outside a sane range, or FCF is non-positive.
    """
    if (f.fcf is None or f.fcf <= 0 or f.price is None
            or a.discount <= a.terminal):
        return None

    def value_at(g):
        ps, *_ = _intrinsic(f.fcf, f.cash, f.debt, f.shares,
                            g, a.discount, a.terminal, a.years)
        return ps

    lo, hi = -0.5, 1.5
    if value_at(hi) < f.price or value_at(lo) > f.price:
        return None
    for _ in range(80):                       # binary search; value rises with g
        mid = (lo + hi) / 2
        if value_at(mid) > f.price:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


# ---------------------------------------------------------------------------
# 4. Asymmetry lens — bear / base / bull, for spotting asymmetric bets
# ---------------------------------------------------------------------------

def scenario_analysis(f: Fundamentals, a: Assumptions, spread: float = 0.10) -> dict:
    """Value the company at low / base / high growth and measure the asymmetry.

    `spread` is how far below/above base growth the bear/bull cases sit.
    Returns each scenario plus an asymmetry ratio (bull upside / bear downside);
    a ratio > 1 means more to gain than to lose at today's price.
    """
    out = {}
    for label, g in (("bear", a.growth - spread),
                     ("base", a.growth),
                     ("bull", a.growth + spread)):
        ps, *_ = _intrinsic(f.fcf, f.cash, f.debt, f.shares,
                            g, a.discount, a.terminal, a.years)
        out[label] = {"growth": g, "value": ps, "return_pct": (ps / f.price - 1) * 100}
    downside = abs(min(out["bear"]["return_pct"], 0)) or 1e-9
    upside = max(out["bull"]["return_pct"], 0)
    out["asymmetry_ratio"] = upside / downside
    return out


# ---------------------------------------------------------------------------
# 5. Command-line report:  python valuation.py AAPL --growth 0.08
# ---------------------------------------------------------------------------

def _report(ticker, growth, discount, terminal, years, mos):
    f = fetch_fundamentals(ticker)
    print(f"\n  {f.ticker} — fetched fundamentals")
    print(f"    price   {f.price}")
    print(f"    FCF     {f.fcf}")
    print(f"    cash    {f.cash}")
    print(f"    debt    {f.debt}")
    print(f"    shares  {f.shares}")
    for n in f.notes:
        print("    note:", n)
    if f.missing:
        print(f"    !! could not fetch: {', '.join(f.missing)} — supply these manually.")
        return

    a = Assumptions(growth=growth, discount=discount, terminal=terminal,
                    years=years, margin_of_safety=mos)
    v = run_dcf(f, a)
    print(f"\n  Intrinsic value : ${v.intrinsic_per_share:,.2f}")
    print(f"  Market price    : ${v.price:,.2f}")
    print(f"  Upside          : {v.upside_pct:+.1f}%  ->  {v.verdict}")
    print(f"  Buy below       : ${v.buy_below:,.2f}  ({mos:.0%} margin of safety)")
    if v.implied_growth is not None:
        print(f"  Price implies   : {v.implied_growth * 100:.1f}%/yr growth "
              f"(you assumed {growth * 100:.1f}%)")

    sc = scenario_analysis(f, a)
    print("\n  Scenario        growth     value      vs price")
    for label in ("bear", "base", "bull"):
        s = sc[label]
        print(f"  {label:<5}          {s['growth']*100:5.1f}%   "
              f"${s['value']:>9,.2f}   {s['return_pct']:+6.0f}%")
    print(f"  Asymmetry ratio : {sc['asymmetry_ratio']:.2f}x  (>1 = more upside than downside)\n")


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="No FOMO DCF valuation")
    p.add_argument("ticker")
    p.add_argument("--growth",   type=float, default=0.08, help="stage-1 FCF growth, decimal")
    p.add_argument("--discount", type=float, default=0.09, help="discount rate, decimal")
    p.add_argument("--terminal", type=float, default=0.025, help="perpetual growth, decimal")
    p.add_argument("--years",    type=int,   default=10)
    p.add_argument("--mos",      type=float, default=0.25, help="margin of safety, decimal")
    args = p.parse_args()
    _report(args.ticker, args.growth, args.discount, args.terminal, args.years, args.mos)
