---
description: Build the 9 alpha-signal scrapers. Hermes dispatches this to build backend scrapers for insider trading, government contracts, 13F holdings, FDA calendar, short flow, patents, congress, underfollowed screening, spin-offs, and social sentiment. Excludes X/Twitter API.
mode: skill
---

# Alpha Scraper Build — Hermes Dispatch

## Mission

Build 9 backend Python scrapers that feed structured alpha signals into the NoFomo subagent council. Each scraper follows the same pattern as `backend/stock_data.py` and `backend/sec_scanner.py`: CLI with `--tickers` and `--json` flags, `requests`-based, rate-limit-aware, SQLite-cached.

**You are not writing these one by one.** Dispatch them in parallel where dependencies allow. The spec below is complete — each subagent should receive the exact schema, data source, and alpha signals to compute.

---

## Shared Pattern for Every Scraper

Every scraper file in `backend/` must follow this template:

```python
"""
<one-line description>
Usage:
    python3 backend/<name>.py                    # scan defaults/watchlist
    python3 backend/<name>.py --tickers AAPL MSFT  # specific tickers
    python3 backend/<name>.py --days 30            # lookback window
    python3 backend/<name>.py --json               # JSON output
"""
import argparse, json, sqlite3, sys, time, os
from datetime import datetime, timedelta
import requests

CACHE_DIR = os.path.join(os.path.dirname(__file__), "..", ".cache")
DB_PATH = os.path.join(CACHE_DIR, "alpha.db")
USER_AGENT = "NoFomo Research (nofomo@example.com)"

def init_cache():
    os.makedirs(CACHE_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    # CREATE TABLE IF NOT EXISTS per scraper
    return conn

# main() with argparse: --tickers, --days, --json
```

**Rules for every scraper:**
- All HTTP requests include `headers={"User-Agent": USER_AGENT}`
- Rate limit: minimum 0.12s between requests to the same host
- Cache results in the shared SQLite `DB_PATH`; check cache before hitting the network
- `--json` flag prints JSON array to stdout, no other output
- Without `--json`, pretty-print a terminal summary
- `--tickers` accepts space-separated list; if omitted, scan a hardcoded default watchlist relevant to that scraper's domain
- `--days` controls lookback window, default varies per scraper
- Every function has a docstring

---

## Scraper 1: Insider Trading — `backend/insider_scraper.py`

**Priority:** Highest. This is the #1 alpha signal.

**Data source:** SEC EDGAR submissions API + Form 4 XML
- CIK lookup: `https://www.sec.gov/files/company_tickers.json` (cache this, refresh weekly)
- Filing index: `https://data.sec.gov/submissions/CIK{cik}.json`
- Form 4 detail: Parse the `primaryDocument` URL from the filing index entry
- Rate limit: 10 req/sec to `data.sec.gov`. Add 0.12s sleep between tickers.

**What to extract from each Form 4:**
- Filer name (rptOwnerName), relationship (officer/director/10% owner), title (CEO/CFO/etc.)
- Transaction date, transaction code (`P` = open-market buy, `S` = open-market sale, `A` = grant/award, `F` = tax withholding)
- Shares transacted, price per share, total value (shares × price)
- `is_10b5_1` — check for "10b5-1" in the footnotes or transaction description. If found, flag it but do NOT count it as a cluster signal.
- Post-transaction holdings (sharesOwnedFollowingTransaction)
- Filing URL (build from CIK + accession number)

**Output JSON schema:**
```json
{
  "ticker": "CRVO",
  "transactions": [
    {
      "filer": "John Smith",
      "role": "CEO",
      "date": "2026-05-28",
      "code": "P",
      "shares": 50000,
      "price": 34.00,
      "value": 1700000,
      "is_10b5_1": false,
      "post_holdings": 2500000,
      "filing_url": "https://www.sec.gov/Archives/edgar/data/..."
    }
  ],
  "cluster_signal": "strong",
  "cluster_detail": "3 open-market buys by CEO, CFO, Director within 14 days",
  "buy_count_30d": 4,
  "sell_count_30d": 0,
  "net_value_30d": 6800000,
  "scraped_at": "2026-06-05T19:00:00Z"
}
```

**Alpha signals to compute:**
- **cluster_signal** — `"strong"` if 3+ open-market buys (`P`) by C-suite/directors (NOT 10b5-1) within 30 days. `"weak"` if 2 buys. `"none"` otherwise.
- **Cluster score** — integer 0-100. 3 buys = 70, 4+ = 85, CEO buying personally = +10, all within 14 days = +5 bonus. Sales (`S`) do not reduce the score (they have too many benign explanations).
- **CEO flag** — boolean. CEO open-market buy in last 90 days is the single strongest Form 4 signal. Flag it prominently.
- **net_value_30d** — dollar-weighted net (buys minus sells, excluding grants/awards/tax withholding). Positive and large = bullish.

**Cron:** Daily at 7pm ET. Form 4s are due within 2 business days.

**Default watchlist:** The full DEFAULT_TICKERS list from `sec_scanner.py`, plus any ticker that has appeared in a `radar_opportunities` row in Supabase.

**Feeds into:** `whale-tracker` subagent, tripleSignal calculation, notification trigger for cluster_signal = "strong"

---

## Scraper 2: Government Contracts — `backend/gov_contracts_scraper.py`

**Priority:** Highest. Unique data edge — almost no retail investor scrapes this.

**Data source:** USASpending.gov API (free, no key required, rate limit 500 req/hour)
- Award search: `https://api.usaspending.gov/api/v2/search/spending_by_award/`
- Award detail: `https://api.usaspending.gov/api/v2/awards/{award_id}/`
- Agency list: `https://api.usaspending.gov/api/v2/references/agency/{id}/`

**Key agencies to prioritize (in order):**
DARPA, DIU, AFWERX, Army Contracting Command, Naval Sea Systems Command, Air Force Research Lab, Space Force, DOE, NASA, DHS, HHS (BARDA), NRO, NGA

