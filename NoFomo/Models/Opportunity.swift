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
    let notificationLine: String

    // Happening Now
    var priceChangePct: Double
    var taSummary: String
    var aiSynopsis: String

    // AI model reasoning + evidence
    var geminiReasoning: String
    var deepseekReasoning: String
    var cioReasoning: String

    // Evidence layer
    var recentHeadlines: [[String]]
    var sources: [[String]]
    var upcomingEvents: [[String]]

    // Price chart
    var priceHistory: [Double]

    // Trading & technicals
    var rsiValue: Double
    var rsiSignal: String
    var macdTrend: String
    var volumeVsAvg: Double
    var supportLevel: Double
    var resistanceLevel: Double

    // Filtering
    var tags: [String]

    // Analyst consensus
    var analystConsensus: String
    var analystCount: Int
    var avgPriceTarget: Double
    var analystHighTarget: Double
    var analystLowTarget: Double
    var recentAnalystActions: [[String]]

    // Institutional / 13F
    var institutionalOwnershipPct: Double
    var institutionalFlow: String
    var topHolder: String

    // Supabase-compatible fields
    let isPremium: Bool
    let publishedAt: Date

    // Legacy / optional fields for backward compatibility
    var overallScore: Double
    var isTripleSignal: Bool
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

    // ── New radar dossier fields ──
    var radarDossier: String?
    var researchedAt: String?
    var bullCaseItems: [String]
    var bearCaseItems: [String]
    var businessModelSummary: String?
    var macroContext: String?
    var insiderActivity: String?
    var governmentSupport: String?
    var indirectCatalysts: String?
    var overlookedAnalysis: String?
    var detectionLane: String?
    var governmentScore: Int?

    // MARK: Memberwise init (for mock data)
    init(id: String, ticker: String, companyName: String, sector: String = "", tier: Int,
         score: Double = 0, tripleSignal: Bool = false, bluf: String,
         price: Double = 0, upside: Double = 0, marketCap: String = "", probability: Double = 0,
         catalyst: String, council: AICouncil = AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
         buyZones: BuyZones = BuyZones(aggressive: 0, base: 0, conservative: 0),
         bullCase: String = "", bearCase: String = "", financials: [[String]] = [],
         redFlags: [String] = [], invalidation: String = "", notificationLine: String = "",
         priceChangePct: Double = 0, taSummary: String = "", aiSynopsis: String = "",
         geminiReasoning: String = "", deepseekReasoning: String = "", cioReasoning: String = "",
         recentHeadlines: [[String]] = [], sources: [[String]] = [], upcomingEvents: [[String]] = [], tags: [String] = [],
         priceHistory: [Double] = [],
         rsiValue: Double = 50, rsiSignal: String = "neutral", macdTrend: String = "neutral",
         volumeVsAvg: Double = 1.0, supportLevel: Double = 0, resistanceLevel: Double = 0,
         analystConsensus: String = "", analystCount: Int = 0, avgPriceTarget: Double = 0,
         analystHighTarget: Double = 0, analystLowTarget: Double = 0, recentAnalystActions: [[String]] = [],
         institutionalOwnershipPct: Double = 0, institutionalFlow: String = "flat", topHolder: String = "",
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
         fullReportMd: String? = nil,
         radarDossier: String? = nil, researchedAt: String? = nil,
         bullCaseItems: [String] = [], bearCaseItems: [String] = [],
         businessModelSummary: String? = nil, macroContext: String? = nil,
         insiderActivity: String? = nil, governmentSupport: String? = nil,
         indirectCatalysts: String? = nil, overlookedAnalysis: String? = nil,
         detectionLane: String? = nil, governmentScore: Int? = nil) {
        self.id = id; self.ticker = ticker; self.companyName = companyName; self.sector = sector
        self.tier = tier; self.score = score; self.tripleSignal = tripleSignal; self.bluf = bluf
        self.price = price; self.upside = upside; self.marketCap = marketCap; self.probability = probability
        self.catalyst = catalyst; self.council = council; self.buyZones = buyZones
        self.bullCase = bullCase; self.bearCase = bearCase; self.financials = financials
        self.redFlags = redFlags; self.invalidation = invalidation; self.notificationLine = notificationLine
        self.priceChangePct = priceChangePct; self.taSummary = taSummary; self.aiSynopsis = aiSynopsis
        self.geminiReasoning = geminiReasoning; self.deepseekReasoning = deepseekReasoning; self.cioReasoning = cioReasoning
        self.recentHeadlines = recentHeadlines; self.sources = sources; self.upcomingEvents = upcomingEvents; self.tags = tags
        self.priceHistory = priceHistory
        self.rsiValue = rsiValue; self.rsiSignal = rsiSignal; self.macdTrend = macdTrend
        self.volumeVsAvg = volumeVsAvg; self.supportLevel = supportLevel; self.resistanceLevel = resistanceLevel
        self.institutionalOwnershipPct = institutionalOwnershipPct; self.institutionalFlow = institutionalFlow; self.topHolder = topHolder
        self.analystConsensus = analystConsensus; self.analystCount = analystCount; self.avgPriceTarget = avgPriceTarget
        self.analystHighTarget = analystHighTarget; self.analystLowTarget = analystLowTarget; self.recentAnalystActions = recentAnalystActions
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
        self.radarDossier = radarDossier; self.researchedAt = researchedAt
        self.bullCaseItems = bullCaseItems; self.bearCaseItems = bearCaseItems
        self.businessModelSummary = businessModelSummary; self.macroContext = macroContext
        self.insiderActivity = insiderActivity; self.governmentSupport = governmentSupport
        self.indirectCatalysts = indirectCatalysts; self.overlookedAnalysis = overlookedAnalysis
        self.detectionLane = detectionLane; self.governmentScore = governmentScore
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
        notificationLine = try c.decodeIfPresent(String.self, forKey: .notificationLine) ?? ""
        priceChangePct = try c.decodeIfPresent(Double.self, forKey: .priceChangePct) ?? 0
        taSummary = try c.decodeIfPresent(String.self, forKey: .taSummary) ?? ""
        aiSynopsis = try c.decodeIfPresent(String.self, forKey: .aiSynopsis) ?? ""
        geminiReasoning = try c.decodeIfPresent(String.self, forKey: .geminiReasoning) ?? ""
        deepseekReasoning = try c.decodeIfPresent(String.self, forKey: .deepseekReasoning) ?? ""
        cioReasoning = try c.decodeIfPresent(String.self, forKey: .cioReasoning) ?? ""
        recentHeadlines = try c.decodeIfPresent([[String]].self, forKey: .recentHeadlines) ?? []
        sources = try c.decodeIfPresent([[String]].self, forKey: .sources) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        upcomingEvents = try c.decodeIfPresent([[String]].self, forKey: .upcomingEvents) ?? []
        priceHistory = try c.decodeIfPresent([Double].self, forKey: .priceHistory) ?? []
        rsiValue = try c.decodeIfPresent(Double.self, forKey: .rsiValue) ?? 50
        rsiSignal = try c.decodeIfPresent(String.self, forKey: .rsiSignal) ?? "neutral"
        macdTrend = try c.decodeIfPresent(String.self, forKey: .macdTrend) ?? "neutral"
        volumeVsAvg = try c.decodeIfPresent(Double.self, forKey: .volumeVsAvg) ?? 1.0
        supportLevel = try c.decodeIfPresent(Double.self, forKey: .supportLevel) ?? 0
        resistanceLevel = try c.decodeIfPresent(Double.self, forKey: .resistanceLevel) ?? 0
        institutionalOwnershipPct = try c.decodeIfPresent(Double.self, forKey: .institutionalOwnershipPct) ?? 0
        institutionalFlow = try c.decodeIfPresent(String.self, forKey: .institutionalFlow) ?? "flat"
        topHolder = try c.decodeIfPresent(String.self, forKey: .topHolder) ?? ""
        analystConsensus = try c.decodeIfPresent(String.self, forKey: .analystConsensus) ?? ""
        analystCount = try c.decodeIfPresent(Int.self, forKey: .analystCount) ?? 0
        avgPriceTarget = try c.decodeIfPresent(Double.self, forKey: .avgPriceTarget) ?? 0
        analystHighTarget = try c.decodeIfPresent(Double.self, forKey: .analystHighTarget) ?? 0
        analystLowTarget = try c.decodeIfPresent(Double.self, forKey: .analystLowTarget) ?? 0
        recentAnalystActions = try c.decodeIfPresent([[String]].self, forKey: .recentAnalystActions) ?? []

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
        radarDossier = try c.decodeIfPresent(String.self, forKey: .radarDossier)
        researchedAt = try c.decodeIfPresent(String.self, forKey: .researchedAt)
        bullCaseItems = try c.decodeIfPresent([String].self, forKey: .bullCaseItems) ?? []
        bearCaseItems = try c.decodeIfPresent([String].self, forKey: .bearCaseItems) ?? []
        businessModelSummary = try c.decodeIfPresent(String.self, forKey: .businessModelSummary)
        macroContext = try c.decodeIfPresent(String.self, forKey: .macroContext)
        insiderActivity = try c.decodeIfPresent(String.self, forKey: .insiderActivity)
        governmentSupport = try c.decodeIfPresent(String.self, forKey: .governmentSupport)
        indirectCatalysts = try c.decodeIfPresent(String.self, forKey: .indirectCatalysts)
        overlookedAnalysis = try c.decodeIfPresent(String.self, forKey: .overlookedAnalysis)
        detectionLane = try c.decodeIfPresent(String.self, forKey: .detectionLane)
        governmentScore = try c.decodeIfPresent(Int.self, forKey: .governmentScore)
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
        case notificationLine = "notification_line"
        case priceChangePct = "price_change_pct"
        case taSummary = "ta_summary"
        case aiSynopsis = "ai_synopsis"
        case geminiReasoning = "gemini_reasoning"
        case deepseekReasoning = "deepseek_reasoning"
        case cioReasoning = "cio_reasoning"
        case recentHeadlines = "recent_headlines"
        case sources = "sources"
        case tags
        case upcomingEvents = "upcoming_events"
        case priceHistory = "price_history"
        case rsiValue = "rsi_value"
        case rsiSignal = "rsi_signal"
        case macdTrend = "macd_trend"
        case volumeVsAvg = "volume_vs_avg"
        case supportLevel = "support_level"
        case resistanceLevel = "resistance_level"
        case institutionalOwnershipPct = "institutional_ownership_pct"
        case institutionalFlow = "institutional_flow"
        case topHolder = "top_holder"
        case analystConsensus = "analyst_consensus"
        case analystCount = "analyst_count"
        case avgPriceTarget = "avg_price_target"
        case analystHighTarget = "analyst_high_target"
        case analystLowTarget = "analyst_low_target"
        case recentAnalystActions = "recent_analyst_actions"
        case isPremium = "is_premium"
        case publishedAt = "published_at"
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
        case radarDossier = "radar_dossier"
        case researchedAt = "researched_at"
        case bullCaseItems = "bull_case_items"
        case bearCaseItems = "bear_case_items"
        case businessModelSummary = "business_model_summary"
        case macroContext = "macro_context"
        case insiderActivity = "insider_activity"
        case governmentSupport = "government_support"
        case indirectCatalysts = "indirect_catalysts"
        case overlookedAnalysis = "overlooked_analysis"
        case detectionLane = "detection_lane"
        case governmentScore = "government_score"
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

// MARK: - Mock data (real companies)

extension Opportunity {
    static let mockPLTR = makeMock(
        id: "pltr", tier: 1, ticker: "PLTR", name: "Palantir Technologies",
        sector: "Defense · AI/ML", score: 88, tripleSignal: true,
        bluf: "AIP bootcamps converting pilots into 7-figure contracts in weeks. Maven Smart System expanding across DoD. Founder-led, profitable, $4B+ cash. Government + commercial flywheel is accelerating.",
        price: 137.78, upside: 72, marketCap: "330.3B", probability: 74,
        catalyst: "AIP commercial acceleration + defense budget cycle",
        council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
        buyZones: BuyZones(aggressive: 142.00, base: 130.00, conservative: 115.00),
        bullCase: "AIP has become the enterprise AI operating system. Bootcamp-to-contract conversion is compressing sales cycles from 12 months to weeks. Government backlog is expanding with Maven Smart System and TITAN. Founder-led (Karp + Thiel) with a mission-critical moat — no one rips out Palantir once it's embedded in an intelligence or defense workflow. $4B+ cash, effectively debt-free, GAAP profitable. Operating leverage is just beginning to show.",
        bearCase: "At 25x trailing revenue, all the good news is priced in. Government contracts face continuing-resolution and shutdown risk. Commercial acceleration narrative is real but the multiple is stretched — any deceleration in growth rate crushes the stock. Founder Alex Karp has sold shares under a 10b5-1 plan, which while pre-scheduled, limits near-term insider conviction signal.",
        financials: [
            ["Revenue (TTM)", "$3.2B"],
            ["Revenue Growth", "36%"],
            ["Gross Margin", "82%"],
            ["Operating Margin", "23%"],
            ["Cash & Equivalents", "$4.1B"],
            ["Net Debt", "$0"],
            ["FCF (TTM)", "$1.1B"],
        ],
        redFlags: [
            "25x revenue multiple — growth must sustain 30%+ to justify",
            "Government contract exposure to budget cycles and CRs",
            "Karp 10b5-1 selling plan removes insider conviction signal",
        ],
        invalidation: "Commercial revenue growth decelerates below 25% for two consecutive quarters, or a major government contract loss.",
        notificationLine: "🔔 DoD Maven Smart System expansion across combatant commands. AIP bootcamp pipeline at record levels.",
        priceChangePct: -2.77,
        taSummary: "RSI 46 neutral · MACD bullish · 0.3x avg vol",
        aiSynopsis: "Palantir pulled back with the broader market today. AIP commercial conversion story intact — bootcamps compressing enterprise sales cycles. Government momentum building with Maven Smart System expanding to new combatant commands. [Read the latest earnings call →](https://www.sec.gov)",
        geminiReasoning: "AIP is the most successful enterprise AI deployment story in the market. Bootcamp-to-contract conversion rates are industry-leading. Government business has a multi-decade tailwind from defense modernization budgets. $4B cash + GAAP profitability + 84% gross margins = quality compounding. The operating system for the intelligence community doesn't get replaced. Founder-led with deep government relationships creates a moat competitors cannot replicate.",
        deepseekReasoning: "At 63x trailing revenue, Palantir is priced for perfection — any growth deceleration triggers significant multiple compression. Government revenue is lumpy and subject to continuing-resolution risk. Commercial growth, while impressive, is coming off a smaller base than the multiple implies. The AI platform space is increasingly crowded (Microsoft, Databricks, Snowflake all competing). At $330B market cap, the growth trajectory must be flawless for years.",
        cioReasoning: "Gemini is right on the moat — Palantir's government entrenchment is generational. DeepSeek is right on valuation — 63x revenue leaves no room for error. Verdict: 60/40 BULL. The bootcamp conversion data is too strong to ignore. Entry below $130 on dips. Stop at $115 (below Bollinger support). Target $200+ within 24 months. Position: core holding, right-sized for the multiple.",
        recentHeadlines: [
            ["Jun 4", "Palantir AIP deployed across 4 new combatant commands via Maven Smart System", "https://www.defense.gov"],
            ["May 20", "Q1 2025 Earnings: Revenue $825M (+36% YoY), raised full-year guidance", "https://www.sec.gov"],
            ["May 15", "Palantir secures $480M Army TITAN contract expansion for AI battlefield management", "https://www.defense.gov"],
            ["Apr 28", "Commercial customer count up 69% YoY — AIP bootcamp conversion driving acceleration", "https://www.sec.gov"],
        ],
        sources: [
            ["Palantir Q1 2025 10-Q Filing", "https://www.sec.gov"],
            ["DoD Maven Smart System Program", "https://www.defense.gov"],
            ["Army TITAN Contract Award", "https://sam.gov"],
            ["Palantir AIP Product Page", "https://www.palantir.com"],
        ],
        upcomingEvents: [
            ["Jul 15", "Q2 2026 Earnings — est. revenue $950M", "earnings"],
            ["Aug 10", "DoD Maven Smart System Phase 2 award decision", "catalyst"],
            ["Sep 22", "AIPCon 2026 — major product announcements expected", "catalyst"],
            ["Oct 2026", "SpaceX IPO — space/defense sector re-rating catalyst for peers", "sector"],
        ],
        tags: ["AI/ML", "Defense", "Government", "Software"],
        priceHistory: [108,112,115,118,114,120,125,128,122,130,135,132,140,145,142,138,143,148,152,147,140,136,142,139,145,150,148,144,149,153,155,150,146,152,158,160,155,148,151,157,162,159,153,156,160,163,158,151,147,143,148,152,155,149,142,138,141,145,148,143,139,135,140,144,141,137,142,147,150,145,140,136,133,130,135,140,137],
        rsiValue: 46.5, rsiSignal: "neutral", macdTrend: "bullish", volumeVsAvg: 0.33,
        supportLevel: 123.71, resistanceLevel: 155.67,
        institutionalOwnershipPct: 48.2, institutionalFlow: "accumulation", topHolder: "Vanguard Group",
        analystConsensus: "Bullish", analystCount: 27, avgPriceTarget: 165.00,
        analystHighTarget: 225.00, analystLowTarget: 85.00,
        recentAnalystActions: [
            ["Citi", "Jun 3", "Upgrade", "Raised to Buy, PT $175 — AIP conversion rates exceeding expectations"],
            ["Morgan Stanley", "May 21", "PT Raise", "PT $190 (from $160) — government backlog accelerating"],
            ["Wedbush", "May 6", "Reiterate Buy", "PT $225 — 'The Microsoft of AI defense'"],
        ],
        detectionLane: "Government & Regulatory Support", researchedAt: "2026-06-05T12:00:00Z",
        overlookedAnalysis: "27 analysts cover PLTR — this is not an underfollowed name. However, the market may be underestimating the AIP bootcamp conversion rate and the operating leverage inherent in the business model. Consensus estimates lag actual revenue acceleration by 2-3 quarters.",
        indirectCatalysts: "SpaceX IPO would re-rate the entire defense/space tech sector. PLTR's Maven Smart System and TITAN contracts benefit from the same DoD modernization budgets. Any SpaceX IPO premium flowing into defense tech would lift PLTR as the sector's flagship AI platform.",
        insiderActivity: "CEO Alex Karp sold shares under a pre-established 10b5-1 plan — this is not a negative signal but removes the insider conviction boost. No cluster buying detected in last 90 days. Insider ownership at 4% indicates aligned but not concentrated.",
        governmentSupport: "$480M Army TITAN contract expansion. Maven Smart System deployed across 4 new combatant commands. DoD AI/ML budget growing at 22% CAGR. Palantir is embedded in intelligence community workflows — switching costs are effectively infinite. NDAA language continues to prioritize AI-enabled battlefield management.",
        bullCaseItems: ["AIP bootcamp-to-contract conversion compressing sales cycles", "Government backlog expanding with Maven + TITAN", "$4B+ cash with GAAP profitability and 84% gross margins", "Operating leverage just beginning as commercial revenue scales"],
        bearCaseItems: ["63x trailing revenue leaves zero room for growth deceleration", "Government contracts face continuing-resolution and shutdown risk", "Karp 10b5-1 selling plan removes insider conviction signal", "AI platform competition intensifying from Microsoft, Databricks, Snowflake"],
        businessModelSummary: "Palantir sells AI data integration platforms to government and commercial customers. Revenue mix: ~55% government, ~45% commercial. AIP (Artificial Intelligence Platform) is the growth driver — bootcamp-led sales cycle. High switching costs once embedded in intelligence/defense workflows. Revenue growth 36% YoY with 84% gross margins and GAAP profitability.",
        macroContext: "DoD modernization budgets growing at 22% CAGR driven by AI/ML adoption. NDAA continues to prioritize software-defined warfare. Commercial AI spending is secular, not cyclical. Rate sensitivity is minimal given $4B+ net cash position.",
        radarDossier: "# AEGIS Radar Dossier: $PLTR\n\n**Radar Score**: 88 | **Tier**: 1\n**Detection Lane**: Government & Regulatory Support\n**Researched**: 2026-06-05T12:00:00Z\n\n## Government & Regulatory Support\n\n$480M Army TITAN contract expansion. Maven Smart System deployed across combatant commands. DoD AI/ML budget at 22% CAGR. PLTR embedded in intelligence community with infinite switching costs. NDAA language prioritizes AI-enabled battlefield management.\n\n## Financial Health\n\nRevenue $3.2B (+36% YoY), Gross Margin 84%, GAAP profitable, $4B+ cash, zero debt. Operating leverage expanding as commercial scales.\n\n## Verdict\n\n65/35 BULL. Core holding. Entry below $130. Stop at $115 (Bollinger support). Target $200+.",
        asymmetryScore: 8, convictionScore: 7, catalystScore: 8, managementScore: 7,
        smartMoneyScore: 5, governmentScore: 9
    )

    static let mockMSTR = makeMock(
        id: "mstr", tier: 1, ticker: "MSTR", name: "Strategy",
        sector: "BTC Treasury · Software", score: 85, tripleSignal: true,
        bluf: "500K+ Bitcoin on balance sheet. Convertible note strategy creates a BTC acquisition flywheel at near-zero cost of capital. Premium to NAV is the debate — but the premium has persisted for years. Founder Saylor owns 10%+.",
        price: 117.26, upside: 145, marketCap: "41.3B", probability: 72,
        catalyst: "BTC price appreciation + convertible note issuance below market rates",
        council: AICouncil(gemini: .bull, deepseek: .bear, cio: .bull),
        buyZones: BuyZones(aggressive: 125.00, base: 110.00, conservative: 95.00),
        bullCase: "Strategy has accumulated over 500K Bitcoin using convertible debt at near-zero coupon rates — a capital markets arbitrage no other company has replicated at scale. Each new convertible note issuance increases BTC per share. Founder Michael Saylor owns 10%+ and has aligned the entire corporate structure around BTC acquisition. The premium to NAV is a feature, not a bug — it reflects the market pricing MSTR as a levered Bitcoin ETF with negative cost of leverage. Software business generates steady cash flow that covers interest expense.",
        bearCase: "The premium to NAV can evaporate as fast as it appeared. If Bitcoin enters a multi-year bear market, the convertible debt becomes a liability, not an asset — forced selling to cover interest could create a death spiral. The software business is in structural decline. Corporate governance is concentrated in Saylor's voting control. This is a levered bet on Bitcoin — if you want 1.5x BTC exposure, buy IBIT options instead of paying a 2x NAV premium.",
        financials: [
            ["BTC Holdings", "500K+"],
            ["BTC Cost Basis", "~$36K"],
            ["Total Debt", "$7.2B"],
            ["Software Revenue", "$465M"],
            ["Software Gross Margin", "78%"],
            ["Interest Expense", "$190M/yr"],
            ["BTC per Share", "~0.022"],
        ],
        redFlags: [
            "Premium to NAV is sentiment-driven, not structural",
            "Convertible debt = forced BTC liquidation risk in a bear market",
            "Software business is declining — pure BTC play",
        ],
        invalidation: "Bitcoin drops below $55K for 90+ days, triggering convertible note markdowns and forced deleveraging.",
        notificationLine: "🔔 RSI 28 oversold — worst selloff since 2024. Convertible note issuance continues below 1% coupon. BTC per share accretion accelerating.",
        priceChangePct: -9.36,
        taSummary: "RSI 28 oversold · MACD bearish · 1.1x avg vol",
        aiSynopsis: "Strategy getting crushed today — down 9% as Bitcoin and the broader market sell off. RSI at 28 signals deeply oversold. Convertible note strategy continues: BTC per share keeps accreting regardless of short-term price action. [Read the latest 8-K →](https://www.sec.gov)",
        geminiReasoning: "Michael Saylor has engineered the most successful corporate Bitcoin strategy in the world. 500K+ BTC accumulated via convertible notes at near-zero coupons — a capital markets arbitrage no other company has replicated at scale. The premium to NAV persists because the market correctly prices the acquisition flywheel. FASB fair-value accounting now reflects BTC holdings at market, boosting reported book value. At RSI 28, this is the most oversold MSTR has been since the 2024 cycle lows.",
        deepseekReasoning: "The premium to NAV is the entire bear case — and at these levels it's actually reasonable (~1.3x vs 2x+ historically). But the risk remains: in a prolonged BTC bear market, $7.2B in convertible debt becomes a forced-selling liability. The software business is in structural decline. Saylor's voting control means no governance check. This is a levered bet on Bitcoin — deep oversold conditions can persist for weeks in a risk-off environment.",
        cioReasoning: "DeepSeek is correct that the premium is sentiment-driven — but at RSI 28 with a 9% single-day drop, the panic is likely overdone. Gemini is correct that the convertible note arbitrage is real and BTC per share keeps rising. Verdict: 60/40 BULL — oversold entry opportunity. The MSTR playbook is buy panic, not euphoria. Entry here at $115-120. Stop: if premium to NAV breaks below 0.9x. Target: $200+ in BTC recovery cycle. Position: 5-10% portfolio max.",
        recentHeadlines: [
            ["Jun 2", "Strategy issues $2B convertible notes at 0.625% coupon to acquire additional Bitcoin", "https://www.sec.gov"],
            ["May 15", "Q1 2025: Strategy now holds 500K+ Bitcoin at average cost of ~$36K", "https://www.sec.gov"],
            ["Apr 10", "Saylor: 'We will keep buying the top forever' — institutional BTC adoption accelerating", "https://www.cnbc.com"],
            ["Mar 28", "FASB fair-value accounting rule change boosts MSTR reported book value by $12B+", "https://www.fasb.org"],
        ],
        sources: [
            ["Strategy Q1 2025 8-K — BTC Holdings", "https://www.sec.gov"],
            ["Strategy Convertible Note Prospectus", "https://www.sec.gov"],
            ["FASB ASU 2023-08 — Fair Value Accounting for Crypto", "https://www.fasb.org"],
            ["Michael Saylor Corporate Presentation", "https://www.strategy.com"],
        ],
        upcomingEvents: [
            ["Jul 22", "Q2 2026 Earnings — BTC holdings update", "earnings"],
            ["Jun 15", "FASB fair-value accounting rule effective — boosts book value $12B+", "catalyst"],
            ["Ongoing", "Next convertible note issuance window — BTC acquisition tranche", "catalyst"],
        ],
        tags: ["Bitcoin", "Crypto", "Treasury", "Financials"],
        priceHistory: [210,198,185,195,205,215,200,190,180,175,185,195,208,215,225,210,200,190,178,168,175,185,200,215,225,235,220,210,195,185,170,160,150,140,155,165,175,185,195,210,200,190,180,170,160,150,145,155,165,175,185,195,205,200,188,178,165,155,145,135,125,118,122,130,128,125,118,115,117],
        rsiValue: 28.5, rsiSignal: "oversold", macdTrend: "bearish", volumeVsAvg: 1.09,
        supportLevel: 117.81, resistanceLevel: 203.80,
        institutionalOwnershipPct: 38.5, institutionalFlow: "accumulation", topHolder: "Capital International",
        analystConsensus: "Bullish", analystCount: 13, avgPriceTarget: 210.00,
        analystHighTarget: 350.00, analystLowTarget: 120.00,
        recentAnalystActions: [
            ["Bernstein", "May 28", "Outperform", "PT $280 — FASB rule change unlocks institutional demand"],
            ["Canaccord", "May 15", "Buy", "PT $350 — BTC per share accretion is underappreciated"],
            ["JP Morgan", "Apr 30", "Neutral", "PT $180 — premium to NAV is justified but watch leverage"],
        ],
        detectionLane: "Insider Activity & Smart Money", researchedAt: "2026-06-05T12:05:00Z",
        overlookedAnalysis: "13 analysts cover MSTR but most frame it as a software company — the market structure around its convertible note arbitrage is poorly understood. FASB fair-value accounting rule change effective Jun 15 will boost reported book value $12B+ and may trigger institutional re-evaluation.",
        indirectCatalysts: "Bitcoin spot ETF inflows drive BTC price, which directly impacts MSTR's NAV. FASB accounting rule change (effective Jun 15) forces fair-value reporting of BTC holdings, potentially attracting value-oriented institutional investors who previously dismissed the stock. Saylor's BTC advocacy creates a reflexive feedback loop.",
        insiderActivity: "Michael Saylor owns 10%+ and has publicly stated he will never sell. Recent Form 4 filings show no insider sales outside of 10b5-1 plans. No cluster buying detected — Saylor's position is already concentrated. The insider signal here is alignment, not accumulation.",
        governmentSupport: "Limited direct government support. FASB accounting rule change is the closest regulatory catalyst. No DoD/DOE/NASA contracts. BTC strategic reserve discussions are speculative and not priced in.",
        bullCaseItems: ["500K+ BTC accumulated at ~$36K cost basis", "Convertible note strategy creates BTC per share accretion at near-zero cost", "FASB fair-value accounting rule change boosts book value $12B+", "Reflexive BTC price relationship amplifies upside in bull cycles"],
        bearCaseItems: ["Premium to NAV is sentiment-driven and can evaporate", "$7.2B convertible debt stack creates forced-selling risk in BTC bear", "Software business in structural decline", "Saylor voting control = no governance check"],
        businessModelSummary: "Strategy (formerly MicroStrategy) is a Bitcoin treasury company with a legacy enterprise software business. Revenue: software $465M (declining), BTC holdings 500K+ coins worth ~$35B. Convertible note arbitrage: issue debt at <1% coupon → buy Bitcoin → BTC per share accretes. The premium to NAV reflects the market pricing this as a levered BTC ETF with negative cost of leverage.",
        macroContext: "BTC price is the dominant macro driver. Rate cuts would weaken USD and boost BTC. Regulatory clarity improving under current administration. FASB accounting rule change is a structural catalyst. Enterprise software spending environment is steady but not growing.",
        radarDossier: "# AEGIS Radar Dossier: $MSTR\n\n**Radar Score**: 85 | **Tier**: 1\n**Detection Lane**: Insider Activity & Smart Money\n**Researched**: 2026-06-05T12:05:00Z\n\n## Insider Activity & Smart Money\n\nMichael Saylor owns 10%+ with publicly stated never-sell conviction. No insider sales outside 10b5-1 plans. FASB rule change triggers institutional re-evaluation. Convertible note arbitrage: BTC per share keeps accreting.\n\n## Financial Health\n\n500K+ BTC at ~$36K cost basis. $7.2B convertible debt with sub-1% coupons. Software generates $465M revenue at 78% gross margin, covering interest expense.\n\n## Verdict\n\n55/45 BULL. Satellite position (5-10% max). Entry at $115-120 on BTC pullback. Stop if premium to NAV breaks below 0.9x. Target $200+ in BTC recovery.",
        asymmetryScore: 7, convictionScore: 7, catalystScore: 8, managementScore: 8,
        smartMoneyScore: 9, governmentScore: 2
    )

    static let mockRKLB = makeMock(
        id: "rklb", tier: 2, ticker: "RKLB", name: "Rocket Lab",
        sector: "Space · Launch & Systems", score: 82, tripleSignal: false,
        bluf: "Neutron rocket on track for 2026 debut. 60+ Electron launches with best cadence outside SpaceX. $1B+ backlog. Space systems revenue now rivals launch — they're not just a rocket company.",
        price: 112.92, upside: 102, marketCap: "70.5B", probability: 68,
        catalyst: "Neutron first flight + space systems margin expansion",
        council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
        buyZones: BuyZones(aggressive: 120.00, base: 105.00, conservative: 90.00),
        bullCase: "Rocket Lab is the only credible competitor to SpaceX in the small-to-medium launch market. Electron is the most-flown small rocket in history. Neutron opens the medium-lift market and makes them a prime contractor for NSSL Phase 3 and DoD payloads. Space systems (satellite components, solar panels, software) now generates nearly half of revenue — they have a vertically integrated space company, not just a launch provider. Founder Peter Beck is an engineer-CEO with skin in the game. Backlog exceeds $1B.",
        bearCase: "Neutron development risk is real — first flights of new rockets have a high failure rate. SpaceX Starship could make medium-lift rockets obsolete. Launch is a low-margin, capital-intensive business. Competition from Firefly, Relativity, and Blue Origin is intensifying. Space systems margins are improving but still below 30%. At 12x forward revenue, the valuation assumes Neutron succeeds — if it slips, the multiple compresses.",
        financials: [
            ["Revenue (TTM)", "$480M"],
            ["Revenue Growth", "52%"],
            ["Gross Margin", "28%"],
            ["Backlog", "$1.1B"],
            ["Cash", "$510M"],
            ["Net Debt", "$0"],
            ["Launches (TTM)", "18"],
        ],
        redFlags: [
            "Neutron first-flight risk — new rockets fail at high rates",
            "SpaceX Starship could disrupt medium-lift economics",
            "Low-margin launch business limits FCF generation",
        ],
        invalidation: "Neutron first flight fails catastrophically or slips past Q2 2027.",
        notificationLine: "⚡ Neutron first flight window approaching. Space systems revenue now 45% of total.",
        priceChangePct: -5.86,
        taSummary: "RSI 48 neutral · MACD bearish · 0.3x avg vol",
        aiSynopsis: "Rocket Lab pulling back with the broader market selloff. Electron launches at record cadence while Neutron development progresses. Space systems revenue is the underappreciated story — satellite components now rival launch. [Read the Neutron program update →](https://www.rocketlabusa.com)",
        geminiReasoning: "Rocket Lab is the only company with a proven orbital rocket (Electron), a medium-lift rocket in development (Neutron), and a space systems business that generates nearly half of revenue. Peter Beck is an operator-founder who has executed 60+ launches. $1B+ backlog is real, contracted revenue. Space systems provides diversification pure-play launch companies lack. If Neutron succeeds, Rocket Lab becomes a mini-SpaceX. The stock is a call option on Neutron with a cash-flowing business as the floor.",
        deepseekReasoning: "Neutron is everything. If it fails or is delayed past 2027, the bull case unravels. Launch is a brutal business — low margins, high capex, binary outcomes. SpaceX has a 20-year head start and Starship could make medium-lift rockets economically obsolete. At 103x trailing revenue, the valuation already prices in Neutron success. Competition from Firefly, Relativity, Blue Origin, and Stoke Space is intensifying. The multiple requires a home run.",
        cioReasoning: "The key insight: Rocket Lab has already derisked execution with 60+ successful Electron launches. Neutron is binary but from a team that has launched to orbit 18 times in 12 months. Today's selloff is macro-driven, not thesis-breaking. Verdict: 60/40 BULL. Entry at $105-115 on this pullback, stop at $90. Target $170+ on successful Neutron first flight.",
        recentHeadlines: [
            ["May 30", "Rocket Lab completes Neutron stage 2 hot-fire test — first flight on track for H1 2026", "https://www.rocketlabusa.com"],
            ["May 22", "Electron launches 5 satellites for NASA — 18th launch in 12 months", "https://www.nasa.gov"],
            ["May 10", "Space systems awarded $150M satellite component contract for SDA Tranche 2", "https://www.defense.gov"],
        ],
        sources: [
            ["Rocket Lab Neutron Program Updates", "https://www.rocketlabusa.com"],
            ["Rocket Lab Q1 2025 Earnings", "https://www.sec.gov"],
            ["SDA Tranche 2 Contract Award", "https://www.defense.gov"],
            ["NASA VADR Launch Services Contract", "https://www.nasa.gov"],
        ],
        upcomingEvents: [
            ["Aug 5", "Q2 2026 Earnings — Neutron update expected", "earnings"],
            ["Sep 2026", "Neutron first flight window opens", "catalyst"],
            ["Jul 10", "Electron launch: NASA VADR mission", "catalyst"],
            ["Oct 2026", "SpaceX IPO — space sector re-rating catalyst", "sector"],
        ],
        tags: ["Space", "Defense", "Aerospace", "Hardware"],
        priceHistory: [95,98,105,102,108,115,112,120,118,125,130,128,122,118,115,110,108,112,118,122,128,132,130,126,122,118,115,110,105,108,112,116,118,122,120,116,112,108,104,100,98,102,106,110,108,105,102,103,105,108,112,111,109,105,102,100,98,100,104,107,111,113],
        rsiValue: 48.0, rsiSignal: "neutral", macdTrend: "bearish", volumeVsAvg: 0.32,
        supportLevel: 103.51, resistanceLevel: 151.89,
        institutionalOwnershipPct: 35.7, institutionalFlow: "accumulation", topHolder: "Deer Management",
        analystConsensus: "Bullish", analystCount: 16, avgPriceTarget: 150.00,
        analystHighTarget: 200.00, analystLowTarget: 85.00,
        recentAnalystActions: [
            ["KeyBanc", "May 30", "Overweight", "PT $170 — Neutron on track, space systems diversifying revenue"],
            ["RBC", "May 22", "Outperform", "PT $155 — launch cadence exceeding expectations"],
            ["Goldman", "May 10", "Buy", "PT $200 — SpaceX IPO will re-rate entire sector"],
        ],
        detectionLane: "Indirect Beneficiary", researchedAt: "2026-06-05T12:10:00Z",
        overlookedAnalysis: "16 analysts cover RKLB — well-followed for a space company. However, most models treat it as a launch provider and undervalue the space systems segment (now 45% of revenue). The market prices RKLB as a binary Neutron bet, missing the diversified revenue base that provides a floor.",
        indirectCatalysts: "SpaceX Starlink IPO rumored for Q4 2026 — would be the most anticipated space sector debut ever. RKLB is the only credible medium-lift competitor and would benefit from sector re-rating. NSSL Phase 3 contract awards would establish RKLB as a national security launch provider alongside SpaceX and ULA. Increased defense spending on space-based ISR directly benefits launch cadence.",
        insiderActivity: "Founder/CEO Peter Beck owns significant equity but has sold small amounts under 10b5-1 plan for diversification. No cluster buying detected. Insider ownership is aligned but not accumulating. Management quality is high — Beck is an engineer-operator who has executed 60+ launches.",
        governmentSupport: "$150M SDA Tranche 2 satellite component contract. NASA VADR launch services contract. DoD space-based ISR budget growing. NSSL Phase 3 eligibility would be the largest government catalyst. Space Force increasingly views RKLB as a strategic launch alternative to SpaceX.",
        bullCaseItems: ["Only credible SpaceX competitor with 60+ proven Electron launches", "Neutron opens medium-lift market and NSSL Phase 3 eligibility", "Space systems revenue (45% of total) provides diversified floor", "SpaceX IPO would re-rate entire space sector"],
        bearCaseItems: ["Neutron first-flight risk — new rockets fail at high rates", "SpaceX Starship could make medium-lift rockets obsolete", "103x trailing revenue requires flawless execution", "Launch margins remain low; FCF generation is years away"],
        businessModelSummary: "Rocket Lab is a vertically integrated space company. Launch segment: Electron (small-lift, 60+ missions) and Neutron (medium-lift, in development). Space Systems: satellite components, solar panels, flight software — now 45% of revenue. Backlog $1B+. Founder-led by engineer-CEO Peter Beck. Revenue growth 63% YoY.",
        macroContext: "Space defense budgets growing with Space Force prioritization. Commercial satellite constellation demand accelerating. SpaceX IPO would bring massive attention and capital to the sector. Rate sensitivity: moderate — growth companies benefit from lower rates but government/defense contracts provide stability.",
        radarDossier: "# AEGIS Radar Dossier: $RKLB\n\n**Radar Score**: 82 | **Tier**: 2\n**Detection Lane**: Indirect Beneficiary\n**Researched**: 2026-06-05T12:10:00Z\n\n## Indirect Beneficiary Analysis\n\nSpaceX Starlink IPO rumored Q4 2026 — RKLB is the only credible medium-lift competitor and would see sector re-rating. NSSL Phase 3 awards would cement RKLB as national security launch provider. Space systems revenue now 45% of total — they're not just a rocket company.\n\n## Financial Health\n\nRevenue $480M (+63% YoY). Backlog $1.1B. Cash $510M, zero debt. Gross margin 28% improving with space systems mix shift.\n\n## Verdict\n\n60/40 BULL. Entry at $105-115 on pullback. Stop at $90. Target $170+ on Neutron first flight.",
        asymmetryScore: 7, convictionScore: 6, catalystScore: 8, managementScore: 8,
        smartMoneyScore: 6, governmentScore: 7
    )

    static let mockASTS = makeMock(
        id: "asts", tier: 2, ticker: "ASTS", name: "AST SpaceMobile",
        sector: "Space · Telecom", score: 76, tripleSignal: false,
        bluf: "First 5 commercial satellites in orbit. AT&T and Verizon as partners for direct-to-phone broadband from space. Pre-revenue. Regulatory approval and constellation scale-up are the binary catalysts.",
        price: 96.24, upside: 175, marketCap: "37.4B", probability: 55,
        catalyst: "Commercial service launch + AT&T/Verizon subscriber rollout",
        council: AICouncil(gemini: .bull, deepseek: .bear, cio: .bull),
        buyZones: BuyZones(aggressive: 105.00, base: 90.00, conservative: 70.00),
        bullCase: "AST SpaceMobile has solved one of the hardest engineering problems in telecom — direct-to-phone broadband from low-earth orbit. No ground terminal, no special phone required. AT&T and Verizon are not just partners, they are investors and have committed to commercial service. The TAM is every phone on Earth that's outside cell coverage. First 5 satellites are in orbit and functioning. If the constellation scales to 90+ satellites, this is a $50B+ company. Spectrum rights and orbital slots create a regulatory moat.",
        bearCase: "Pre-revenue with enormous capex needs. Each satellite costs ~$25M — a full constellation requires $2B+ in additional funding. Dilution risk is high. 5 satellites prove the tech works but don't prove the business model. Starlink Direct-to-Cell has deeper pockets and a larger existing constellation. Regulatory approvals across dozens of countries are uncertain. At $6.8B market cap with zero revenue, this is a binary option — either 10x or zero.",
        financials: [
            ["Revenue (TTM)", "$0"],
            ["Cash", "$520M"],
            ["Cash Burn (Q)", "$65M"],
            ["Satellites in Orbit", "5"],
            ["Full Constellation", "90+"],
            ["Partners", "AT&T, Verizon, Vodafone"],
            ["Est. Capex Need", "$2.2B"],
        ],
        redFlags: [
            "Pre-revenue — $0 in sales today",
            "$2B+ additional funding needed = massive dilution risk",
            "SpaceX Starlink Direct-to-Cell is a well-funded competitor",
        ],
        invalidation: "Commercial service launch delayed past Q4 2026, or funding gap emerges before constellation reaches 25 satellites.",
        notificationLine: "⚡ AT&T + Verizon commercial launch window: H2 2026. 5 satellites operational. Full constellation = 90+.",
        priceChangePct: -10.30,
        taSummary: "RSI 49 neutral · MACD bearish · 0.4x avg vol",
        aiSynopsis: "AST SpaceMobile getting hammered in today's selloff — down 10%. First 5 satellites are functional. AT&T and Verizon partnerships provide credibility but the capex requirement is enormous and dilution risk is real in this tape. [Read the latest satellite update →](https://www.ast-science.com)",
        geminiReasoning: "Direct-to-phone broadband from space is a 'holy grail' technology that ASTS has actually demonstrated with working satellites. The AT&T and Verizon partnerships are unprecedented — no other company has two tier-1 carriers as strategic investors and commercial partners. The regulatory moat from spectrum rights is real and hard to replicate. If the business works, the addressable market is billions of phones. The risk/reward at $6.8B market cap is asymmetric — success implies $50B+, failure implies near-zero. That's exactly the kind of asymmetry we look for.",
        deepseekReasoning: "Zero revenue. $2B+ in future funding needs. 5 satellites in orbit out of 90+ required. This is not a company — it's a science project with a ticker. Starlink Direct-to-Cell is backed by SpaceX's launch cost advantage and existing 5,000+ satellite constellation. ASTS has to raise money at market prices to build each satellite, while SpaceX launches its own at cost. The funding gap is the thesis-killer — every equity raise dilutes existing shareholders. AT&T and Verizon partnerships are non-exclusive and can be cancelled.",
        cioReasoning: "This is the most asymmetric setup in the radar. DeepSeek is correct about the funding risk and SpaceX competition. Gemini is correct about the technology moat and partner quality. Verdict: 50/50 — true uncertainty. Position: call options or a 2-3% portfolio allocation. This is not a core holding — it's a lottery ticket with a thesis. Entry at $18-22. No stop — this trades on binary events, not technicals. If commercial service launches on schedule, this re-rates 5-10x. If it slips past 2027, write it to zero.",
        recentHeadlines: [
            ["May 25", "AST SpaceMobile confirms all 5 Block 1 satellites operational — direct-to-phone data speeds achieved", "https://www.ast-science.com"],
            ["May 12", "AT&T exec: 'AST SpaceMobile will be integrated into consumer plans in 2026'", "https://www.cnbc.com"],
            ["Apr 30", "Q1 2025 10-Q: Cash $520M — management guides 12-month runway before next capital raise", "https://www.sec.gov"],
        ],
        sources: [
            ["AST SpaceMobile Q1 2025 10-Q", "https://www.sec.gov"],
            ["AST SpaceMobile Technology Overview", "https://www.ast-science.com"],
            ["FCC Experimental License Filings", "https://www.fcc.gov"],
            ["AT&T + AST Partnership Announcement", "https://about.att.com"],
        ],
        upcomingEvents: [
            ["Aug 12", "Q2 2026 Earnings — commercial launch timeline update", "earnings"],
            ["H2 2026", "Commercial direct-to-phone service launch — AT&T + Verizon", "catalyst"],
            ["Oct 2026", "FCC global regulatory approval milestone", "catalyst"],
            ["Oct 2026", "SpaceX IPO — space sector re-rating benefits satellite plays", "sector"],
        ],
        tags: ["Space", "Telecom", "Hardware", "Pre-Revenue"],
        priceHistory: [68,72,78,82,85,90,95,88,92,98,105,102,108,112,115,110,105,108,115,120,118,112,108,102,98,95,100,105,108,112,115,118,120,115,110,105,100,96,92,88,85,90,94,98,96,92,88,84,86,90,94,98,96,92,88,85,89,93,97,96],
        rsiValue: 49.2, rsiSignal: "neutral", macdTrend: "bearish", volumeVsAvg: 0.41,
        supportLevel: 62.05, resistanceLevel: 134.90,
        institutionalOwnershipPct: 22.3, institutionalFlow: "flat", topHolder: "Jane Street",
        analystConsensus: "Bullish", analystCount: 9, avgPriceTarget: 160.00,
        analystHighTarget: 300.00, analystLowTarget: 45.00,
        recentAnalystActions: [
            ["Scotiabank", "May 25", "Sector Outperform", "PT $180 — 5 satellites operational, tech validated"],
            ["B. Riley", "May 12", "Buy", "PT $300 — AT&T integration is the catalyst no one is pricing"],
            ["Deutsche Bank", "Apr 30", "Hold", "PT $95 — funding gap remains the primary risk"],
        ],
        detectionLane: "Overlooked / Underfollowed", researchedAt: "2026-06-05T12:15:00Z",
        overlookedAnalysis: "9 analysts cover ASTS. Institutional ownership at just 22.3% with Jane Street as top holder (likely market-making, not fundamental). No ETF inclusion. The technology — direct-to-phone broadband from space — is so ambitious that many analysts dismiss it as science fiction. The 5 functional satellites in orbit prove the tech works but the market hasn't fully priced the AT&T + Verizon commercial commitment.",
        indirectCatalysts: "SpaceX IPO would benefit ASTS as a space sector peer. FCC regulatory framework for direct-to-device satellite service is being developed — approval would open the floodgates for commercial deployment. AT&T and Verizon are not just partners but investors — their commercial integration signals conviction in the technology.",
        insiderActivity: "No recent insider cluster buying detected. Management holds equity but no open-market purchases in last 90 days. This is expected for a pre-revenue company where management is compensated in equity. Insider conviction would be a strong positive signal if it appears.",
        governmentSupport: "FCC experimental license for satellite testing granted. FCC regulatory framework for direct-to-device service under active development. No DoD contracts yet, but national security applications for direct-to-phone satellite connectivity are clear. Rural broadband initiatives could provide additional government tailwinds.",
        bullCaseItems: ["Direct-to-phone broadband from space proven with 5 working satellites", "AT&T and Verizon as strategic partners and investors — unprecedented telecom backing", "TAM is every phone outside cell coverage — billions of devices", "FCC regulatory framework under development would unlock commercial deployment"],
        bearCaseItems: ["Zero revenue — $0 in sales today", "$2B+ additional funding needed for full 90-satellite constellation", "SpaceX Starlink Direct-to-Cell has launch cost advantage and larger constellation", "At $37B market cap with no revenue, this is a binary option"],
        businessModelSummary: "AST SpaceMobile is building a direct-to-phone satellite broadband constellation. 5 Block 1 satellites operational — technology proven. Partnerships: AT&T, Verizon, Vodafone as strategic investors and commercial partners. Pre-revenue. Requires 90+ satellites for global coverage at ~$25M per satellite. The business model is wholesale bandwidth to carriers, not direct-to-consumer.",
        macroContext: "FCC regulatory framework for satellite direct-to-device is a binary catalyst. Telecom infrastructure spending is secular. Competition from Starlink Direct-to-Cell is the primary external threat. Rate environment matters — higher rates increase cost of capital for the $2B+ constellation buildout.",
        radarDossier: "# AEGIS Radar Dossier: $ASTS\n\n**Radar Score**: 76 | **Tier**: 2\n**Detection Lane**: Overlooked / Underfollowed\n**Researched**: 2026-06-05T12:15:00Z\n\n## Overlooked / Underfollowed Analysis\n\n9 analysts, 22% institutional ownership, no ETF inclusion. Market dismisses as science fiction but 5 working satellites prove the tech. AT&T and Verizon are strategic investors — not just partners. The TAM is every phone outside cell coverage.\n\n## Financial Health\n\nZero revenue. Cash $520M. Burn $65M/quarter. Need $2B+ for full constellation. Binary outcome: 10x or zero.\n\n## Verdict\n\n50/50 — true uncertainty. Call options or 2-3% max position. No stop-loss. Target 5-10x on commercial launch.",
        asymmetryScore: 9, convictionScore: 5, catalystScore: 7, managementScore: 6,
        smartMoneyScore: 3, governmentScore: 4
    )

    static let mockOKLO = makeMock(
        id: "oklo", tier: 2, ticker: "OKLO", name: "Oklo",
        sector: "Energy · Advanced Nuclear", score: 74, tripleSignal: false,
        bluf: "Advanced nuclear SMR with NRC application in progress. Data center offtake discussions signal commercial demand for 24/7 carbon-free power. Pre-revenue but regulatory milestone-driven catalyst path.",
        price: 59.92, upside: 150, marketCap: "10.4B", probability: 52,
        catalyst: "NRC design certification + first data center offtake agreement",
        council: AICouncil(gemini: .bull, deepseek: .bear, cio: .bull),
        buyZones: BuyZones(aggressive: 65.00, base: 55.00, conservative: 45.00),
        bullCase: "Oklo is building small modular reactors designed for commercial deployment at data centers, industrial sites, and remote communities. Unlike traditional nuclear plants that take 10+ years, SMRs are factory-built and deployable in 3-5 years. The data center power crisis is real — AI training requires 24/7 carbon-free electricity, and wind/solar can't provide baseload. Oklo's NRC application is one of only a handful of advanced reactor designs under active review. Sam Altman is chairman and a major investor.",
        bearCase: "The NRC has never approved an advanced non-light-water reactor design. The regulatory timeline is uncertain and could stretch years. Pre-revenue with no near-term path to positive cash flow — this is a regulatory option, not a business. Data center offtake discussions are non-binding MOUs, not contracts. Nuclear has a history of cost overruns and delays that kill projects. Competitors (NuScale, TerraPower, X-energy) are further along. At $3.5B market cap with zero revenue, this is priced for success that could be 5+ years away.",
        financials: [
            ["Revenue (TTM)", "$0"],
            ["Cash", "$280M"],
            ["Cash Burn (Q)", "$18M"],
            ["NRC Application", "Under Review"],
            ["First Reactor", "2028-2029"],
            ["Chairman", "Sam Altman"],
            ["Employees", "120+"],
        ],
        redFlags: [
            "NRC has never approved this reactor type — regulatory first-of-kind risk",
            "Pre-revenue; first reactor deployment 3-5 years out",
            "Nuclear cost-overrun history is brutal — SMR economics unproven",
        ],
        invalidation: "NRC issues a negative safety evaluation or design certification is delayed past 2028.",
        notificationLine: "⚡ NRC design certification milestone approaching. Data center power demand creating urgency for 24/7 carbon-free solutions.",
        priceChangePct: -8.37,
        taSummary: "RSI 43 neutral · MACD bearish · 0.5x avg vol",
        aiSynopsis: "Oklo caught in the risk-off sweep — down 8%. The NRC design certification remains the binary catalyst. With AI power demand exploding, the need for 24/7 baseload nuclear hasn't changed, but pre-revenue names get punished in selloffs. [Read the NRC docket →](https://www.nrc.gov)",
        geminiReasoning: "The AI data center buildout requires baseload power that renewables alone cannot provide. Nuclear SMRs are the only scalable, carbon-free baseload solution. Oklo has the cleanest regulatory pathway of any advanced reactor company, with an active NRC application and Sam Altman's network opening doors to hyperscaler offtake. The regulatory moat is the investment thesis — once a design is certified, competitors face a 3-5 year catch-up window.",
        deepseekReasoning: "The NRC has never approved an advanced reactor design. 'Under review' means years of uncertainty. Oklo has zero revenue and won't have any until the 2030s at the earliest. Data center 'discussions' are not contracts — hyperscalers are talking to every nuclear company simultaneously. This is a concept stock in a sector where concepts have historically destroyed capital. Sam Altman's involvement creates a halo effect, not a business. At $3.5B market cap, this is purely optionality value.",
        cioReasoning: "This is a regulatory catalyst play with a genuine secular tailwind. DeepSeek is correct about the regulatory risk and pre-revenue nature. Gemini is correct that the AI power demand problem is real and Oklo is well-positioned. Verdict: 45/55 — slight bull tilt on the thematic tailwind, but position size must reflect the binary risk. Entry at $24-28 on pullbacks. No stop — this trades on regulatory news, not price. Target: 3-5x on NRC design certification. Position size: 1-2% max.",
        recentHeadlines: [
            ["Jun 1", "Oklo submits additional NRC design certification documentation — docket update expected Q3 2026", "https://www.nrc.gov"],
            ["May 18", "Oklo signs MOU with major data center operator for 500MW SMR deployment", "https://www.oklo.com"],
            ["May 5", "Q1 2025 10-Q: Cash $280M — Sam Altman participates in $100M PIPE at $26", "https://www.sec.gov"],
        ],
        sources: [
            ["NRC — Oklo Advanced Reactor Docket", "https://www.nrc.gov"],
            ["Oklo Q1 2025 10-Q Filing", "https://www.sec.gov"],
            ["Oklo Aurora Reactor Technical Specifications", "https://www.oklo.com"],
            ["DOE Advanced Reactor Demonstration Program", "https://www.energy.gov"],
        ],
        upcomingEvents: [
            ["Aug 8", "Q2 2026 Earnings", "earnings"],
            ["Q3 2026", "NRC design certification docket update", "catalyst"],
            ["Dec 2026", "First data center offtake agreement target", "catalyst"],
        ],
        tags: ["Nuclear", "Energy", "SMR", "Pre-Revenue"],
        priceHistory: [42,45,48,50,52,55,58,60,62,59,55,52,50,48,52,55,58,60,63,65,62,60,58,55,52,50,48,45,48,50,55,58,60,62,65,63,60,58,55,52,50,48,52,55,58,61,59,56,54,52,55,57,60,59,56,54,52,55,58,60],
        rsiValue: 43.1, rsiSignal: "neutral", macdTrend: "bearish", volumeVsAvg: 0.53,
        supportLevel: 55.95, resistanceLevel: 77.43,
        institutionalOwnershipPct: 18.9, institutionalFlow: "distribution", topHolder: "Altman Family Trust",
        analystConsensus: "Bullish", analystCount: 19, avgPriceTarget: 65.00,
        analystHighTarget: 120.00, analystLowTarget: 28.00,
        recentAnalystActions: [
            ["BofA", "Jun 1", "Buy", "PT $75 — data center power crisis makes SMRs inevitable"],
            ["Wells Fargo", "May 18", "Overweight", "PT $65 — NRC application progress is on track"],
            ["Citigroup", "May 5", "Neutral", "PT $40 — regulatory timeline uncertain, patience required"],
        ],
        detectionLane: "Government & Regulatory Support", researchedAt: "2026-06-05T12:20:00Z",
        overlookedAnalysis: "19 analysts cover OKLO but most are energy specialists — the broader market doesn't understand advanced nuclear SMRs. Institutional ownership at just 18.9% reflects the pre-revenue regulatory risk. No ETF inclusion. The data center power crisis is creating demand for 24/7 baseload solutions that Oklo is uniquely positioned to address with NRC-certified SMRs.",
        indirectCatalysts: "AI data center buildout is the primary indirect catalyst — hyperscalers need 24/7 carbon-free baseload power that renewables cannot provide. Every new data center announcement increases the urgency for advanced nuclear deployment. CHIPS Act energy infrastructure provisions could accelerate SMR deployment timelines.",
        insiderActivity: "Sam Altman is chairman and a major investor — alignment is strong. Altman participated in $100M PIPE at $26, signaling conviction at higher prices. No open-market insider selling detected in last 90 days. The Altman halo effect is real but cuts both ways — his involvement brings attention but also expectations.",
        governmentSupport: "NRC design certification under active review — this is the single most important catalyst. DOE Advanced Reactor Demonstration Program provides funding and regulatory support. CHIPS Act includes energy infrastructure provisions that benefit advanced nuclear. The NRC has never approved this reactor type — regulatory first-of-kind risk is the primary uncertainty.",
        bullCaseItems: ["NRC design certification under active review — regulatory moat", "AI data center power crisis creating demand for 24/7 baseload nuclear", "Sam Altman backing provides capital access and hyperscaler connections", "SMR factory-built model enables faster, cheaper deployment than traditional nuclear"],
        bearCaseItems: ["NRC has never approved this reactor type — first-of-kind regulatory risk", "Pre-revenue with first deployment 3-5 years out", "Nuclear cost-overrun history is brutal", "Competition from NuScale, TerraPower, X-energy"],
        businessModelSummary: "Oklo is developing advanced small modular nuclear reactors for commercial deployment. Target customers: data centers, industrial sites, remote communities. Factory-built SMRs designed for 3-5 year deployment vs 10+ years for traditional nuclear. NRC design certification is the primary regulatory catalyst. Chairman Sam Altman provides strategic backing and capital access.",
        macroContext: "AI data center power demand is the dominant macro driver — hyperscalers need 24/7 carbon-free baseload. Nuclear renaissance sentiment is building globally. Regulatory environment is the binary risk — NRC approval timeline is uncertain. CHIPS Act and energy policy provide government tailwinds.",
        radarDossier: "# AEGIS Radar Dossier: $OKLO\n\n**Radar Score**: 74 | **Tier**: 2\n**Detection Lane**: Government & Regulatory Support\n**Researched**: 2026-06-05T12:20:00Z\n\n## Government & Regulatory Support\n\nNRC design certification under active review — the single most important catalyst. DOE Advanced Reactor Demonstration Program support. CHIPS Act energy provisions. NRC has never approved this reactor type — regulatory first-of-kind risk is real.\n\n## Financial Health\n\nZero revenue. Cash $280M. Burn $18M/quarter. Sam Altman PIPE at $26. First deployment target 2028-2029.\n\n## Verdict\n\n45/55 — slight bull tilt on data center power crisis tailwind. 1-2% max position. Entry $24-28. No stop. Target 3-5x on NRC certification.",
        asymmetryScore: 8, convictionScore: 5, catalystScore: 6, managementScore: 7,
        smartMoneyScore: 7, governmentScore: 8
    )

    static let mocks: [Opportunity] = [mockPLTR, mockMSTR, mockRKLB, mockASTS, mockOKLO]

    static let mock = mockPLTR

    // MARK: Factory

    private static func makeMock(
        id: String, tier: Int, ticker: String, name: String, sector: String,
        score: Double, tripleSignal: Bool, bluf: String,
        price: Double, upside: Double, marketCap: String, probability: Double,
        catalyst: String, council: AICouncil, buyZones: BuyZones,
        bullCase: String, bearCase: String, financials: [[String]],
        redFlags: [String], invalidation: String, notificationLine: String = "",
        priceChangePct: Double = 0, taSummary: String = "", aiSynopsis: String = "",
        geminiReasoning: String = "", deepseekReasoning: String = "", cioReasoning: String = "",
        recentHeadlines: [[String]] = [], sources: [[String]] = [], upcomingEvents: [[String]] = [], tags: [String] = [],
        priceHistory: [Double] = [],
        rsiValue: Double = 50, rsiSignal: String = "neutral", macdTrend: String = "neutral",
        volumeVsAvg: Double = 1.0, supportLevel: Double = 0, resistanceLevel: Double = 0,
        institutionalOwnershipPct: Double = 0, institutionalFlow: String = "flat", topHolder: String = "",
        analystConsensus: String = "", analystCount: Int = 0, avgPriceTarget: Double = 0,
        analystHighTarget: Double = 0, analystLowTarget: Double = 0, recentAnalystActions: [[String]] = [],
        detectionLane: String? = nil, researchedAt: String? = nil,
        overlookedAnalysis: String? = nil, indirectCatalysts: String? = nil,
        insiderActivity: String? = nil, governmentSupport: String? = nil,
        bullCaseItems: [String] = [], bearCaseItems: [String] = [],
        businessModelSummary: String? = nil, macroContext: String? = nil,
        radarDossier: String? = nil,
        asymmetryScore: Int = 0, convictionScore: Int = 0, catalystScore: Int = 0, managementScore: Int = 0,
        smartMoneyScore: Int? = nil, governmentScore: Int? = nil
    ) -> Opportunity {
        Opportunity(
            id: id, ticker: ticker, companyName: name, sector: sector,
            tier: tier, score: score, tripleSignal: tripleSignal, bluf: bluf,
            price: price, upside: upside, marketCap: marketCap, probability: probability,
            catalyst: catalyst, council: council, buyZones: buyZones,
            bullCase: bullCase, bearCase: bearCase, financials: financials,
            redFlags: redFlags, invalidation: invalidation, notificationLine: notificationLine,
            priceChangePct: priceChangePct, taSummary: taSummary, aiSynopsis: aiSynopsis,
            geminiReasoning: geminiReasoning, deepseekReasoning: deepseekReasoning, cioReasoning: cioReasoning,
            recentHeadlines: recentHeadlines, sources: sources, upcomingEvents: upcomingEvents, tags: tags,
            priceHistory: priceHistory,
            rsiValue: rsiValue, rsiSignal: rsiSignal, macdTrend: macdTrend,
            volumeVsAvg: volumeVsAvg, supportLevel: supportLevel, resistanceLevel: resistanceLevel,
            analystConsensus: analystConsensus, analystCount: analystCount, avgPriceTarget: avgPriceTarget,
            analystHighTarget: analystHighTarget, analystLowTarget: analystLowTarget, recentAnalystActions: recentAnalystActions,
            institutionalOwnershipPct: institutionalOwnershipPct, institutionalFlow: institutionalFlow, topHolder: topHolder,
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
            asymmetryScore: asymmetryScore, convictionScore: convictionScore, catalystScore: catalystScore, managementScore: managementScore,
            downsidePct: nil, smartMoneyScore: smartMoneyScore, marketCapScore: nil, fullReportMd: nil,
            radarDossier: radarDossier, researchedAt: researchedAt,
            bullCaseItems: bullCaseItems, bearCaseItems: bearCaseItems,
            businessModelSummary: businessModelSummary, macroContext: macroContext,
            insiderActivity: insiderActivity, governmentSupport: governmentSupport,
            indirectCatalysts: indirectCatalysts, overlookedAnalysis: overlookedAnalysis,
            detectionLane: detectionLane, governmentScore: governmentScore
        )
    }
}
