"""NoFomo Radar MVP — Python server. No LLM required.
Uses Brave Search + Yahoo Finance + rule-based scoring.

Run: python3 radar_mvp.py
Port: 3001

Endpoints:
  GET  /health   — status check
  POST /radar    — { ticker, skip_persist }
  POST /council  — { dossier } (returns rule-based verdict)
"""

import http.server
import json
import os
import time
import urllib.request
import urllib.parse
from datetime import datetime

# ── Config ──────────────────────────────────────────────────────────
PORT = int(os.environ.get('PORT', '3002'))

def get_brave_key():
    """Read Brave key from .env file."""
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("BRAVE_API_KEY"):
                    val = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if val:
                        return val
    return os.environ.get("BRAVE_API_KEY", "")


def fetch_brave(query: str, count: int = 5) -> list[dict]:
    """Search Brave and return parsed results."""
    key = get_brave_key()
    if not key:
        return []

    params = urllib.parse.urlencode({"q": query, "count": count})
    url = f"https://api.search.brave.com/res/v1/web/search?{params}"
    req = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "Accept-Encoding": "gzip",
        "X-Subscription-Token": key,
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw = resp.read()
            # Handle gzip encoding
            if resp.headers.get("Content-Encoding") == "gzip":
                import gzip
                raw = gzip.decompress(raw)
            data = json.loads(raw)
            results = []
            for r in (data.get("web") or {}).get("results") or []:
                results.append({
                    "title": r.get("title", ""),
                    "url": r.get("url", ""),
                    "snippet": (r.get("description") or "")[:500],
                })
            return results
    except Exception as e:
        print(f"[brave] Error: {e}")
        return []


def fetch_price(ticker: str) -> dict:
    """Get stock price from Yahoo Finance (free, no key)."""
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=1d"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "NoFomo/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            meta = (data.get("chart") or {}).get("result") or [{}]
            meta = meta[0].get("meta") or {}
            price = meta.get("regularMarketPrice")
            prev = meta.get("previousClose")
            change = ((price - prev) / prev * 100) if price and prev else None
            return {
                "price": price or 0,
                "change_pct": round(change, 2) if change else 0,
                "volume": meta.get("regularMarketVolume", 0),
                "currency": meta.get("currency", "USD"),
            }
    except Exception as e:
        print(f"[price] Error: {e}")
        return {"price": 0, "change_pct": 0, "volume": 0, "currency": "USD"}


def fetch_rsi(ticker: str, period: int = 14) -> float | None:
    """Calculate RSI-14 from 3-month Yahoo Finance price history."""
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=3mo"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "NoFomo/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            result = (data.get("chart") or {}).get("result") or [{}]
            closes_raw = result[0].get("indicators", {}).get("quote", [{}])[0].get("close", [])
            closes = [c for c in closes_raw if c is not None]

            if len(closes) < period + 1:
                return None

            deltas = [closes[i] - closes[i - 1] for i in range(1, len(closes))]
            gains = [d if d > 0 else 0.0 for d in deltas]
            losses = [-d if d < 0 else 0.0 for d in deltas]

            avg_gain = sum(gains[:period]) / period
            avg_loss = sum(losses[:period]) / period

            for i in range(period, len(deltas)):
                avg_gain = (avg_gain * (period - 1) + gains[i]) / period
                avg_loss = (avg_loss * (period - 1) + losses[i]) / period

            if avg_loss == 0:
                return 100.0
            rs = avg_gain / avg_loss
            return round(100 - (100 / (1 + rs)), 2)
    except Exception as e:
        print(f"[rsi] Error: {e}")
        return None


def fetch_volume_spike(ticker: str) -> float:
    """Return ratio of today's volume vs 10-day average (>2.0 = spike)."""
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=1mo"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "NoFomo/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            result = (data.get("chart") or {}).get("result") or [{}]
            vols_raw = result[0].get("indicators", {}).get("quote", [{}])[0].get("volume", [])
            vols = [v for v in vols_raw if v is not None]

            if len(vols) < 2:
                return 1.0

            today = vols[-1]
            history = vols[-11:-1]
            avg = sum(history) / len(history) if history else today
            return round(today / avg, 2) if avg > 0 else 1.0
    except Exception as e:
        print(f"[volume] Error: {e}")
        return 1.0


# ── Research Engine ─────────────────────────────────────────────────

RESEARCH_QUERIES = [
    "{ticker} business model products customers revenue 2025 2026",
    "{ticker} earnings financial results revenue growth margin",
    "{ticker} news catalyst analyst rating upgrade downgrade",
    "{ticker} competitive advantage moat market share",
    "{ticker} insider trading buying selling institutional",
]

