"""
Stock Price + Technical Analysis — free spike using yfinance.
Fetches real-time price, RSI, MACD, and key metrics for any ticker.

Usage:
    python3 backend/stock_data.py AAPL               # quick snapshot
    python3 backend/stock_data.py AAPL --full         # full TA report
    python3 backend/stock_data.py AAPL MSFT GOOG      # multiple tickers
    python3 backend/stock_data.py AAPL --json          # JSON output
"""

import argparse
import json
import sys

import pandas as pd

# yfinance is free but unofficial — swap to Twelve Data / FMP before production
import yfinance as yf


def compute_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """Compute Relative Strength Index."""
    delta = series.diff()
    gain = delta.where(delta > 0, 0.0)
    loss = (-delta).where(delta < 0, 0.0)
    avg_gain = gain.ewm(alpha=1 / period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / period, min_periods=period, adjust=False).mean()
    rs = avg_gain / avg_loss
    return 100.0 - (100.0 / (1.0 + rs))


def compute_macd(series: pd.Series) -> dict:
    """Compute MACD (12, 26, 9)."""
    ema12 = series.ewm(span=12, adjust=False).mean()
    ema26 = series.ewm(span=26, adjust=False).mean()
    macd_line = ema12 - ema26
    signal = macd_line.ewm(span=9, adjust=False).mean()
    histogram = macd_line - signal
    return {
        "macd": round(float(macd_line.iloc[-1]), 4),
        "signal": round(float(signal.iloc[-1]), 4),
        "histogram": round(float(histogram.iloc[-1]), 4),
        "bullish": bool(histogram.iloc[-1] > 0),
    }


def compute_bollinger(series: pd.Series, period: int = 20) -> dict:
    """Bollinger Bands (2 std dev)."""
    sma = series.rolling(window=period).mean()
    std = series.rolling(window=period).std()
    return {
        "upper": round(float(sma.iloc[-1] + 2 * std.iloc[-1]), 2),
        "middle": round(float(sma.iloc[-1]), 2),
        "lower": round(float(sma.iloc[-1] - 2 * std.iloc[-1]), 2),
    }


def get_snapshot(ticker: str) -> dict:
    """Fetch a quick price + RSI + MACD snapshot."""
    t = yf.Ticker(ticker)
    info = t.info
    hist = t.history(period="6mo")

    if hist.empty:
        return {"ticker": ticker.upper(), "error": "No data returned"}

    close = hist["Close"]
    volume = hist["Volume"]
    last_price = round(float(close.iloc[-1]), 2)
    prev_close = round(float(close.iloc[-2]), 2) if len(close) > 1 else last_price
    change_pct = round((last_price - prev_close) / prev_close * 100, 2) if prev_close else 0

    rsi = compute_rsi(close)
    macd = compute_macd(close)
    bb = compute_bollinger(close)

    avg_vol = int(volume.tail(20).mean())

    return {
        "ticker": ticker.upper(),
        "company": info.get("shortName", info.get("longName", ticker)),
        "sector": info.get("sector", ""),
        "industry": info.get("industry", ""),
        "price": last_price,
        "change_pct": change_pct,
        "prev_close": prev_close,
        "market_cap": _fmt_cap(info.get("marketCap")),
        "pe_trailing": info.get("trailingPE"),
        "pe_forward": info.get("forwardPE"),
        "ps_ttm": info.get("priceToSalesTrailing12Months"),
        "pfcf": info.get("priceToFreeCashflow"),
        "ev_ebitda": info.get("enterpriseToEbitda"),
        "gross_margin": round(info.get("grossMargins", 0) * 100, 1) if info.get("grossMargins") else None,
        "rev_growth_yoy": round(info.get("revenueGrowth", 0) * 100, 1) if info.get("revenueGrowth") else None,
        "beta": info.get("beta"),
        "short_pct": round(info.get("shortPercentOfFloat", 0) * 100, 1) if info.get("shortPercentOfFloat") else None,
        "analyst_count": info.get("numberOfAnalystOpinions"),
        "rsi_14": round(float(rsi.iloc[-1]), 1),
        "rsi_signal": "oversold" if rsi.iloc[-1] < 30 else "overbought" if rsi.iloc[-1] > 70 else "neutral",
        "macd": macd,
        "bollinger": bb,
        "avg_volume": avg_vol,
        "vol_vs_avg": round(int(volume.iloc[-1]) / avg_vol, 2) if avg_vol else None,
        "price_history": [round(float(c), 2) for c in close.tolist()],
    }


def _fmt_cap(cap) -> str:
    if cap is None:
        return "N/A"
    if cap >= 1e12:
        return f"${cap / 1e12:.2f}T"
    if cap >= 1e9:
        return f"${cap / 1e9:.1f}B"
    if cap >= 1e6:
        return f"${cap / 1e6:.0f}M"
    return f"${cap:,.0f}"


def format_terminal(snap: dict) -> str:
    """Pretty-print a snapshot for terminal."""
    if "error" in snap:
        return f"❌ {snap['ticker']}: {snap['error']}"

    rsi = snap["rsi_14"]
    rsi_bar = "█" * int(rsi / 10) + "░" * (10 - int(rsi / 10))
    macd = snap["macd"]
    signal = "📈 BULLISH" if macd["bullish"] else "📉 BEARISH"

    return f"""
${snap['ticker']} — {snap['company']}
{'─' * 50}
  Sector:       {snap['sector']} · {snap['industry']}
  Price:        ${snap['price']}  ({snap['change_pct']:+.2f}%)
  Market Cap:   {snap['market_cap']}
  P/E (TTM):    {snap['pe_trailing'] or 'N/A'}   P/E (Fwd): {snap['pe_forward'] or 'N/A'}
  P/S:          {snap['ps_ttm'] or 'N/A'}        P/FCF:     {snap['pfcf'] or 'N/A'}
  EV/EBITDA:    {snap['ev_ebitda'] or 'N/A'}
  Gross Margin: {snap['gross_margin']}%          Rev Growth: {snap['rev_growth_yoy']}%
  Beta:         {snap['beta']}                   Short:     {snap['short_pct']}%
  Analysts:     {snap['analyst_count']}

  RSI (14):     {rsi}  {rsi_bar}  [{snap['rsi_signal'].upper()}]
  MACD:         {macd['macd']}  Signal: {macd['signal']}  Hist: {macd['histogram']}  {signal}
  Bollinger:    ${snap['bollinger']['lower']} — ${snap['bollinger']['middle']} — ${snap['bollinger']['upper']}
  Avg Volume:   {snap['avg_volume']:,}  (Today: {snap['vol_vs_avg']}x avg)
"""


def main():
    parser = argparse.ArgumentParser(description="Stock Price + TA Snapshot")
    parser.add_argument("tickers", nargs="+", help="Ticker symbol(s)")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    for ticker in args.tickers:
        snap = get_snapshot(ticker)
        if args.json:
            print(json.dumps(snap, indent=2, default=str))
        else:
            print(format_terminal(snap))


if __name__ == "__main__":
    main()
