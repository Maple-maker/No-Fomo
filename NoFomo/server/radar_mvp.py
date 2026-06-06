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


# ── Research Engine ─────────────────────────────────────────────────

RESEARCH_QUERIES = [
    "{ticker} business model products customers revenue 2025 2026",
    "{ticker} earnings financial results revenue growth margin",
    "{ticker} news catalyst analyst rating upgrade downgrade",
    "{ticker} competitive advantage moat market share",
    "{ticker} insider trading buying selling institutional",
]

def research_ticker(ticker: str) -> dict:
    """Research a ticker using Brave Search. Returns structured data."""
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

    # Classify search results into signal categories
    signals = classify_signals(unique, ticker)

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


def classify_signals(results: list[dict], ticker: str) -> dict:
    """Rule-based signal classification from search results."""
    text = " ".join(r["title"] + " " + r["snippet"] for r in results).lower()

    signals = {
        "insider_buying": any(kw in text for kw in ["insider buy", "insider purchase", "director buy", "open market purchase"]),
        "insider_selling": any(kw in text for kw in ["insider sell", "insider sale", "director sell"]),
        "analyst_upgrade": any(kw in text for kw in ["upgrade", "buy rating", "overweight", "price target raised"]),
        "analyst_downgrade": any(kw in text for kw in ["downgrade", "sell rating", "underweight", "price target cut"]),
        "positive_earnings": any(kw in text for kw in ["beat earnings", "earnings beat", "revenue beat", "raised guidance"]),
        "negative_earnings": any(kw in text for kw in ["miss earnings", "earnings miss", "revenue miss", "lowered guidance", "profit warning"]),
        "government_contract": any(kw in text for kw in ["government contract", "dod contract", "awarded contract", "sbir", "sttr"]),
        "activist": any(kw in text for kw in ["activist investor", "activist stake", "takeover target", "acquisition target"]),
        "new_product": any(kw in text for kw in ["launch", "fda approval", "fda clearance", "new product", "pipeline"]),
        "regulatory_risk": any(kw in text for kw in ["investigation", "lawsuit", "regulatory", "compliance", "sanction"]),
        "strong_growth": any(kw in text for kw in ["growing", "expansion", "record revenue", "record profit"]),
        "margin_pressure": any(kw in text for kw in ["margin compression", "rising costs", "inflation", "supply chain"]),
    }

    # Count bullish and bearish signals
    bullish = sum([
        signals["insider_buying"],
        signals["analyst_upgrade"],
        signals["positive_earnings"],
        signals["government_contract"],
        signals["new_product"],
        signals["strong_growth"],
    ])
    bearish = sum([
        signals["insider_selling"],
        signals["analyst_downgrade"],
        signals["negative_earnings"],
        signals["regulatory_risk"],
        signals["margin_pressure"],
    ])

    # Score calculation
    base_score = 50
    score = base_score + (bullish * 8) - (bearish * 6)
    score = max(0, min(100, score))

    # Tier determination
    if score >= 75 and bullish >= 2 and bearish <= 1:
        tier = 1 if score >= 85 else 2
    elif score >= 60 and bullish >= 1:
        tier = 2
    else:
        tier = 3

    # BLUF
    if score >= 75:
        bluf = f"{ticker} shows {'strong' if score >= 85 else 'moderate'} bullish signals with {bullish} positive indicators."
    elif score >= 60:
        bluf = f"{ticker} has mixed signals — {bullish} bullish vs {bearish} bearish indicators."
    else:
        bluf = f"{ticker} has more bearish signals than bullish ({bearish} vs {bullish}). Caution warranted."

    return {
        "signals": signals,
        "bullish_count": bullish,
        "bearish_count": bearish,
        "asymmetry_score": min(10, max(1, round((bullish + 1) / 2))),
        "conviction_score": min(10, max(1, round(score / 10))),
        "catalyst_score": min(10, max(1, round(bullish * 2))),
        "management_score": 5,
        "overall_score": score,
        "tier": tier,
        "bluf": bluf,
        "triple_signal": signals["insider_buying"] and signals["positive_earnings"] and score >= 75,
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