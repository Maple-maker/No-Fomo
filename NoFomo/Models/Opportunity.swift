import Foundation

// MARK: - Core opportunity model (maps to opportunity_feed Supabase table)
// Updated to match No Fomo design prototype data schema

struct Opportunity: Identifiable, Codable {
    let id: String
    let ticker: String
    let companyName: String
    var sector: String
    let tier: Int
    var score: Double
    var tripleSignal: Bool
    let bluf: String

    // Price / metrics
    var price: Double
    var upside: Double
    var marketCap: String
    var probability: Double
    let catalyst: String

    // AI Council
    var council: AICouncil

    // Buy zones
    var buyZones: BuyZones

    // Detail content
    let bullCase: String
    let bearCase: String
    var financials: [[String]]
    var redFlags: [String]
    var invalidation: String

    // Supabase-compatible fields
    let isPremium: Bool
    let publishedAt: Date

    // Legacy / optional fields for backward compatibility
    var overallScore: Double   // alias for score (used by old code)
    var isTripleSignal: Bool   // alias for tripleSignal
    var geminiVerdict: Verdict
    var deepseekVerdict: Verdict
    var debateVerdict: Verdict
    var buyZoneAggressive: Double?
    var buyZoneBase: Double?
    var buyZoneConservative: Double?
    var probabilityScore: Double
    var upsidePct: Double?
    var snap: FinancialSnapshot?
    var thesis: String?
    var sourceCompany: String?
    var sourceQuote: String?
    var marketMiss: String
    var invalidationTrigger: String
    var targetPrice: Double?
    var floorPrice: Double?
    var asymmetryScore: Int
    var convictionScore: Int
    var catalystScore: Int
    var managementScore: Int
    var downsidePct: Double?
    var smartMoneyScore: Int?
    var marketCapScore: Int?
    var fullReportMd: String?

    // MARK: Memberwise init (for mock data)
    init(id: String, ticker: String, companyName: String, sector: String = "", tier: Int,
         score: Double = 0, tripleSignal: Bool = false, bluf: String,
         price: Double = 0, upside: Double = 0, marketCap: String = "", probability: Double = 0,
         catalyst: String, council: AICouncil = AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
         buyZones: BuyZones = BuyZones(aggressive: 0, base: 0, conservative: 0),
         bullCase: String = "", bearCase: String = "", financials: [[String]] = [],
         redFlags: [String] = [], invalidation: String = "",
         isPremium: Bool = false, publishedAt: Date = Date(),
         overallScore: Double? = nil, isTripleSignal: Bool? = nil,
         geminiVerdict: Verdict? = nil, deepseekVerdict: Verdict? = nil, debateVerdict: Verdict? = nil,
         buyZoneAggressive: Double? = nil, buyZoneBase: Double? = nil, buyZoneConservative: Double? = nil,
         probabilityScore: Double? = nil, upsidePct: Double? = nil,
         snap: FinancialSnapshot? = nil, thesis: String? = nil,
         sourceCompany: String? = nil, sourceQuote: String? = nil,
         marketMiss: String = "", invalidationTrigger: String? = nil,
         targetPrice: Double? = nil, floorPrice: Double? = nil,
         asymmetryScore: Int = 0, convictionScore: Int = 0, catalystScore: Int = 0, managementScore: Int = 0,
         downsidePct: Double? = nil, smartMoneyScore: Int? = nil, marketCapScore: Int? = nil,
         fullReportMd: String? = nil) {
        self.id = id; self.ticker = ticker; self.companyName = companyName; self.sector = sector
        self.tier = tier; self.score = score; self.tripleSignal = tripleSignal; self.bluf = bluf
        self.price = price; self.upside = upside; self.marketCap = marketCap; self.probability = probability
        self.catalyst = catalyst; self.council = council; self.buyZones = buyZones
        self.bullCase = bullCase; self.bearCase = bearCase; self.financials = financials
        self.redFlags = redFlags; self.invalidation = invalidation
        self.isPremium = isPremium; self.publishedAt = publishedAt
        self.overallScore = overallScore ?? score
        self.isTripleSignal = isTripleSignal ?? tripleSignal
        self.geminiVerdict = geminiVerdict ?? council.gemini
        self.deepseekVerdict = deepseekVerdict ?? council.deepseek
        self.debateVerdict = debateVerdict ?? council.cio
        self.buyZoneAggressive = buyZoneAggressive ?? buyZones.aggressive
        self.buyZoneBase = buyZoneBase ?? buyZones.base
        self.buyZoneConservative = buyZoneConservative ?? buyZones.conservative
        self.probabilityScore = probabilityScore ?? probability
        self.upsidePct = upsidePct ?? upside
        self.snap = snap; self.thesis = thesis
        self.sourceCompany = sourceCompany; self.sourceQuote = sourceQuote
        self.marketMiss = marketMiss
        self.invalidationTrigger = invalidationTrigger ?? invalidation
        self.targetPrice = targetPrice; self.floorPrice = floorPrice
        self.asymmetryScore = asymmetryScore; self.convictionScore = convictionScore
        self.catalystScore = catalystScore; self.managementScore = managementScore
        self.downsidePct = downsidePct
        self.smartMoneyScore = smartMoneyScore; self.marketCapScore = marketCapScore
        self.fullReportMd = fullReportMd
    }

