-- No Fomo — Supabase Database Schema
-- Run this in the Supabase SQL Editor:
-- https://lmgphebvungyqsnqitcg.supabase.co → SQL Editor → New Query → Paste → Run

-- ============================================================================
-- 1. opportunity_feed — the core table
-- ============================================================================
CREATE TABLE IF NOT EXISTS opportunity_feed (
    id              TEXT PRIMARY KEY,
    ticker          TEXT NOT NULL,
    company_name    TEXT NOT NULL,
    sector          TEXT NOT NULL DEFAULT '',
    tier            INTEGER NOT NULL CHECK (tier IN (1, 2)),
    score           DOUBLE PRECISION NOT NULL DEFAULT 0,
    triple_signal   BOOLEAN NOT NULL DEFAULT false,
    bluf            TEXT NOT NULL,
    price           DOUBLE PRECISION NOT NULL DEFAULT 0,
    upside          DOUBLE PRECISION NOT NULL DEFAULT 0,
    market_cap      TEXT NOT NULL DEFAULT '',
    probability     DOUBLE PRECISION NOT NULL DEFAULT 0,
    catalyst        TEXT NOT NULL DEFAULT '',
    council         JSONB NOT NULL DEFAULT '{"gemini":"BULL","deepseek":"BULL","cio":"BULL"}',
    buy_zones       JSONB NOT NULL DEFAULT '{"aggressive":0,"base":0,"conservative":0}',
    bull_case       TEXT NOT NULL DEFAULT '',
    bear_case       TEXT NOT NULL DEFAULT '',
    financials      JSONB NOT NULL DEFAULT '[]',
    red_flags       JSONB NOT NULL DEFAULT '[]',
    invalidation    TEXT NOT NULL DEFAULT '',
    is_premium      BOOLEAN NOT NULL DEFAULT true,
    published_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Legacy / backward-compat columns
    overall_score           DOUBLE PRECISION,
    is_triple_signal        BOOLEAN,
    gemini_verdict          TEXT,
    deepseek_verdict        TEXT,
    debate_verdict          TEXT,
    buy_zone_aggressive     DOUBLE PRECISION,
    buy_zone_base           DOUBLE PRECISION,
    buy_zone_conservative   DOUBLE PRECISION,
    probability_score       DOUBLE PRECISION,
    upside_pct              DOUBLE PRECISION,
    snap                    JSONB,
    thesis                  TEXT,
    source_company          TEXT,
    source_quote            TEXT,
    market_miss             TEXT,
    invalidation_trigger    TEXT,
    target_price            DOUBLE PRECISION,
    floor_price             DOUBLE PRECISION,
    asymmetry_score         INTEGER,
    conviction_score        INTEGER,
    catalyst_score          INTEGER,
    management_score        INTEGER,
    downside_pct            DOUBLE PRECISION,
    smart_money_score       INTEGER,
    market_cap_score        INTEGER,
    full_report_md          TEXT
);

-- ============================================================================
-- 2. user_watchlist — tracks saved opportunities per user
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_watchlist (
    id              BIGSERIAL PRIMARY KEY,
    user_id         TEXT NOT NULL,
    opportunity_id  TEXT NOT NULL REFERENCES opportunity_feed(id),
    ticker          TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, opportunity_id)
);

-- ============================================================================
-- 3. push_tokens — APNS device tokens for push notifications
-- ============================================================================
CREATE TABLE IF NOT EXISTS push_tokens (
    id          BIGSERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    apns_token  TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, apns_token)
);