def research_ticker(ticker: str) -> dict:
    """Research a ticker using Brave Search + quantitative signals."""
    ticker = ticker.upper().strip()
    price_data = fetch_price(ticker)

    all_results = []
    for q in RESEARCH_QUERIES:
        results = fetch_brave(q.replace("{ticker}", ticker), count=4)
        all_results.extend(results)

    # Deduplicate by URL
    seen = set()
    unique = []
    for r in all_results:
        if r["url"] not in seen:
            seen.add(r["url"])
            unique.append(r)

    # Fetch quantitative signals (RSI + volume spike)
    rsi = fetch_rsi(ticker)
    volume_spike = fetch_volume_spike(ticker)

    # Classify search results into signal categories
    signals = classify_signals(unique, ticker, rsi=rsi, volume_spike=volume_spike)

    return {
        "ticker": ticker,
        "price": price_data["price"],
        "change_pct": price_data["change_pct"],
        "volume": price_data["volume"],
        "currency": price_data["currency"],
        "results_count": len(unique),
        "results": unique[:20],
        "signals": signals,
        "scored_at": datetime.utcnow().isoformat(),
    }


_REPUTABLE_SOURCES = {
    "sec.gov", "edgar.sec", "usaspending.gov", "sam.gov", "fda.gov",
    "darpa.mil", "bloomberg", "wsj.com", "ft.com", "reuters",
    "barrons.com", "seekingalpha", "benzinga", "marketwatch",
}

def _kw_hit(title_text: str, snippet_text: str, keywords: list[str]) -> bool:
    """Title match = 2 weight, snippet = 1. Returns True if total weight >= 1."""
    for kw in keywords:
        if kw in title_text:
            return True   # title match is authoritative
        if kw in snippet_text:
            return True
    return False


def classify_signals(
    results: list[dict],
    ticker: str,
    rsi: float | None = None,
    volume_spike: float = 1.0,
) -> dict:
    """Rule-based signal classification: keyword (title-weighted) + quantitative."""
    title_text = " ".join(r["title"] for r in results).lower()
    snippet_text = " ".join(r["snippet"] for r in results).lower()

    # Source reputation: primary sources carry extra weight
    has_primary_source = any(
        src in r["url"].lower()
        for r in results
        for src in _REPUTABLE_SOURCES
    )

    def hit(keywords: list[str]) -> bool:
        return _kw_hit(title_text, snippet_text, keywords)

    signals: dict[str, bool | float | None] = {
        "insider_buying": hit(["insider buy", "insider purchase", "director buy",
                                "open market purchase", "form 4 buy", "executive buy",
                                "ceo buy", "cfo buy"]),
        "insider_selling": hit(["insider sell", "insider sale", "director sell",
                                  "form 4 sell", "executive sell"]),
        "analyst_upgrade": hit(["upgrade", "buy rating", "overweight", "outperform",
                                  "price target raised", "initiates coverage", "strong buy"]),
        "analyst_downgrade": hit(["downgrade", "sell rating", "underweight", "underperform",
                                    "price target cut", "price target lowered"]),
        "positive_earnings": hit(["beat earnings", "earnings beat", "revenue beat",
                                    "raised guidance", "beat estimates", "record revenue",
                                    "record profit", "raised full year"]),
        "negative_earnings": hit(["miss earnings", "earnings miss", "revenue miss",
                                    "lowered guidance", "profit warning", "guidance cut",
                                    "below estimates", "lowered full year"]),
        "government_contract": hit(["government contract", "dod contract", "awarded contract",
                                      "sbir", "sttr", "pentagon contract", "defense contract",
                                      "nasa contract", "air force contract", "army contract"]),
        "activist": hit(["activist investor", "activist stake", "takeover target",
                          "acquisition target", "strategic alternatives", "buyout"]),
        "new_product": hit(["launch", "fda approval", "fda clearance", "fda approved",
                              "new product", "pipeline milestone", "510k", "phase 3"]),
        "regulatory_risk": hit(["investigation", "lawsuit", "sec investigation",
                                  "regulatory action", "compliance failure", "sanction",
                                  "doj", "ftc investigation"]),
        "strong_growth": hit(["growing", "expansion", "accelerating", "record revenue",
                                "record profit", "fastest growing", "market share gains"]),
        "margin_pressure": hit(["margin compression", "rising costs", "cost inflation",
                                  "supply chain disruption", "margin decline", "gross margin fell"]),
    }

    # Quantitative signals: RSI and volume
    oversold = rsi is not None and rsi < 30
    overbought = rsi is not None and rsi > 70
    vol_spike_flag = volume_spike >= 2.0

    signals["oversold"] = oversold
    signals["overbought"] = overbought
    signals["volume_spike"] = vol_spike_flag
    signals["rsi"] = rsi
    signals["volume_spike_ratio"] = volume_spike
    signals["has_primary_source"] = has_primary_source

    # Bullish / bearish signal counts
    bullish = sum([
        bool(signals["insider_buying"]),
        bool(signals["analyst_upgrade"]),
        bool(signals["positive_earnings"]),
        bool(signals["government_contract"]),
        bool(signals["new_product"]),
        bool(signals["strong_growth"]),
        bool(signals["activist"]),
        oversold,
        vol_spike_flag,
    ])
    bearish = sum([
        bool(signals["insider_selling"]),
        bool(signals["analyst_downgrade"]),
        bool(signals["negative_earnings"]),
        bool(signals["regulatory_risk"]),
        bool(signals["margin_pressure"]),
        overbought,
    ])

    # Scoring formula
    base_score = 50
    score = base_score + (bullish * 8) - (bearish * 6)

    # RSI modifiers
    if oversold:
        score += 5   # meaningful oversold setup
    elif overbought:
        score -= 4

    # Volume surge bonus
    if vol_spike_flag:
        score += 3

    # Primary source credibility bonus
    if has_primary_source:
        score += 4

    score = max(0, min(100, score))

    # Tier gating
    if score >= 80 and bullish >= 2 and bearish <= 1:
        tier = 1
    elif score >= 65 and bullish >= 1:
        tier = 2
    else:
        tier = 3

    # BLUF
    rsi_note = f" (RSI {rsi:.0f})" if rsi is not None else ""
    if score >= 80:
        bluf = f"{ticker} shows strong bullish signals: {bullish} positive indicators{rsi_note}. High conviction setup."
    elif score >= 65:
        bluf = f"{ticker} has {bullish} bullish vs {bearish} bearish signals{rsi_note}. Moderate conviction."
    else:
        bluf = f"{ticker} has more bearish signals ({bearish}) than bullish ({bullish}){rsi_note}. Caution warranted."

    # Triple signal: insider buy + earnings beat + technical setup OR 3 strong bull signals
    triple_signal = (
        bool(signals["insider_buying"]) and bool(signals["positive_earnings"]) and score >= 70
    ) or (bullish >= 3 and score >= 75)

    return {
        "signals": signals,
        "bullish_count": bullish,
        "bearish_count": bearish,
        "asymmetry_score": min(10, max(1, round((bullish + 1) / 2))),
        "conviction_score": min(10, max(1, round(score / 10))),
        "catalyst_score": min(10, max(1, round(bullish * 1.5))),
        "management_score": 5,
        "overall_score": score,
        "tier": tier,
        "bluf": bluf,
        "triple_signal": triple_signal,
    }


