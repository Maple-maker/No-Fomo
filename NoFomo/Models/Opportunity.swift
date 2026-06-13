import Foundation

// MARK: - Core opportunity model (maps to radar_opportunities Supabase table)
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

    // ── Restored (additive) fields used by DetailSheet ──
    var councilSummary: String? = nil
    var competitiveAdvantages: String? = nil
    var investmentRisks: String? = nil
    var keyMetrics: KeyMetricsData? = nil
    var insiderTotalBuys: Int = 0
    var insiderTotalSells: Int = 0
    var insiderBuyVolume: Int = 0
    var insiderSellVolume: Int = 0
    var insiderBuyingNames: [String] = []
    var insiderSellingNames: [String] = []
    var insiderClusterScore: Int = 0
    var insiderNetSentiment: String = ""
    var insiderSignal: String = ""
    var insiderTransactions: [[String]] = []

    // ── Confidence scoring ──
    var confidenceScore: Int?
    var confidenceLabel: String?
    var dataFreshness: String?

    // ── Radar V2 signal engine ──
    var scoreBreakdown: ScoreBreakdown?
    var repriceGap: RepriceGap?
    var councilExplanation: CouncilExplanation?
    var regimeFlags: [String]

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
         detectionLane: String? = nil, governmentScore: Int? = nil,
         scoreBreakdown: ScoreBreakdown? = nil, repriceGap: RepriceGap? = nil,
         councilExplanation: CouncilExplanation? = nil, regimeFlags: [String] = [],
         keyMetrics: KeyMetricsData? = nil) {
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
        self.scoreBreakdown = scoreBreakdown; self.repriceGap = repriceGap
        self.councilExplanation = councilExplanation; self.regimeFlags = regimeFlags
        self.keyMetrics = keyMetrics
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

        let decodedScoreBreakdown = try c.decodeIfPresent(ScoreBreakdown.self, forKey: .scoreBreakdown)
        sector = try c.decodeIfPresent(String.self, forKey: .sector) ?? ""
        let fallbackScore = try c.decodeIfPresent(Double.self, forKey: .score) ?? c.decodeIfPresent(Double.self, forKey: .overallScore) ?? 0
        let fallbackTripleSignal = try c.decodeIfPresent(Bool.self, forKey: .tripleSignal) ?? c.decodeIfPresent(Bool.self, forKey: .isTripleSignal) ?? false
        score = decodedScoreBreakdown?.radarScore ?? fallbackScore
        tripleSignal = decodedScoreBreakdown?.confluence?.tripleSignal ?? fallbackTripleSignal
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
        // ── Restored (additive) fields ──
        councilSummary = try c.decodeIfPresent(String.self, forKey: .councilSummary)
        competitiveAdvantages = try c.decodeIfPresent(String.self, forKey: .competitiveAdvantages)
        investmentRisks = try c.decodeIfPresent(String.self, forKey: .investmentRisks)
        keyMetrics = try c.decodeIfPresent(KeyMetricsData.self, forKey: .keyMetrics)
        insiderTotalBuys = try c.decodeIfPresent(Int.self, forKey: .insiderTotalBuys) ?? 0
        insiderTotalSells = try c.decodeIfPresent(Int.self, forKey: .insiderTotalSells) ?? 0
        insiderBuyVolume = try c.decodeIfPresent(Int.self, forKey: .insiderBuyVolume) ?? 0
        insiderSellVolume = try c.decodeIfPresent(Int.self, forKey: .insiderSellVolume) ?? 0
        insiderBuyingNames = try c.decodeIfPresent([String].self, forKey: .insiderBuyingNames) ?? []
        insiderSellingNames = try c.decodeIfPresent([String].self, forKey: .insiderSellingNames) ?? []
        insiderClusterScore = try c.decodeIfPresent(Int.self, forKey: .insiderClusterScore) ?? 0
        insiderNetSentiment = try c.decodeIfPresent(String.self, forKey: .insiderNetSentiment) ?? ""
        insiderSignal = try c.decodeIfPresent(String.self, forKey: .insiderSignal) ?? ""
        insiderTransactions = try c.decodeIfPresent([[String]].self, forKey: .insiderTransactions) ?? []
        // ── Confidence scoring ──
        confidenceScore = try c.decodeIfPresent(Int.self, forKey: .confidenceScore)
        confidenceLabel = try c.decodeIfPresent(String.self, forKey: .confidenceLabel)
        dataFreshness = try c.decodeIfPresent(String.self, forKey: .dataFreshness)
        scoreBreakdown = decodedScoreBreakdown
        repriceGap = try c.decodeIfPresent(RepriceGap.self, forKey: .repriceGap)
        councilExplanation = try c.decodeIfPresent(CouncilExplanation.self, forKey: .councilExplanation)
        regimeFlags = try c.decodeIfPresent([String].self, forKey: .regimeFlags) ?? scoreBreakdown?.regimeFlags ?? []
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
        case councilSummary = "council_summary"
        case competitiveAdvantages = "competitive_advantages"
        case investmentRisks = "investment_risks"
        case keyMetrics = "key_metrics"
        case insiderTotalBuys = "insider_total_buys"
        case insiderTotalSells = "insider_total_sells"
        case insiderBuyVolume = "insider_buy_volume"
        case insiderSellVolume = "insider_sell_volume"
        case insiderBuyingNames = "insider_buying_names"
        case insiderSellingNames = "insider_selling_names"
        case insiderClusterScore = "insider_cluster_score"
        case insiderNetSentiment = "insider_net_sentiment"
        case insiderSignal = "insider_signal"
        case insiderTransactions = "insider_transactions"
        case confidenceScore = "confidence_score"
        case confidenceLabel = "confidence_label"
        case dataFreshness = "data_freshness"
        case scoreBreakdown = "score_breakdown"
        case repriceGap = "reprice_gap"
        case councilExplanation = "council_explanation"
        case regimeFlags = "regime_flags"
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

// MARK: - Key metrics (Qualtrim-style financial summary)

struct KeyMetricsData: Codable {
    let peTrailing: String?
    let peForward: String?
    let evEbitda: String?
    let grossMargin: String?
    let operatingMargin: String?
    let dividendYield: String?
    let beta: String?

    enum CodingKeys: String, CodingKey {
        case peTrailing = "pe_trailing"
        case peForward = "pe_forward"
        case evEbitda = "ev_ebitda"
        case grossMargin = "gross_margin"
        case operatingMargin = "operating_margin"
        case dividendYield = "dividend_yield"
        case beta
    }

    var hasAnyRatio: Bool {
        [peTrailing, peForward, evEbitda, grossMargin, operatingMargin, dividendYield, beta]
            .contains { ($0?.isEmpty == false) && $0 != "N/A" }
    }
}

struct ScoreBreakdown: Codable {
    let ticker: String
    let radarScore: Double
    let gatePass: Bool?
    let categoryScores: [String: Double]
    let confluence: Confluence?
    let crowding: Crowding?
    let signals: [SignalLedgerItem]
    let regimeFlags: [String]
    let repriceGap: RepriceGap?

    enum CodingKeys: String, CodingKey {
        case ticker
        case radarScore = "radar_score"
        case gatePass = "gate_pass"
        case categoryScores = "category_scores"
        case confluence
        case crowding
        case signals
        case regimeFlags = "regime_flags"
        case repriceGap = "reprice_gap"
    }

    struct Confluence: Codable {
        let k: Int
        let multiplier: Double
        let tripleSignal: Bool
        let categories: [String]?

        enum CodingKeys: String, CodingKey {
            case k, multiplier, categories
            case tripleSignal = "triple_signal"
        }
    }

    struct Crowding: Codable {
        let value: Double
        let penaltyApplied: Double

        enum CodingKeys: String, CodingKey {
            case value
            case penaltyApplied = "penalty_applied"
        }
    }
}

struct SignalLedgerItem: Codable, Identifiable {
    var id: String { "\(type)-\(sourceUrl)" }
    let type: String
    let category: String
    let evidence: String
    let sourceUrl: String
    let decayedScore: Double
    let ageDays: Double
    let direction: Int

    enum CodingKeys: String, CodingKey {
        case type, category, evidence, direction
        case sourceUrl = "source_url"
        case decayedScore = "decayed_score"
        case ageDays = "age_days"
    }
}

struct RepriceGap: Codable {
    let expectedDriftRemainingPct: Double?
    let windowElapsedPct: Double?

    enum CodingKeys: String, CodingKey {
        case expectedDriftRemainingPct = "expected_drift_remaining_pct"
        case windowElapsedPct = "window_elapsed_pct"
    }
}

struct CouncilExplanation: Codable {
    let verdict: String?
    let thesis: String?
    let reasoningChain: [String]
    let signalsCited: [String]
    let signalsChallenged: [ChallengedSignal]
    let bearCase: String?
    let invalidationConditions: [String]
    let whatWouldChangeMyMind: String?
    let sizingAnnotation: String?

    enum CodingKeys: String, CodingKey {
        case verdict, thesis
        case reasoningChain = "reasoning_chain"
        case signalsCited = "signals_cited"
        case signalsChallenged = "signals_challenged"
        case bearCase = "bear_case"
        case invalidationConditions = "invalidation_conditions"
        case whatWouldChangeMyMind = "what_would_change_my_mind"
        case sizingAnnotation = "sizing_annotation"
    }

    struct ChallengedSignal: Codable {
        let type: String
        let objection: String
    }
}

// MARK: - Factory

extension Opportunity {
    // Feed falls back to live Supabase data; mocks intentionally empty (no fabricated rows).
    static let mocks: [Opportunity] = []
}