**What to extract:**
- Award ID, awarding agency, sub-agency
- Recipient name (legal entity) → manually map to ticker. Build and maintain a `vendor_ticker_map.json` in `backend/` with known mappings. For unknown vendors, flag them with `"ticker": "UNKNOWN"` and log the vendor name for manual mapping.
- Contract type: award type (IDIQ, BPA, definitive contract, OTA, grant), pricing type (firm-fixed-price, cost-plus, time-and-materials), is sole-source
- Dollar amounts: total obligation, base and all options value (ceiling), total outlayed
- Period of performance start/end
- Award date, last modified date
- NAICS code, PSC code
- Description of requirement
- Place of performance (state/country)
- Solicitation ID (to cross-reference awards)

**Award types to flag as high-signal:**
- "IDC" (Indefinite Delivery Contract) — ceiling matters more than initial obligation
- "Other Transaction Agreement" (OTA) — DARPA/DIU's fast-track vehicle, signals urgency
- Sole-source justifications (check `isSoleSource` or the solicitation procedures field)
- "BPA Call" (Blanket Purchase Agreement against a GSA schedule)

**Vendor-to-ticker mapping strategy:**
Start with a hardcoded map of defense/gov IT names:
```python
VENDOR_TICKER_MAP = {
    "PALANTIR TECHNOLOGIES INC": "PLTR",
    "ANDRUIL INDUSTRIES": "ANDR",
    "KRATOS DEFENSE": "KTOS",
    "AEROVIRONMENT INC": "AVAV",
    "LEIDOS INC": "LDOS",
    # ... expand as new vendors appear
}
```
For unknown vendors, attempt: fuzzy match against yfinance company names, manual review queue. The `"ticker": "UNKNOWN"` entries go to a `backend/unmapped_vendors.json` log that you can review periodically.

**Output JSON schema:**
```json
{
  "ticker": "PLTR",
  "contracts": [
    {
      "award_id": "W91234567890",
      "agency": "DoD",
      "sub_agency": "Army Contracting Command",
      "award_type": "IDIQ",
      "pricing_type": "firm-fixed-price",
      "is_sole_source": true,
      "ceiling": 890000000,
      "obligated": 45000000,
      "period_start": "2026-06-01",
      "period_end": "2031-05-31",
      "award_date": "2026-05-28",
      "description": "Counter-UAS command and control software platform",
      "naics": "541511",
      "psc": "7A20",
      "place_of_performance": "VA",
      "mod_count": 3,
      "solicitation_id": "H92403-25-R-0001"
    }
  ],
  "total_obligated_12m": 245000000,
  "total_ceiling_12m": 1890000000,
  "new_awards_90d": 7,
  "first_gov_contract": false,
  "ota_count_12m": 0,
  "scraped_at": "2026-06-05T08:00:00Z"
}
```

**Alpha signals:**
- **first_gov_contract** — boolean. A commercial company winning its first federal contract ever is a re-rating catalyst. Check if any prior contracts exist in the USASpending database.
- **sole_source_idiq** — sole-source IDIQ is the single strongest contract type. Flags revenue visibility and pricing power for years.
- **ota_presence** — OTA awards from DARPA/DIU signal that the government is buying something novel and urgent.
- **contract_acceleration** — award count and total ceiling value both rising Q/Q.
- **agency diversification** — company moving from 1 agency to 3+ agencies.

**Cron:** Daily, 6am ET. New awards post each business day.

**Default watchlist:** All tickers in `backend/sec_scanner.py` DEFAULT_TICKERS plus any ticker tagged "Defense", "Aerospace", "Government IT", or "Security" in the Supabase `radar_opportunities` sector field.

**Feeds into:** `deep-research` subagent (catalyst evidence), `sector-scanner` (defense capex proxy), notification trigger for first_gov_contract or >$100M new award

---

## Scraper 3: 13F Institutional Holdings — `backend/f13_scraper.py`

**Priority:** High. Quarterly context for smart-money positioning.

**Data source:** SEC EDGAR 13F-HR filings
- CIK for institutional managers: either from the SEC company_tickers.json (the same one used for Form 4) or from a separate maintained list of top-200 fund CIKs.
- Filing retrieval: `https://data.sec.gov/submissions/CIK{fund_cik}.json` to get the latest 13F-HR accession numbers, then fetch the XML from `https://www.sec.gov/Archives/edgar/data/{fund_cik}/{acc_clean}/{acc}-primary-doc.xml`

**Fund universe to track:**
Top 50 hedge funds + top 50 mutual funds by AUM. Curate a `backend/funds_watchlist.json` with fund name, CIK, and style (value/activist/growth/macro/quant). Seed with:
- Berkshire Hathaway, Baupost, Pershing Square, Greenlight, Third Point, Elliott, Starboard, ValueAct, Trian
- Citadel, Point72, Millennium, D.E. Shaw, Two Sigma, Renaissance, Bridgewater, AQR
- Fidelity (FMR), Vanguard, BlackRock, State Street, Capital Group, T. Rowe Price, Wellington
- Tiger Global, Coatue, Lone Pine, Viking, Maverick