    // MARK: Custom decoding for Supabase compatibility
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        ticker = try c.decode(String.self, forKey: .ticker)
        companyName = try c.decode(String.self, forKey: .companyName)
        tier = try c.decode(Int.self, forKey: .tier)
        bluf = try c.decode(String.self, forKey: .bluf)
        catalyst = try c.decode(String.self, forKey: .catalyst)
        bullCase = try c.decodeIfPresent(String.self, forKey: .bullCase) ?? ""
        bearCase = try c.decodeIfPresent(String.self, forKey: .bearCase) ?? ""
        isPremium = try c.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        publishedAt = try c.decodeIfPresent(Date.self, forKey: .publishedAt) ?? Date()

        // New design-prototype fields with fallbacks
        sector = try c.decodeIfPresent(String.self, forKey: .sector) ?? ""
        score = try c.decodeIfPresent(Double.self, forKey: .score) ?? c.decodeIfPresent(Double.self, forKey: .overallScore) ?? 0
        tripleSignal = try c.decodeIfPresent(Bool.self, forKey: .tripleSignal) ?? c.decodeIfPresent(Bool.self, forKey: .isTripleSignal) ?? false
        price = try c.decodeIfPresent(Double.self, forKey: .price) ?? c.decodeIfPresent(FinancialSnapshot.self, forKey: .snap)?.price ?? 0
        upside = try c.decodeIfPresent(Double.self, forKey: .upside) ?? c.decodeIfPresent(Double.self, forKey: .upsidePct) ?? 0
        marketCap = try c.decodeIfPresent(String.self, forKey: .marketCap) ?? "N/A"
        probability = try c.decodeIfPresent(Double.self, forKey: .probability) ?? c.decodeIfPresent(Double.self, forKey: .probabilityScore) ?? 0
        council = try c.decodeIfPresent(AICouncil.self, forKey: .council) ?? AICouncil(gemini: .bull, deepseek: .bull, cio: .bull)
        buyZones = try c.decodeIfPresent(BuyZones.self, forKey: .buyZones) ?? BuyZones(
            aggressive: c.decodeIfPresent(Double.self, forKey: .buyZoneAggressive) ?? 0,
            base: c.decodeIfPresent(Double.self, forKey: .buyZoneBase) ?? 0,
            conservative: c.decodeIfPresent(Double.self, forKey: .buyZoneConservative) ?? 0
        )
        financials = try c.decodeIfPresent([[String]].self, forKey: .financials) ?? []
        redFlags = try c.decodeIfPresent([String].self, forKey: .redFlags) ?? []
        invalidation = try c.decodeIfPresent(String.self, forKey: .invalidation) ?? c.decodeIfPresent(String.self, forKey: .invalidationTrigger) ?? ""