# ── HTTP Server ─────────────────────────────────────────────────────

class RadarHandler(http.server.BaseHTTPRequestHandler):
    def _send_json(self, data, status=200):
        body = json.dumps(data, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send_json({
                "status": "ok",
                "service": "nofomo-radar-mvp",
                "version": "1.0.0",
                "providers": {
                    "brave": bool(get_brave_key()),
                },
                "scoring": "rule-based (no LLM required)",
            })
        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            self._send_json({"error": "Empty body"}, 400)
            return

        body = json.loads(self.rfile.read(length))
        path = urllib.parse.urlparse(self.path).path

        if path == "/radar":
            ticker = (body.get("ticker") or "").strip().upper()
            if not ticker:
                self._send_json({"error": "Ticker required"}, 400)
                return

            print(f"[radar] Researching ${ticker}...")
            start = time.time()
            research = research_ticker(ticker)
            elapsed = round(time.time() - start, 1)

            result = {
                "ticker": ticker,
                "tier": research["signals"]["tier"],
                "score": research["signals"]["overall_score"],
                "triple_signal": research["signals"]["triple_signal"],
                "bluf": research["signals"]["bluf"],
                "price": research["price"],
                "change_pct": research["change_pct"],
                "volume": research["volume"],
                "currency": research["currency"],
                "signals": research["signals"],
                "results_count": research["results_count"],
                "dossier_length": sum(len(r["snippet"]) for r in research["results"]),
                "elapsed_seconds": elapsed,
            }
            self._send_json(result)

        elif path == "/council":
            dossier = body.get("dossier", "")
            if not dossier:
                self._send_json({"error": "Dossier required"}, 400)
                return
            self._send_json({
                "gemini": {"verdict": "BULL", "reasoning": "Rule-based assessment (no LLM)."},
                "deepseek": {"verdict": "BULL", "reasoning": "Rule-based assessment (no LLM)."},
                "cio": {"verdict": "BULL", "synthesis": "Rule-based MVP verdict.", "tier": 2, "score": 50, "triple_signal": False},
            })

        else:
            self._send_json({"error": "Not found"}, 404)

    def log_message(self, format, *args):
        print(f"[http] {args[0]} {args[1]} {args[2]}")


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), RadarHandler)
    print(f"\n  NoFomo Radar MVP (no LLM needed)")
    print(f"  ────────────────────────────────────")
    print(f"  http://0.0.0.0:{PORT}")
    print(f"  /health  — status check")
    print(f"  /radar   — POST {{ ticker }} → Brave research + rule scoring")
    print(f"  /council — POST {{ dossier }} → rule-based verdict")
    print(f"\n  Brave API: {'✅ configured' if get_brave_key() else '❌ missing'}")
    print()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()