-- ============================================================================
-- 4. Seed data — 5 prototype opportunities
-- ============================================================================
INSERT INTO opportunity_feed (
    id, ticker, company_name, sector, tier, score, triple_signal, bluf,
    price, upside, market_cap, probability, catalyst,
    council, buy_zones, bull_case, bear_case, financials, red_flags, invalidation,
    published_at, is_premium,
    overall_score, is_triple_signal,
    gemini_verdict, deepseek_verdict, debate_verdict,
    buy_zone_aggressive, buy_zone_base, buy_zone_conservative,
    probability_score, upside_pct
) VALUES
(
    'crvo', 'CRVO', 'Corvus Therapeutics', 'Biotech · Oncology', 1, 91, true,
    'FDA granted accelerated approval for CRV-431 in hepatocellular carcinoma. Two insiders bought $4.1M of stock 9 days prior. Market has not repriced the label expansion.',
    38.42, 142, '1.2B', 78, 'FDA accelerated approval',
    '{"gemini":"BULL","deepseek":"BULL","cio":"BULL"}',
    '{"aggressive":41.20,"base":37.80,"conservative":33.50}',
    'First-in-class cyclophilin inhibitor with a clean safety profile and a label that opens a $3.4B addressable market. Insider cluster-buying at $34 signals conviction from people who read the data before the Street. Cash runway through 2028 removes dilution overhang.',
    'Accelerated approval requires a confirmatory Phase 3 — a miss in 2027 unwinds the thesis. Single-asset concentration. Commercial launch execution is unproven for a company that has never sold a drug.',
    '[["Revenue (TTM)","$0"],["Cash & equivalents","$612M"],["Burn (quarterly)","$48M"],["Runway","Q1 2028"],["Float","31.2M sh"],["Short interest","14.3%"]]',
    '["Confirmatory Phase 3 read-out risk in 2027","Zero commercial revenue history","14% short interest can squeeze both ways"]',
    'Confirmatory trial enrollment slips past Q3 2026, or label gets a boxed warning.',
    now() - interval '2 hours', true,
    91, true, 'BULL', 'BULL', 'BULL',
    41.20, 37.80, 33.50, 78, 142
),
(
    'hdrn', 'HDRN', 'Hadrian Defense Systems', 'Defense · Autonomy', 2, 84, false,
    'Awarded $890M IDIQ ceiling on the Army''s counter-UAS program. Backlog now exceeds 3x trailing revenue. Street models still anchor to the pre-award run rate.',
    62.18, 64, '4.8B', 71, 'Government contract award',
    '{"gemini":"BULL","deepseek":"BULL","cio":"BULL"}',
    '{"aggressive":66.00,"base":60.50,"conservative":54.00}',
    'IDIQ ceiling converts to firm orders as counter-drone budgets compound at 22% CAGR. Sole-source position on a program of record means pricing power and multi-year visibility. Free cash flow inflects positive next fiscal year.',
    'IDIQ is a ceiling, not a guarantee — funding is appropriated annually and subject to continuing-resolution risk. Valuation already prices a clean conversion. Customer concentration in a single agency.',
    '[["Revenue (TTM)","$1.6B"],["Gross margin","38%"],["Backlog","$5.1B"],["Net debt","$340M"],["FCF (TTM)","-$12M"],["Insider own.","9.4%"]]',
    '["IDIQ ceiling ≠ funded orders","Continuing-resolution / shutdown exposure","Single-agency customer concentration"]',
    'FY funding comes in below the program''s authorized level, or a protest delays award.',
    now() - interval '3 hours', true,
    84, false, 'BULL', 'BULL', 'BULL',
    66.00, 60.50, 54.00, 71, 64
),
(
    'aeth', 'AETH', 'Aether Compute', 'Semis · AI Infrastructure', 2, 79, false,
    'Named a qualified supplier in a hyperscaler''s custom-silicon RFP. Earnings transcript flagged a ''multi-year framework'' without naming the partner. Supply-chain checks corroborate ramp.',
    114.60, 53, '11.3B', 66, 'Tech-giant partnership',
    '{"gemini":"BULL","deepseek":"BEAR","cio":"BULL"}',
    '{"aggressive":121.00,"base":109.00,"conservative":96.00}',
    'Qualification on a hyperscaler''s accelerator program is a multi-year annuity that the market underwrites only after revenue prints. Design wins are sticky; switching costs are high. Gross margin mix shifts up as custom volume scales.',
    'Framework language is non-binding and partner is unconfirmed. Hyperscaler in-housing risk is real. At 11x forward sales, any ramp slippage compresses the multiple hard. DeepSeek flags inventory build ahead of orders.',
    '[["Revenue (TTM)","$2.1B"],["Gross margin","54%"],["Fwd P/S","11.2x"],["Net cash","$1.8B"],["R&D / rev","29%"],["Insider own.","6.1%"]]',
    '["Partner unconfirmed; framework non-binding","Hyperscaler in-sourcing risk","Premium multiple leaves no room for slips"]',
    'Next two transcripts pass without a named design win, or inventory days keep rising.',
    now() - interval '4 hours', true,
    79, false, 'BULL', 'BEAR', 'BULL',
    121.00, 109.00, 96.00, 66, 53
),
(
    'mrdn', 'MRDN', 'Meridian Energy', 'Energy · Grid Storage', 1, 88, true,
    'DOE loan guarantee closed on a 4-state grid-storage buildout. CEO and CFO bought a combined $6.8M in the open market the same week. Catalyst is funded, not announced.',
    21.07, 96, '2.9B', 74, 'DOE loan + insider cluster',
    '{"gemini":"BULL","deepseek":"BULL","cio":"BULL"}',
    '{"aggressive":22.40,"base":20.10,"conservative":17.60}',
    'Federal loan guarantee de-risks the capex cycle and locks in below-market financing. Two C-suite open-market buys at $19 is the strongest insider signal in the book. Contracted offtake covers 80% of phase-one capacity.',
    'Interest-rate sensitivity on a capital-intensive build. Execution risk across four jurisdictions simultaneously. Loan disbursement is milestone-gated — slippage delays the revenue ramp.',
    '[["Revenue (TTM)","$540M"],["Gross margin","26%"],["DOE facility","$1.1B"],["Contracted offtake","80%"],["Net debt","$210M"],["Insider own.","12.8%"]]',
    '["Capital-intensive build, rate-sensitive","Four-jurisdiction execution risk","Milestone-gated loan disbursement"]',
    'A phase-one milestone slips two quarters, or offtake counterparties renegotiate.',
    now() - interval '30 minutes', true,
    88, true, 'BULL', 'BULL', 'BULL',
    22.40, 20.10, 17.60, 74, 96
),
(
    'sols', 'SOLS', 'Solstice Materials', 'Materials · Lithium', 2, 76, false,
    'Signed binding supply agreement with a top-three EV maker. Resource estimate upgraded 40% on infill drilling. Lithium spot has bottomed on cost-curve support.',
    8.94, 71, '1.6B', 62, 'Binding offtake + resource upgrade',
    '{"gemini":"BULL","deepseek":"BEAR","cio":"BULL"}',
    '{"aggressive":9.60,"base":8.40,"conservative":7.10}',
    'Binding offtake with a marquee OEM validates the deposit and underwrites project financing. Resource upgrade extends mine life and lowers unit costs. Lithium price has found a floor at the marginal cost of production.',
    'Commodity-price taker with no control over the cycle. Permitting and construction are years out. DeepSeek flags dilution risk to fund the build. Spot lithium could overshoot to the downside before recovering.',
    '[["Revenue (TTM)","$0"],["Cash","$185M"],["Resource (M&I)","+40%"],["First production","2028E"],["Net debt","$0"],["Insider own.","7.7%"]]',
    '["Pure commodity-price exposure","Pre-revenue; first production years out","Likely equity dilution to fund capex"]',
    'Lithium breaks the cost-curve floor, or permitting timeline slips past 2026.',
    now() - interval '1 hour', true,
    76, false, 'BULL', 'BEAR', 'BULL',
    9.60, 8.40, 7.10, 62, 71
)
ON CONFLICT (id) DO UPDATE SET
    ticker = EXCLUDED.ticker,
    company_name = EXCLUDED.company_name,
    sector = EXCLUDED.sector,
    tier = EXCLUDED.tier,
    score = EXCLUDED.score,
    triple_signal = EXCLUDED.triple_signal,
    bluf = EXCLUDED.bluf,
    price = EXCLUDED.price,
    upside = EXCLUDED.upside,
    market_cap = EXCLUDED.market_cap,
    probability = EXCLUDED.probability,
    catalyst = EXCLUDED.catalyst,
    council = EXCLUDED.council,
    buy_zones = EXCLUDED.buy_zones,
    bull_case = EXCLUDED.bull_case,
    bear_case = EXCLUDED.bear_case,
    financials = EXCLUDED.financials,
    red_flags = EXCLUDED.red_flags,
    invalidation = EXCLUDED.invalidation;