        // Legacy fields
        overallScore = try c.decodeIfPresent(Double.self, forKey: .overallScore) ?? score
        isTripleSignal = try c.decodeIfPresent(Bool.self, forKey: .isTripleSignal) ?? tripleSignal
        geminiVerdict = try c.decodeIfPresent(Verdict.self, forKey: .geminiVerdict) ?? council.gemini
        deepseekVerdict = try c.decodeIfPresent(Verdict.self, forKey: .deepseekVerdict) ?? council.deepseek
        debateVerdict = try c.decodeIfPresent(Verdict.self, forKey: .debateVerdict) ?? council.cio
        buyZoneAggressive = try c.decodeIfPresent(Double.self, forKey: .buyZoneAggressive) ?? buyZones.aggressive
        buyZoneBase = try c.decodeIfPresent(Double.self, forKey: .buyZoneBase) ?? buyZones.base
        buyZoneConservative = try c.decodeIfPresent(Double.self, forKey: .buyZoneConservative) ?? buyZones.conservative
        probabilityScore = try c.decodeIfPresent(Double.self, forKey: .probabilityScore) ?? probability
        upsidePct = try c.decodeIfPresent(Double.self, forKey: .upsidePct) ?? upside
        snap = try c.decodeIfPresent(FinancialSnapshot.self, forKey: .snap)
        thesis = try c.decodeIfPresent(String.self, forKey: .thesis)
        sourceCompany = try c.decodeIfPresent(String.self, forKey: .sourceCompany)
        sourceQuote = try c.decodeIfPresent(String.self, forKey: .sourceQuote)
        marketMiss = try c.decodeIfPresent(String.self, forKey: .marketMiss) ?? ""
        invalidationTrigger = try c.decodeIfPresent(String.self, forKey: .invalidationTrigger) ?? invalidation
        targetPrice = try c.decodeIfPresent(Double.self, forKey: .targetPrice)
        floorPrice = try c.decodeIfPresent(Double.self, forKey: .floorPrice)
        asymmetryScore = try c.decodeIfPresent(Int.self, forKey: .asymmetryScore) ?? 0
        convictionScore = try c.decodeIfPresent(Int.self, forKey: .convictionScore) ?? 0
        catalystScore = try c.decodeIfPresent(Int.self, forKey: .catalystScore) ?? 0
        managementScore = try c.decodeIfPresent(Int.self, forKey: .managementScore) ?? 0
        downsidePct = try c.decodeIfPresent(Double.self, forKey: .downsidePct)
        smartMoneyScore = try c.decodeIfPresent(Int.self, forKey: .smartMoneyScore)
        marketCapScore = try c.decodeIfPresent(Int.self, forKey: .marketCapScore)
        fullReportMd = try c.decodeIfPresent(String.self, forKey: .fullReportMd)
    }

    enum CodingKeys: String, CodingKey {
        case id, ticker
        case companyName = "company_name"
        case sector
        case tier
        case score
        case tripleSignal = "triple_signal"
        case bluf
        case price
        case upside
        case marketCap = "market_cap"
        case probability
        case catalyst
        case council
        case buyZones = "buy_zones"
        case bullCase = "bull_case"
        case bearCase = "bear_case"
        case financials
        case redFlags = "red_flags"
        case invalidation
        case isPremium = "is_premium"
        case publishedAt = "published_at"
        // Legacy
        case overallScore = "overall_score"
        case isTripleSignal = "is_triple_signal"
        case geminiVerdict = "gemini_verdict"
        case deepseekVerdict = "deepseek_verdict"
        case debateVerdict = "debate_verdict"
        case buyZoneAggressive = "buy_zone_aggressive"
        case buyZoneBase = "buy_zone_base"
        case buyZoneConservative = "buy_zone_conservative"
        case probabilityScore = "probability_score"
        case upsidePct = "upside_pct"
        case snap
        case thesis
        case sourceCompany = "source_company"
        case sourceQuote = "source_quote"
        case marketMiss = "market_miss"
        case invalidationTrigger = "invalidation_trigger"
        case targetPrice = "target_price"
        case floorPrice = "floor_price"
        case asymmetryScore = "asymmetry_score"
        case convictionScore = "conviction_score"
        case catalystScore = "catalyst_score"
        case managementScore = "management_score"
        case downsidePct = "downside_pct"
        case smartMoneyScore = "smart_money_score"
        case marketCapScore = "market_cap_score"
        case fullReportMd = "full_report_md"
    }
}