**What to extract:**
- Fund name, CIK, quarter end date, filing date
- Each position: ticker (from CUSIP mapping), shares held, market value
- Q/Q delta: shares added (positive) or trimmed (negative)
- New positions (not in prior quarter's 13F)
- Full exits (was in prior quarter, absent now)
- Top 10 positions by market value

**CUSIP → ticker mapping:**
CUSIPs in 13F filings are 9-character. Strip the check digit (last char) to get 8-char, then match against a CUSIP-to-ticker database. Build `backend/cusip_map.json` from:
- SEC company_tickers.json includes CUSIP
- yfinance ticker info includes CUSIP-like identifiers
- For unmapped CUSIPs, attempt: query Polygon reference API if key is available, otherwise flag as `UNKNOWN`

**Output JSON schema:**
```json
{
  "ticker": "MSTR",
  "quarter_end": "2026-03-31",
  "holders": [
    {
      "fund": "Baupost Group",
      "fund_style": "value",
      "shares": 1250000,
      "value": 450000000,
      "delta_shares": 250000,
      "action": "add",
      "is_new_position": false,
      "is_top_10": true,
      "filing_url": "https://www.sec.gov/..."
    }
  ],
  "total_institutional_shares": 28500000,
  "institutional_pct_float": 42.3,
  "net_flow_qoq": "inflow",
  "net_flow_dollar": 340000000,
  "new_funds_buying": ["Baupost Group", "Third Point"],
  "full_exits": ["Renaissance Technologies"],
  "accumulation_score": 72,
  "scraped_at": "2026-06-05T12:00:00Z"
}
```

**Alpha signals:**
- **accumulation_score** (0-100): weighed by fund quality — top-quartile-return funds weighted 2x, new positions weighted 1.5x, full exits by elite funds = heavy negative. Net institutional inflow + growing institutional ownership % = bullish. Distribution/selling by elite funds while retail buys = bearish.
- **concentration_risk** — single fund >10% of float is a double-edged signal. Report it.
- **activation_signal** — activist fund (Elliott, Starboard, ValueAct) takes a new position = catalyst in its own right.

**Cron:** Weekly during 13F season (Feb 10–Mar 15, May 10–Jun 15, Aug 10–Sep 15, Nov 10–Dec 15). Reduced to bi-weekly outside season. Always report the quarter end date — the data is 45 days stale by design.

**Feeds into:** `whale-tracker` subagent

---

## Scraper 4: FDA / Regulatory Calendar — `backend/fda_calendar_scraper.py`

**Priority:** High. Binary catalysts are the highest-impact events in biotech.

**Data source:**
- **ClinicalTrials.gov API v2:** `https://clinicaltrials.gov/api/v2/studies?query.term={ticker}+OR+{company_name}&pageSize=20`
- **FDA Drugs@FDA:** `https://api.fda.gov/drug/drugsfda.json?search=openfda.application_number:*&limit=100` — approved drugs database
- **FDA Advisory Committee calendar:** Scrape `https://www.fda.gov/advisory-committees` for upcoming meeting dates, agendas, and briefing documents
- **SEC filings (secondary):** Companies announce PDUFA dates and regulatory updates in 8-Ks and 10-Qs. The existing `sec_scanner.py` catches these — cross-reference.

**What to extract from ClinicalTrials.gov:**
- NCT ID, study title, conditions (indication), interventions (drug name)
- Sponsor, collaborators
- Phase (Phase 1/2, Phase 2, Phase 3, Phase 4)
- Enrollment target, actual enrollment
- Study start date, primary completion date, study completion date
- Overall status (recruiting, active-not-recruiting, completed, terminated)
- Locations (countries/sites) — breadth signals commercial intent

**What to extract from FDA sources:**
- Drug name (brand + generic), application number
- PDUFA goal date / action date
- FDA designation (Fast Track, Breakthrough Therapy, Priority Review, Accelerated Approval, Orphan Drug)
- Advisory Committee meeting date + outcome (if voted) + vote split
- Approval status (Approved, Complete Response Letter, Tentative Approval)
- Label indications
- Post-marketing requirements / confirmatory trial obligations

**Company → ticker mapping:**
Biotech sponsor names need mapping. Build `backend/biotech_ticker_map.json`. Seed with known names and use yfinance `search_company` or Polygon reference API for unknowns.

**Output JSON schema:**
```json
{
  "ticker": "CRVO",
  "pipeline": [
    {
      "drug": "CRV-431",
      "indication": "Hepatocellular carcinoma",
      "phase": "Phase 3",
      "designations": ["Fast Track", "Orphan Drug"],
      "pdufa_date": "2026-08-15",
      "adcom_date": null,
      "adcom_outcome": null,
      "nct_id": "NCT01234567",
      "enrollment": 420,
      "primary_completion": "2026-02-01",
      "status": "Approved (Accelerated)",
      "confirmatory_trial_nct": "NCT09876543",
      "confirmatory_trial_completion": "2027-06-30",
      "ex_us_regulatory": {
        "EMA": {"status": "Under Review", "decision_date": "2026-10-15"},
        "PMDA": {"status": "Not filed"}
      }
    }
  ],
  "upcoming_catalysts_12m": [
    {"type": "PDUFA", "date": "2026-08-15", "drug": "CRV-431", "binary": true},
    {"type": "Phase 3 Data", "date": "2026-12-01", "drug": "CRV-891", "binary": true}
  ],
  "catalyst_count_12m": 2,
  "has_accelerated_approval": true,
  "scraped_at": "2026-06-05T08:00:00Z"
}
```

**Alpha signals:**
- **first_pdufa** — company's first-ever FDA decision is a re-rating event. Market often prices it wrong.
- **catalyst_density** — 3+ binary events in 12 months creates optionality value.
- **adcom_vote_split** — close votes (7-8, 8-7, 9-6) signal genuine uncertainty. The market often overreacts to the outcome.
- **accelerated_approval_with_confirmatory** — AA requires a confirmatory trial. Track the confirmatory trial separately. An AA drug whose confirmatory trial enrolls on time is de-risking.
- **crl_resubmission** — a Complete Response Letter followed by resubmission within 6 months. The selloff on the CRL is often an overreaction if the FDA's concerns are addressable.
- **label_expansion_potential** — drug in Phase 3 for a second indication, with primary completion within 12 months.

**Cron:** Weekly refresh. For tickers with a PDUFA date within 14 days, scrape daily. Advisory committee dates are published 6-8 weeks ahead — catch them as early as possible.

**Default watchlist:** All biotech/pharma tickers from `sec_scanner.py` DEFAULT_TICKERS (CRVO, RXRX, ABCL) plus any ticker with sector containing "Biotech", "Pharma", "Healthcare", "Oncology" in Supabase.

**Feeds into:** `deep-research` subagent (catalyst calendar), notification trigger for PDUFA within 7 days

---

## Scraper 5: Short Interest + Options Flow — `backend/short_flow_scraper.py`

**Priority:** Highest. Squeeze detection is pure alpha.

**Data sources:**
- **Polygon.io** (API key already configured):
  - Snapshot: `https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers/{ticker}?apiKey={key}`
  - Options chain: `https://api.polygon.io/v3/snapshot/options/{ticker}?apiKey={key}`
  - Ticker details (short interest): `https://api.polygon.io/v3/reference/tickers/{ticker}?apiKey={key}`
- **FINRA** short sale volume (daily, free, no key):
  - `https://cdn.finra.org/equity/regsho/daily/CNMSshvol{YYYYMMDD}.txt` (large daily files — parse for relevant tickers)
- **CBOE** put/call ratio: `https://www.cboe.com/us/options/market_statistics/` (scrape or use Polygon aggregated data)

**What to extract:**
- **Short interest:** % of float, days to cover, trend over 6 months (rising/falling/flat). Polygon reports this; FINRA bi-monthly settlement data is the authoritative source.
- **Options flow (30-day window):**
  - Call/put ratio by volume
  - Unusual activity: single trades with premium > $500K or volume > 5x open interest
  - Largest trades by premium (top 10), side (call/put/bought/sold), strike, expiry
  - Implied volatility vs. historical volatility (IV/HV spread)
  - Put/call skew (IV of OTM puts vs OTM calls)
- **Dark pool / ATS volume:** % of total volume, trend direction
  - FINRA ATS data: `https://otctransparency.finra.org/otctransparency/` or aggregated via Polygon if available
- **Gamma exposure:** aggregate gamma at each strike from options open interest. Find the "gamma flip" zone (where dealers switch from hedging-long to hedging-short).

**Output JSON schema:**
```json
{
  "ticker": "CRVO",
  "short_interest_pct_float": 14.3,
  "short_interest_trend": "rising",
  "days_to_cover": 6.2,
  "short_squeeze_score": 78,
  "options_flow_30d": {
    "call_put_ratio": 1.8,
    "iv_percentile": 65,
    "iv_hv_spread": 12.5,
    "put_call_skew": -0.08,
    "unusual_activity": [
      {
        "date": "2026-06-04",
        "strike": 45.0,
        "expiry": "2026-07-19",
        "side": "call",
        "direction": "bought",
        "premium": 2200000,
        "size_vs_oi": 6.2,
        "sentiment": "bullish"
      }
    ],
    "top_trades": []
  },
  "dark_pool_pct": 42.1,
  "dark_pool_trend": "rising",
  "gamma_flip_zone": 37.5,
  "scraped_at": "2026-06-05T16:00:00Z"
}
```

**Alpha signals (compute these — this is the edge):**
- **short_squeeze_score (0-100):**
  - Short interest > 20% of float = 50 points
  - Days to cover > 5 = +15 points
  - Short interest rising (not falling) over 6 months = +10 points
  - Insider cluster buying detected (cross-ref `insider_scraper.py` cache) = +15 points
  - Near-term binary catalyst (cross-ref `fda_calendar` or `sec_scanner`) = +10 points
  - Score > 70 = flag for notification
- **unusual_options_sentiment:** Net bullish/bearish based on direction + side. Bought calls = bullish, sold calls = bearish. Bought puts = bearish, sold puts = bullish. Aggregate over 30 days.
- **dark_pool_accumulation:** dark pool % rising + price rising = institutional accumulation (bullish). dark pool % rising + price falling = institutional distribution (bearish).
- **gamma_exposure_regime:** positive aggregate gamma = stabilizing (dealers buy low, sell high). negative aggregate gamma = destabilizing (dealers sell into weakness, buy into strength). Gamma flip zone = price where regime changes.

**Cron:** Daily, after market close. Options flow and dark pool data are daily. Short interest updates bi-monthly — use Polygon's reported figure and flag when it's stale.

**Feeds into:** `whale-tracker` (options flow), `risk-audit` (short squeeze risk scoring), notification trigger for short_squeeze_score > 70

---

## Scraper 6: Patent & Technology — `backend/patent_scraper.py`

**Priority:** Medium. Lead indicator for technology moats and pivots.

**Data source:** Google Patents (free, no key, more searchable than raw USPTO)
- Search: `https://patents.google.com/?q=assignee:%22{company}%22&before=priority:20260605&after=publication:20240101&num=25`
- Or use the USPTO Patent Public Search API: `https://developer.uspto.gov/api-catalog` (requires registration, free)
- Fallback: scrape Google Patents HTML search results if API is rate-limited

**What to extract:**
- Patent number, title, abstract
- Assignee (company name → ticker mapping, reuse `vendor_ticker_map.json` approach)
- Filing date, publication date (note: US patents publish 18 months after filing — this is a lagging indicator)
- IPC/CPC classification codes (technology domain tags)
- Inventors (names, count)
- Patent family size (number of jurisdictions filed — breadth signals commercial intent)
- Forward citation count (how many later patents cite this one — the best quality signal)
- Legal status (granted, pending, expired)

**Technology domains to flag as high-signal:**
- G06N (AI/ML), H01L (semiconductors), G06T (computer vision), H04L (networking/blockchain)
- A61K (pharma/biotech), C12N (genetic engineering), G01S (radar/lidar/navigation)
- F41G/H (weapon systems/defense), B64G (spacecraft), G21C (nuclear reactors)
- H01M (batteries), C01B/C22B (materials/lithium processing)
- G06Q 20/00 (fintech/payment), G06Q 40/00 (finance/trading)

**Output JSON schema:**
```json
{
  "ticker": "PLTR",
  "patents": [
    {
      "number": "US12345678B2",
      "title": "Federated ontology-based data integration system",
      "abstract": "A system for federated ontology-based data integration...",
      "filing_date": "2024-12-01",
      "publication_date": "2026-06-03",
      "ipc_classes": ["G06F16/00", "G06N20/00"],
      "high_signal_domain": true,
      "inventors": ["Alex Karp", "Shyam Sankar"],
      "inventor_count": 4,
      "family_size": 12,
      "forward_citations": 2,
      "legal_status": "granted",
      "url": "https://patents.google.com/patent/US12345678B2"
    }
  ],
  "patent_count_12m": 47,
  "patent_count_3y_trend": "accelerating",
  "top_domains": ["G06F16/00", "G06N20/00", "H04L63/00"],
  "domain_shift_flag": false,
  "avg_forward_citations_3y": 8.4,
  "avg_family_size_12m": 11.2,
  "scraped_at": "2026-06-05T10:00:00Z"
}
```

**Alpha signals:**
- **patent_velocity_acceleration** — quarterly filing rate increasing > 20% Q/Q. Signals R&D output accelerating.
- **domain_shift_flag** — patents appearing in a new IPC class not seen in prior 3 years. The company is building something new that hasn't been announced.
- **citation_quality** — forward citations > sector median. This patent is foundational — competitors are building on it.
- **family_size_signal** — filing in 12+ jurisdictions is expensive ($50K+/patent). This is commercial intent, not defensive filing.
- **inventor_migration** — key inventor leaves BigCo for SmallCo. Track inventor names across companies. An AI/ML PhD leaving Google for a micro-cap is a signal.

**Cron:** Weekly. USPTO publishes new grants every Tuesday.

**Default watchlist:** All tickers from DEFAULT_TICKERS plus any ticker whose sector contains "Technology", "AI", "Semis", "Biotech", "Defense", "Materials" in Supabase.

**Feeds into:** `deep-research` (technology moat evidence), `sector-scanner` (innovation signal by sector)

---

## Scraper 7: Congressional Trading — `backend/congress_scraper.py`

**Priority:** Medium. Informational edge — politicians trade on non-public information and it's legal (for them).

**Data source:**
- **Senate Financial Disclosures:** `https://efdsearch.senate.gov/search/` — HTML form-based, requires session handling. Scrape via POST with search parameters.
- **House Financial Disclosures:** `https://disclosures-clerk.house.gov/FinancialDisclosure` — CSV downloads available for bulk data. Direct download: `https://disclosures-clerk.house.gov/public_disc/financial-pdfs/{year}/FD_{year}.csv`
- Both are free, no API key, no documented rate limit. Be respectful (1 req/sec).

**Parsing strategy:**
- House: parse the CSV for transaction reports (PTP = Periodic Transaction Report). Extract: member name, ticker, transaction type (P=Purchase, S=Sale, E=Exchange), amount range, transaction date, filing date.
- Senate: scrape the search results or use the bulk JSON endpoint if available. Senate data is less structured — parse the PDFs or use the HTML table view.
- Amounts are reported in RANGES ($1K-$15K, $15K-$50K, $50K-$100K, $100K-$250K, $250K-$500K, $500K-$1M, $1M-$5M, $5M+). Use the midpoint for aggregation. Flag $1M-$5M and $5M+ transactions as high-signal.
- Committee assignments matter: members of Armed Services, Intelligence, Appropriations, Ways & Means, Energy & Commerce, HELP, Finance, Banking, and Foreign Relations committees have the most informational advantage. Build `backend/committee_assignments.json` from congress.gov member data.

**Output JSON schema:**
```json
{
  "ticker": "NVDA",
  "transactions": [
    {
      "member": "Nancy Pelosi",
      "chamber": "House",
      "party": "D",
      "committees": ["Appropriations"],
      "type": "buy",
      "amount_range": "$1M-$5M",
      "amount_midpoint": 3000000,
      "transaction_date": "2026-05-15",
      "filed_at": "2026-06-14",
      "filing_lag_days": 30,
      "source_url": "..."
    }
  ],
  "total_buyers": 3,
  "total_sellers": 0,
  "total_buy_value_midpoint": 5200000,
  "cross_party_flag": true,
  "committee_overlap_flag": true,
  "committee_overlap_detail": "Armed Services + Intelligence Committee members buying defense stocks",
  "scraped_at": "2026-06-05T10:00:00Z"
}
```

**Alpha signals:**
- **committee_cluster** — 2+ members of the same relevant committee buying the same ticker within 60 days. This is the strongest congressional signal. Armed Services members buying defense stocks in the month before NDAA markup = informational edge.
- **cross_party_consensus** — same ticker bought by both Democrats and Republicans. Rare. Exceptional signal.
- **speaker_leadership_effect** — Speaker of the House, Majority/Minority Leader, or committee chairs trading. These members have the most access.
- **timing_vs_legislation** — transaction date relative to key votes, committee markups, or NDAA passage.
- **filing_lag_alert** — the 30-45 day filing lag means these trades are public but many retail platforms don't surface them. Freshly filed transaction by Pelosi that hasn't hit the aggregators yet = immediate notification.

**Cron:** Weekly. New filings arrive continuously. The House CSV updates periodically; Senate search results are near real-time.

**Feeds into:** `whale-tracker` (smart money), notification trigger for committee_cluster or speaker trading

---

## Scraper 8: Underfollowed Stock Screener — `backend/coverage_screener.py`

**Priority:** Medium. Discovery engine for the entire radar.

**Data sources:**
- **yfinance** — `info['numberOfAnalystOpinions']`, `info['heldPercentInstitutions']`, `info['floatShares']`, `info['marketCap']`, `info['averageVolume']`, `info['shortName']`, `info['sector']`, `info['industry']`
- **Polygon.io** — reference data for analyst coverage confirmation, ETF constituent lookups
- **ETF.com** — scrape ETF holdings for ticker inclusion data. For each ticker found to be included in ETFs, record the ETF tickers.
- **FTSE Russell** — annual Russell reconstitution schedule. `https://www.ftserussell.com/` — reconstitution dates are published months ahead.

**Screening criteria (from CLAUDE.md):**
- Analyst count 0-3 (underfollowed)
- Institutional ownership < 40% (under-owned)
- ETF inclusion count 0-2 (not yet "discovered" by passive flows)
- Market cap $100M-$10B (small/mid-cap sweet spot)
- Average daily volume > $1M (tradable)

**What to extract per ticker:**
- Company name, sector, industry
- Market cap, enterprise value
- Analyst count, institutional ownership %
- Number of ETFs holding this stock, list of ETF tickers
- Index membership (Russell 2000/3000, S&P 600, S&P 400, Wilshire, none)
- Upcoming Russell reconstitution status (staying, graduating up, graduating down, entering, exiting)
- Russell reconstitution effective date (usually last Friday in June)
- Float shares, float market cap
- Average daily dollar volume (30-day and 90-day)
- Short interest (cross-ref from `short_flow_scraper.py` cache)

**Output JSON schema:**
```json
{
  "ticker": "HDRN",
  "company_name": "Hadrian Defense Systems",
  "sector": "Industrials",
  "industry": "Aerospace & Defense",
  "market_cap": 4800000000,
  "enterprise_value": 5140000000,
  "analyst_count": 2,
  "institutional_ownership_pct": 31.1,
  "etf_inclusion_count": 1,
  "etf_inclusions": ["ITA"],
  "index_membership": ["Russell 2000"],
  "russell_status": "graduating",  # 2000 → 1000
  "russell_reconstitution_date": "2026-06-26",
  "russell_graduation_add_estimate_pct": 10.5,
  "float_shares": 38000000,
  "float_market_cap": 2360000000,
  "avg_dollar_volume_30d": 12400000,
  "avg_dollar_volume_90d": 9800000,
  "volume_trend": "rising",
  "underfollowed_score": 85,
  "scraped_at": "2026-06-05T10:00:00Z"
}
```

**Alpha signals:**
- **underfollowed_score (0-100):** 0 analysts = 40 points, 1-2 = 30, 3 = 20. Institutional ownership < 20% = +20, 20-40% = +10. 0 ETF inclusions = +20, 1 = +15, 2 = +10. Market cap in sweet spot ($500M-$5B) = +20. Volume > $5M/day = bonus (tradable). Score > 70 = high-alpha underfollowed.
- **russell_graduation:** Russell 2000 → 1000 or Russell 1000 → top 500. Forces passive buying of ~10-15% of float. The mechanical uplift is real. Flag 4 weeks ahead.
- **first_analyst_initiation:** Track analyst count changes. First initiation is a discovery catalyst. A stock going from 2 analysts to 3 = early in the coverage cycle. Going from 0 to 1 = event.
- **etf_inclusion_event:** New ETF adds this ticker. For thematic ETFs (AI, space, defense, nuclear, bitcoin), inclusion means new forced buying.
- **volume_inflection:** 90-day average volume crossing above $5M/day while institutional ownership < 40% = stock is being discovered but not yet owned. Early.

**Screening universe:** Use yfinance to scan. Start with known tickers from existing DEFAULT_TICKERS, then expand: all tickers in Russell 2000 (download from FTSE Russell), all tickers in S&P 600, plus any ticker that has appeared in an SEC filing cross-reference. Goal: screen 2,000+ tickers weekly. Cache results so you're only querying delta changes.

**Cron:** Weekly full screen. Daily for Russell reconstitution candidates in May-June.

**Feeds into:** `sector-scanner` (captain discovery), `market-brief` (discovery signals), new ticker addition to default watchlists

---

## Scraper 9: Spin-off & Corporate Action Tracker — `backend/spinoff_tracker.py`

**Priority:** Medium. Rare events, exceptional alpha.

**Data source:** SEC EDGAR filings — the existing `sec_scanner.py` already monitors 8-Ks, but spin-offs require specific parsing.
- **Form 10-12B:** Registration statement for spin-off. The definitive document — contains business description, financials, distribution details, lockup schedule. Filing signals 2-4 months before distribution.
- **Form 8-K Item 2.01:** Completion of acquisition or disposition — used when the spin-off actually closes.
- **Form 8-K Item 8.01:** Other events — often used for distribution ratio and record date announcements.

**Detection strategy:**
- Reuse the SEC submissions API pipeline from `sec_scanner.py`. Scan every ticker in the universe for recent 10-12B and 8-K (Item 2.01 + specific spin-off keywords) filings.
- Keywords: "spin-off", "spinoff", "spin off", "separation", "distribution", "split-off", "rights offering", "carve-out", "carve out", "when-issued", "tax-free distribution", "Form 10 registration"
- Parse the 10-12B filing for the distribution ratio, record date, distribution date, and spinco financials.

**What to extract:**
- Parent company, parent ticker
- Spinco name, spinco ticker (if assigned — often announced 2-4 weeks before distribution)
- Transaction type: spin-off (pro-rata distribution to shareholders), split-off (shareholder election/tender), carve-out IPO, rights offering, tracking stock
- Distribution ratio: e.g., 1 share of SpinCo for every 3 shares of Parent
- Key dates: announcement date, record date, distribution date, when-issued trading start
- Parent retained stake post-spin (0% = clean spin-off)
- Spinco business description, segment financials from the 10-12B
- Estimated market cap at distribution (use when-issued pricing if available, otherwise estimate from segment financials)
- Form 10-12B URL

**Output JSON schema:**
```json
{
  "parent_ticker": "GE",
  "parent_name": "General Electric",
  "spinco_name": "GE Vernova",
  "spinco_ticker": "GEV",
  "transaction_type": "spin-off",
  "distribution_ratio": "1:3",
  "announcement_date": "2024-03-15",
  "record_date": "2024-03-22",
  "distribution_date": "2024-04-02",
  "when_issued_start": "2024-03-25",
  "parent_retained_pct": 0.0,
  "spinco_business": "Electrification, power generation, wind energy",
  "spinco_segment_revenue": 34000000000,
  "spinco_est_market_cap": 35000000000,
  "parent_est_market_cap_post": 160000000000,
  "form_10_12b_url": "https://www.sec.gov/...",
  "status": "completed",
  "scraped_at": "2026-06-05T10:00:00Z"
}
```

**Alpha signals:**
- **when_issued_discount:** Spinco trading at a discount to sum-of-parts during when-issued period. Institutional shareholders of the parent often sell the when-issued SpinCo because it's not in their mandate — forced selling, not fundamental.
- **index_fund_selling_window:** SpinCo is often too small for the parent's index. Russell 1000 parent → spin-off too small for Russell 1000 → forced index selling in the first 2 weeks. This is a mechanical dip, not a fundamental event. The alpha is buying it.
- **insider_buying_post_spin:** SpinCo management buying in the open market after distribution. They just got independence and a fresh equity package — buying more signals they think the market is undervaluing it.
- **clean_spin_vs_partial:** 0% retained = clean spin-off, management focus, pure play. >20% retained = partial, parent still influences. Clean is better.
- **size_mismatch:** When SpinCo is < 10% of parent's market cap, it's likely to be ignored by parent's institutional holders. The forced-selling effect is larger.

**Cron:** Weekly. Form 10-12B gives 2-4 months of lead time. When a new 10-12B is detected, flag it immediately via notification.

**Feeds into:** `deep-research` (catalyst), `sector-scanner` (new entity to track), notification trigger for new spin-off announcement

---

## Scraper 10: Social Sentiment — `backend/social_scraper.py`

**Priority:** Lower-medium. Useful contrarian indicator, high noise unless well-filtered.

**Data sources (no X/Twitter API — excluded per instructions):**
- **Reddit API (PRAW):** `https://www.reddit.com/dev/api/` — requires OAuth app registration (free). Track r/wallstreetbets, r/stocks, r/investing, r/SPACs, r/options, r/thetagang, r/biotech_stocks.
- **StockTwits:** `https://api.stocktwits.com/api/2/streams/symbol/{ticker}.json` — free, ticker-specific feeds. Includes sentiment tagging.
- **ApeWisdom:** `https://apewisdom.io/api/v1.0/filter/all-stocks/page/1` — aggregates WSB mentions. Free tier available.

**Reddit scraping (PRAW):**
- Monitor `r/wallstreetbets` — track every post and comment for ticker mentions using regex: `\b[A-Z]{1,5}\b` (filter out common words)
- Track: post title, post body, comment body, upvotes, comment count, timestamp
- De-duplicate: a ticker mentioned in a high-engagement post will generate hundreds of comments. Count unique posts, not total mentions.
- Sentiment classification: simple keyword approach (buy/calls/moon/yolo/tendies/straddle = bullish; puts/short/gay/bear/bagholder/bankrupt = bearish). Future iteration: use a lightweight model, but start simple.
- Track sentiment over time: a sentiment flip (bearish→bullish or bullish→bearish) at a technical level is the signal to flag.

**StockTwits API:**
- `https://api.stocktwits.com/api/2/streams/symbol/{TICKER}.json` returns recent messages with `sentiment` field (Bullish/Bearish) already tagged by the user.
- Count messages per day, calculate bullish/bearish ratio.
- Track unusual message volume spike (z-score > 3 vs 90-day average).

**Do NOT scrape:**
- X/Twitter (excluded per instructions)
- Discord servers (private communities, TOS issues)
- Telegram channels (same)
- YouTube comments
- TikTok

**Output JSON schema:**
```json
{
  "ticker": "MSTR",
  "reddit": {
    "mentions_24h": 142,
    "unique_posts_24h": 18,
    "mention_z_score_24h": 4.3,
    "sentiment": 0.72,
    "sentiment_trend": "bullish_increasing",
    "top_posts": [
      {
        "subreddit": "wallstreetbets",
        "title": "MSTR is the only Bitcoin play that makes sense",
        "upvotes": 2400,
        "comments": 312,
        "url": "https://reddit.com/r/wallstreetbets/comments/...",
        "sentiment": "bullish",
        "posted_at": "2026-06-05T12:30:00Z"
      }
    ]
  },
  "stocktwits": {
    "messages_24h": 230,
    "message_z_score_24h": 2.1,
    "bullish_ratio": 0.68,
    "watchlist_adds_7d": 1400
  },
  "social_sentiment_composite": 0.70,
  "social_velocity_flag": true,
  "contrarian_flag": false,
  "scraped_at": "2026-06-05T15:00:00Z"
}
```

**Alpha signals:**
- **social_velocity_spike:** Mention count z-score > 3. Retail is discovering this ticker. If no fundamental news or price move yet, it's early — investigate.
- **sentiment_extreme:** Bullish ratio > 0.85 or < 0.15. Extreme sentiment + no fundamental catalyst = potential fade. Extreme sentiment + genuine catalyst = momentum confirmation.
- **narrative_shift:** Sentiment trend flips from bearish to bullish (or vice versa) while price is at a key technical level. The narrative follows price, but sometimes leads it by hours.
- **contrarian_flag:** Social sentiment extreme (>0.80 or <0.20) opposite to the smart-money flow (from `insider_scraper` and `f13_scraper` cache). If Reddit is euphoric but insiders are selling and 13Fs show distribution — that's a short candidate.
- **meme_risk_flag:** Social mentions > 3 std dev above average + short interest > 20% = potential meme squeeze. Flag for `risk-audit` — this is NOT a fundamental long, it's a volatility trade.

**Cron:** Hourly for Reddit/StockTwits tracking of the active watchlist. Full sentiment screen of all tickers daily.

**Default watchlist:** Same as `sec_scanner.py` DEFAULT_TICKERS, plus any ticker that appears in a Reddit/StockTwits trending feed, plus any ticker with recent unusual social volume.

**Feeds into:** `market-brief` (retail pulse), `risk-audit` (contrarian check, meme risk), `whale-tracker` (smart-money vs retail divergence)

---

## Implementation Order

```
Day 1-3 — Phase 1: Core Alpha (3 scrapers)
├── 1. insider_scraper.py      ← build first, highest signal/noise
├── 5. short_flow_scraper.py   ← squeeze detection, cross-refs insider data
└── 2. gov_contracts_scraper.py ← unique data moat

Day 4-6 — Phase 2: Institutional + Catalysts (3 scrapers)
├── 3. f13_scraper.py          ← quarterly context, fund universe
├── 4. fda_calendar_scraper.py ← binary catalyst calendar
└── 8. coverage_screener.py    ← discovery engine, feeds all other scrapers

Day 7-9 — Phase 3: Special Situations + Sentiment (4 scrapers)
├── 9. spinoff_tracker.py      ← rare events, high alpha
├── 6. patent_scraper.py       ← technology lead indicator
├── 7. congress_scraper.py     ← informational edge
└── 10. social_scraper.py      ← retail flow (Reddit + StockTwits only)
```

## Cross-Scraper Integration

Scrapers should cross-reference each other's cached data in the shared SQLite DB:

- `short_flow_scraper` reads `insider_scraper` cache → insider cluster boosts squeeze score
- `whale-tracker` subagent reads all 4 caches (insider, 13F, congress, options) → composite smart-money score
- `coverage_screener` reads `short_flow_scraper` cache → adds short interest to underfollowed score
- `social_scraper` reads `insider_scraper` and `f13_scraper` caches → contrarian divergence flag
- `risk-audit` subagent reads `short_flow_scraper` cache → squeeze risk, lockup dilution
- `deep-research` subagent reads `gov_contracts_scraper`, `fda_calendar_scraper`, `patent_scraper`, `spinoff_tracker` caches → catalyst evidence

## Requirements Update

Add to `backend/requirements.txt`:
```
yfinance>=0.2.40
pandas>=2.0.0
requests>=2.31.0
praw>=7.0.0       # Reddit API
sqlite3           # (stdlib, already present)
```

## Shared Cache Schema

Create `backend/cache_schema.py` with table definitions for the shared SQLite database:

```sql
CREATE TABLE IF NOT EXISTS insider_transactions (
    ticker TEXT, filer TEXT, role TEXT, date TEXT, code TEXT,
    shares INTEGER, price REAL, value REAL, is_10b5_1 INTEGER,
    post_holdings INTEGER, filing_url TEXT,
    scraped_at TEXT, PRIMARY KEY (ticker, filer, date, code, shares)
);

CREATE TABLE IF NOT EXISTS gov_contracts (
    award_id TEXT PRIMARY KEY, ticker TEXT, agency TEXT,
    sub_agency TEXT, award_type TEXT, is_sole_source INTEGER,
    ceiling REAL, obligated REAL, award_date TEXT,
    period_start TEXT, period_end TEXT, description TEXT,
    naics TEXT, psc TEXT, scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS f13_holdings (
    fund TEXT, fund_style TEXT, ticker TEXT, quarter_end TEXT,
    shares INTEGER, value REAL, delta_shares INTEGER, action TEXT,
    is_new_position INTEGER, is_full_exit INTEGER,
    filing_url TEXT, scraped_at TEXT,
    PRIMARY KEY (fund, ticker, quarter_end)
);

CREATE TABLE IF NOT EXISTS fda_pipeline (
    ticker TEXT, drug TEXT, indication TEXT, phase TEXT,
    pdufa_date TEXT, adcom_date TEXT, nct_id TEXT PRIMARY KEY,
    designations TEXT, status TEXT, confirmatory_nct TEXT,
    scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS short_flow (
    ticker TEXT, date TEXT PRIMARY KEY, short_interest_pct REAL,
    days_to_cover REAL, dark_pool_pct REAL, call_put_ratio REAL,
    gamma_flip_zone REAL, short_squeeze_score INTEGER,
    scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS patents (
    number TEXT PRIMARY KEY, ticker TEXT, title TEXT,
    filing_date TEXT, publication_date TEXT, ipc_classes TEXT,
    family_size INTEGER, forward_citations INTEGER,
    legal_status TEXT, url TEXT, scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS congress_trades (
    id INTEGER PRIMARY KEY AUTOINCREMENT, ticker TEXT,
    member TEXT, chamber TEXT, party TEXT, committees TEXT,
    type TEXT, amount_range TEXT, amount_midpoint REAL,
    transaction_date TEXT, filed_at TEXT, source_url TEXT,
    scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS coverage_screen (
    ticker TEXT PRIMARY KEY, analyst_count INTEGER,
    institutional_ownership_pct REAL, etf_inclusion_count INTEGER,
    index_membership TEXT, russell_status TEXT,
    underfollowed_score INTEGER, market_cap REAL,
    avg_dollar_volume_30d REAL, scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS spinoffs (
    parent_ticker TEXT, spinco_ticker TEXT, transaction_type TEXT,
    distribution_ratio TEXT, record_date TEXT, distribution_date TEXT,
    when_issued_start TEXT, parent_retained_pct REAL,
    spinco_business TEXT, form_10_12b_url TEXT, status TEXT,
    PRIMARY KEY (parent_ticker, spinco_ticker, distribution_date)
);

CREATE TABLE IF NOT EXISTS social_sentiment (
    ticker TEXT, platform TEXT, date_hour TEXT,
    mentions INTEGER, unique_posts INTEGER, sentiment REAL,
    mention_z_score REAL, PRIMARY KEY (ticker, platform, date_hour)
);
```

## Pipeline Integration

Scrapers feed data into two consumption paths:

1. **Server subagents (runtime):** The server's agent tools (`web_search`, `get_stock_price`) gain two new tools:
   - `query_alpha_cache(scraper, ticker)` — reads from the shared SQLite DB. Each subagent (whale-tracker, deep-research, risk-audit, sector-scanner, market-brief) calls this before firing web searches. If the data is in the cache and fresh, use it.
   - `run_scraper(scraper, tickers)` — triggers a targeted scrape for real-time freshness.

2. **Cron automation (outside server):** A `crontab` or `launchd` schedule runs each scraper at its cadence:
   ```
   # Daily scrapers
   0 19 * * * cd /path/to/NoFomo && python3 backend/insider_scraper.py --json >> .cache/insider.log
   0 6  * * * cd /path/to/NoFomo && python3 backend/gov_contracts_scraper.py --json >> .cache/gov.log
   0 16 * * 1-5 cd /path/to/NoFomo && python3 backend/short_flow_scraper.py --json >> .cache/flow.log
   0 *  * * * cd /path/to/NoFomo && python3 backend/social_scraper.py --json >> .cache/social.log

   # Weekly scrapers
   0 8  * * 1 cd /path/to/NoFomo && python3 backend/fda_calendar_scraper.py --json >> .cache/fda.log
   0 10 * * 1 cd /path/to/NoFomo && python3 backend/coverage_screener.py --json >> .cache/coverage.log
   0 12 * * 1 cd /path/to/NoFomo && python3 backend/patent_scraper.py --json >> .cache/patent.log
   0 14 * * 1 cd /path/to/NoFomo && python3 backend/congress_scraper.py --json >> .cache/congress.log
   0 16 * * 1 cd /path/to/NoFomo && python3 backend/spinoff_tracker.py --json >> .cache/spinoff.log

   # 13F scrapers — seasonal, run during 13F windows
   0 10 * * 2 cd /path/to/NoFomo && python3 backend/f13_scraper.py --json >> .cache/f13.log
   ```
   (Alternatively, use a single `backend/scheduler.py` that orchestrates all scrapers per their cadence.)

## Hard Rules

- **No secrets in scraper code.** API keys from env vars only (`os.environ.get("POLYGON_API_KEY")`, etc.).
- **Every scraper respects rate limits.** Minimum 0.12s between requests to the same host. Use `time.sleep()`.
- **Cache before network.** Check SQLite cache; only hit the network if cache is stale or missing.
- **Fail gracefully.** A single ticker timing out should not kill the scan. Catch exceptions, log warnings, continue.
- **No X/Twitter API.** Reddit + StockTwits only for social sentiment.
- **`--json` output is the machine interface.** Every scraper must support it.
- **No comments in code unless explaining a non-obvious transformation.**