-- ============================================================================
-- 5. RLS policies — public read for opportunity_feed, authenticated for watchlist
-- ============================================================================
ALTER TABLE opportunity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_watchlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

-- Anyone can read the feed (anon key)
DROP POLICY IF EXISTS "Public read" ON opportunity_feed;
CREATE POLICY "Public read" ON opportunity_feed
    FOR SELECT USING (true);

-- Watchlist: users can only see their own
DROP POLICY IF EXISTS "Users manage own watchlist" ON user_watchlist;
CREATE POLICY "Users manage own watchlist" ON user_watchlist
    FOR ALL USING (auth.uid()::text = user_id)
    WITH CHECK (auth.uid()::text = user_id);

-- Push tokens: users manage their own
DROP POLICY IF EXISTS "Users manage own tokens" ON push_tokens;
CREATE POLICY "Users manage own tokens" ON push_tokens
    FOR ALL USING (auth.uid()::text = user_id)
    WITH CHECK (auth.uid()::text = user_id);

-- ============================================================================
-- 6. Watchlist RPC function
-- ============================================================================
CREATE OR REPLACE FUNCTION get_watchlist(user_id text)
RETURNS SETOF opportunity_feed
LANGUAGE sql
AS $$
    SELECT o.*
    FROM opportunity_feed o
    JOIN user_watchlist w ON w.opportunity_id = o.id
    WHERE w.user_id = get_watchlist.user_id
    ORDER BY o.published_at DESC;
$$;