// MARK: - Nested types

struct AICouncil: Codable {
    let gemini: Verdict
    let deepseek: Verdict
    let cio: Verdict
}

struct BuyZones: Codable {
    let aggressive: Double
    let base: Double
    let conservative: Double
}

struct FinancialSnapshot: Codable {
    let price: Double?
    let mktCap: Double?
    let pe: Double?
    let evToEbitda: Double?
    let psRatioTTM: Double?
    let pfcfRatioTTM: Double?
    let grossMarginTTM: Double?
    let revenueGrowthTTM: Double?
    let beta: Double?
    let sector: String?
    let industry: String?

    var formattedMarketCap: String {
        guard let cap = mktCap else { return "N/A" }
        if cap >= 1_000_000_000 { return "$\(String(format: "%.1f", cap / 1_000_000_000))B" }
        return "$\(String(format: "%.0f", cap / 1_000_000))M"
    }
}

// MARK: - Mock data (matching prototype exactly)

extension Opportunity {
    static let mockCRVO = makeMock(
        id: "crvo", tier: 1, ticker: "CRVO", name: "Corvus Therapeutics",
        sector: "Biotech · Oncology", score: 91, tripleSignal: true,
        bluf: "FDA granted accelerated approval for CRV-431 in hepatocellular carcinoma. Two insiders bought $4.1M of stock 9 days prior. Market has not repriced the label expansion.",
        price: 38.42, upside: 142, marketCap: "1.2B", probability: 78,
        catalyst: "FDA accelerated approval",
        council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
        buyZones: BuyZones(aggressive: 41.20, base: 37.80, conservative: 33.50),
        bullCase: "First-in-class cyclophilin inhibitor with a clean safety profile and a label that opens a $3.4B addressable market. Insider cluster-buying at $34 signals conviction from people who read the data before the Street. Cash runway through 2028 removes dilution overhang.",
        bearCase: "Accelerated approval requires a confirmatory Phase 3 — a miss in 2027 unwinds the thesis. Single-asset concentration. Commercial launch execution is unproven for a company that has never sold a drug.",
        financials: [
            ["Revenue (TTM)", "$0"],
            ["Cash & equivalents", "$612M"],
            ["Burn (quarterly)", "$48M"],
            ["Runway", "Q1 2028"],
            ["Float", "31.2M sh"],
            ["Short interest", "14.3%"],
        ],
        redFlags: [
            "Confirmatory Phase 3 read-out risk in 2027",
            "Zero commercial revenue history",
            "14% short interest can squeeze both ways",
        ],
        invalidation: "Confirmatory trial enrollment slips past Q3 2026, or label gets a boxed warning."
    )

    static let mockHDRN = makeMock(
        id: "hdrn", tier: 2, ticker: "HDRN", name: "Hadrian Defense Systems",
        sector: "Defense · Autonomy", score: 84, tripleSignal: false,
        bluf: "Awarded $890M IDIQ ceiling on the Army's counter-UAS program. Backlog now exceeds 3x trailing revenue. Street models still anchor to the pre-award run rate.",
        price: 62.18, upside: 64, marketCap: "4.8B", probability: 71,
        catalyst: "Government contract award",
        council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
        buyZones: BuyZones(aggressive: 66.00, base: 60.50, conservative: 54.00),
        bullCase: "IDIQ ceiling converts to firm orders as counter-drone budgets compound at 22% CAGR. Sole-source position on a program of record means pricing power and multi-year visibility. Free cash flow inflects positive next fiscal year.",
        bearCase: "IDIQ is a ceiling, not a guarantee — funding is appropriated annually and subject to continuing-resolution risk. Valuation already prices a clean conversion. Customer concentration in a single agency.",
        financials: [
            ["Revenue (TTM)", "$1.6B"],
            ["Gross margin", "38%"],
            ["Backlog", "$5.1B"],
            ["Net debt", "$340M"],
            ["FCF (TTM)", "-$12M"],
            ["Insider own.", "9.4%"],
        ],
        redFlags: [
            "IDIQ ceiling ≠ funded orders",
            "Continuing-resolution / shutdown exposure",
            "Single-agency customer concentration",
        ],
        invalidation: "FY funding comes in below the program's authorized level, or a protest delays award."
    )

    static let mockAETH = makeMock(
        id: "aeth", tier: 2, ticker: "AETH", name: "Aether Compute",
        sector: "Semis · AI Infrastructure", score: 79, tripleSignal: false,
        bluf: "Named a qualified supplier in a hyperscaler's custom-silicon RFP. Earnings transcript flagged a 'multi-year framework' without naming the partner. Supply-chain checks corroborate ramp.",
        price: 114.60, upside: 53, marketCap: "11.3B", probability: 66,
        catalyst: "Tech-giant partnership",
        council: AICouncil(gemini: .bull, deepseek: .bear, cio: .bull),
        buyZones: BuyZones(aggressive: 121.00, base: 109.00, conservative: 96.00),
        bullCase: "Qualification on a hyperscaler's accelerator program is a multi-year annuity that the market underwrites only after revenue prints. Design wins are sticky; switching costs are high. Gross margin mix shifts up as custom volume scales.",
        bearCase: "Framework language is non-binding and partner is unconfirmed. Hyperscaler in-housing risk is real. At 11x forward sales, any ramp slippage compresses the multiple hard. DeepSeek flags inventory build ahead of orders.",
        financials: [
            ["Revenue (TTM)", "$2.1B"],
            ["Gross margin", "54%"],
            ["Fwd P/S", "11.2x"],
            ["Net cash", "$1.8B"],
            ["R&D / rev", "29%"],
            ["Insider own.", "6.1%"],
        ],
        redFlags: [
            "Partner unconfirmed; framework non-binding",
            "Hyperscaler in-sourcing risk",
            "Premium multiple leaves no room for slips",
        ],
        invalidation: "Next two transcripts pass without a named design win, or inventory days keep rising."
    )

    static let mockMRDN = makeMock(
        id: "mrdn", tier: 1, ticker: "MRDN", name: "Meridian Energy",
        sector: "Energy · Grid Storage", score: 88, tripleSignal: true,
        bluf: "DOE loan guarantee closed on a 4-state grid-storage buildout. CEO and CFO bought a combined $6.8M in the open market the same week. Catalyst is funded, not announced.",
        price: 21.07, upside: 96, marketCap: "2.9B", probability: 74,
        catalyst: "DOE loan + insider cluster",
        council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
        buyZones: BuyZones(aggressive: 22.40, base: 20.10, conservative: 17.60),
        bullCase: "Federal loan guarantee de-risks the capex cycle and locks in below-market financing. Two C-suite open-market buys at $19 is the strongest insider signal in the book. Contracted offtake covers 80% of phase-one capacity.",
        bearCase: "Interest-rate sensitivity on a capital-intensive build. Execution risk across four jurisdictions simultaneously. Loan disbursement is milestone-gated — slippage delays the revenue ramp.",
        financials: [
            ["Revenue (TTM)", "$540M"],
            ["Gross margin", "26%"],
            ["DOE facility", "$1.1B"],
            ["Contracted offtake", "80%"],
            ["Net debt", "$210M"],
            ["Insider own.", "12.8%"],
        ],
        redFlags: [
            "Capital-intensive build, rate-sensitive",
            "Four-jurisdiction execution risk",
            "Milestone-gated loan disbursement",
        ],
        invalidation: "A phase-one milestone slips two quarters, or offtake counterparties renegotiate."
    )

    static let mockSOLS = makeMock(
        id: "sols", tier: 2, ticker: "SOLS", name: "Solstice Materials",
        sector: "Materials · Lithium", score: 76, tripleSignal: false,
        bluf: "Signed binding supply agreement with a top-three EV maker. Resource estimate upgraded 40% on infill drilling. Lithium spot has bottomed on cost-curve support.",
        price: 8.94, upside: 71, marketCap: "1.6B", probability: 62,
        catalyst: "Binding offtake + resource upgrade",
        council: AICouncil(gemini: .bull, deepseek: .bear, cio: .bull),
        buyZones: BuyZones(aggressive: 9.60, base: 8.40, conservative: 7.10),
        bullCase: "Binding offtake with a marquee OEM validates the deposit and underwrites project financing. Resource upgrade extends mine life and lowers unit costs. Lithium price has found a floor at the marginal cost of production.",
        bearCase: "Commodity-price taker with no control over the cycle. Permitting and construction are years out. DeepSeek flags dilution risk to fund the build. Spot lithium could overshoot to the downside before recovering.",
        financials: [
            ["Revenue (TTM)", "$0"],
            ["Cash", "$185M"],
            ["Resource (M&I)", "+40%"],
            ["First production", "2028E"],
            ["Net debt", "$0"],
            ["Insider own.", "7.7%"],
        ],
        redFlags: [
            "Pure commodity-price exposure",
            "Pre-revenue; first production years out",
            "Likely equity dilution to fund capex",
        ],
        invalidation: "Lithium breaks the cost-curve floor, or permitting timeline slips past 2026."
    )

    static let mocks: [Opportunity] = [mockCRVO, mockHDRN, mockAETH, mockMRDN, mockSOLS]

    // Legacy mock kept for backward compat
    static let mock = mockCRVO

    // MARK: Factory

    private static func makeMock(
        id: String, tier: Int, ticker: String, name: String, sector: String,
        score: Double, tripleSignal: Bool, bluf: String,
        price: Double, upside: Double, marketCap: String, probability: Double,
        catalyst: String, council: AICouncil, buyZones: BuyZones,
        bullCase: String, bearCase: String, financials: [[String]],
        redFlags: [String], invalidation: String
    ) -> Opportunity {
        Opportunity(
            id: id, ticker: ticker, companyName: name, sector: sector,
            tier: tier, score: score, tripleSignal: tripleSignal, bluf: bluf,
            price: price, upside: upside, marketCap: marketCap, probability: probability,
            catalyst: catalyst, council: council, buyZones: buyZones,
            bullCase: bullCase, bearCase: bearCase, financials: financials,
            redFlags: redFlags, invalidation: invalidation,
            isPremium: true, publishedAt: Date(),
            overallScore: score, isTripleSignal: tripleSignal,
            geminiVerdict: council.gemini, deepseekVerdict: council.deepseek,
            debateVerdict: council.cio,
            buyZoneAggressive: buyZones.aggressive,
            buyZoneBase: buyZones.base,
            buyZoneConservative: buyZones.conservative,
            probabilityScore: probability, upsidePct: upside,
            snap: FinancialSnapshot(price: price, mktCap: nil, pe: nil, evToEbitda: nil,
                                     psRatioTTM: nil, pfcfRatioTTM: nil, grossMarginTTM: nil,
                                     revenueGrowthTTM: nil, beta: nil, sector: sector, industry: nil),
            thesis: nil, sourceCompany: nil, sourceQuote: nil,
            marketMiss: "", invalidationTrigger: invalidation,
            targetPrice: nil, floorPrice: nil,
            asymmetryScore: 0, convictionScore: 0, catalystScore: 0, managementScore: 0,
            downsidePct: nil, smartMoneyScore: nil, marketCapScore: nil, fullReportMd: nil
        )
    }
}
