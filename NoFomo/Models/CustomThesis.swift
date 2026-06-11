import Foundation

// MARK: - CustomThesis (maps user_theses table)

struct CustomThesis: Identifiable, Codable, Equatable {
    var id: Int                  // 0 = not yet saved
    var userId: String
    var name: String
    var description: String?
    var templateId: String?

    var detectionLanes: [String]
    var minScore: Int
    var minUpside: Double
    var minProbability: Double
    var sectorFilter: [String]
    var tierFilter: [Int]
    var requireTripleSignal: Bool
    var maxAnalystCount: Int?
    var minMarketCapB: Double?
    var maxMarketCapB: Double?

    var requireInsiderBuying: Bool
    var requireGovContract: Bool
    var requireFdaCatalyst: Bool
    var requireEarningsInflection: Bool
    var requireAnalystUpgrade: Bool
    var requireBullConsensus: Bool

    var notifyTier1: Bool
    var notifyTier2: Bool
    var isActive: Bool
    var matchCount: Int
    // timestamptz strings (fractional seconds break JSONDecoder's .iso8601)
    var lastMatchedAt: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case userId = "user_id"
        case templateId = "template_id"
        case detectionLanes = "detection_lanes"
        case minScore = "min_score"
        case minUpside = "min_upside"
        case minProbability = "min_probability"
        case sectorFilter = "sector_filter"
        case tierFilter = "tier_filter"
        case requireTripleSignal = "require_triple_signal"
        case maxAnalystCount = "max_analyst_count"
        case minMarketCapB = "min_market_cap_b"
        case maxMarketCapB = "max_market_cap_b"
        case requireInsiderBuying = "require_insider_buying"
        case requireGovContract = "require_gov_contract"
        case requireFdaCatalyst = "require_fda_catalyst"
        case requireEarningsInflection = "require_earnings_inflection"
        case requireAnalystUpgrade = "require_analyst_upgrade"
        case requireBullConsensus = "require_bull_consensus"
        case notifyTier1 = "notify_tier1"
        case notifyTier2 = "notify_tier2"
        case isActive = "is_active"
        case matchCount = "match_count"
        case lastMatchedAt = "last_matched_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        templateId = try c.decodeIfPresent(String.self, forKey: .templateId)
        detectionLanes = try c.decodeIfPresent([String].self, forKey: .detectionLanes) ?? []
        minScore = try c.decodeIfPresent(Int.self, forKey: .minScore) ?? 75
        minUpside = try c.decodeIfPresent(Double.self, forKey: .minUpside) ?? 100
        minProbability = try c.decodeIfPresent(Double.self, forKey: .minProbability) ?? 60
        sectorFilter = try c.decodeIfPresent([String].self, forKey: .sectorFilter) ?? []
        tierFilter = try c.decodeIfPresent([Int].self, forKey: .tierFilter) ?? [1, 2]
        requireTripleSignal = try c.decodeIfPresent(Bool.self, forKey: .requireTripleSignal) ?? false
        maxAnalystCount = try c.decodeIfPresent(Int.self, forKey: .maxAnalystCount)
        minMarketCapB = try c.decodeIfPresent(Double.self, forKey: .minMarketCapB)
        maxMarketCapB = try c.decodeIfPresent(Double.self, forKey: .maxMarketCapB)
        requireInsiderBuying = try c.decodeIfPresent(Bool.self, forKey: .requireInsiderBuying) ?? false
        requireGovContract = try c.decodeIfPresent(Bool.self, forKey: .requireGovContract) ?? false
        requireFdaCatalyst = try c.decodeIfPresent(Bool.self, forKey: .requireFdaCatalyst) ?? false
        requireEarningsInflection = try c.decodeIfPresent(Bool.self, forKey: .requireEarningsInflection) ?? false
        requireAnalystUpgrade = try c.decodeIfPresent(Bool.self, forKey: .requireAnalystUpgrade) ?? false
        requireBullConsensus = try c.decodeIfPresent(Bool.self, forKey: .requireBullConsensus) ?? false
        notifyTier1 = try c.decodeIfPresent(Bool.self, forKey: .notifyTier1) ?? true
        notifyTier2 = try c.decodeIfPresent(Bool.self, forKey: .notifyTier2) ?? true
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        matchCount = try c.decodeIfPresent(Int.self, forKey: .matchCount) ?? 0
        lastMatchedAt = try c.decodeIfPresent(String.self, forKey: .lastMatchedAt)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(
        id: Int, userId: String, name: String, description: String?, templateId: String?,
        detectionLanes: [String], minScore: Int, minUpside: Double, minProbability: Double,
        sectorFilter: [String], tierFilter: [Int], requireTripleSignal: Bool,
        maxAnalystCount: Int?, minMarketCapB: Double?, maxMarketCapB: Double?,
        requireInsiderBuying: Bool, requireGovContract: Bool, requireFdaCatalyst: Bool,
        requireEarningsInflection: Bool, requireAnalystUpgrade: Bool, requireBullConsensus: Bool,
        notifyTier1: Bool, notifyTier2: Bool, isActive: Bool, matchCount: Int,
        lastMatchedAt: String?, createdAt: String?
    ) {
        self.id = id; self.userId = userId; self.name = name
        self.description = description; self.templateId = templateId
        self.detectionLanes = detectionLanes; self.minScore = minScore
        self.minUpside = minUpside; self.minProbability = minProbability
        self.sectorFilter = sectorFilter; self.tierFilter = tierFilter
        self.requireTripleSignal = requireTripleSignal
        self.maxAnalystCount = maxAnalystCount
        self.minMarketCapB = minMarketCapB; self.maxMarketCapB = maxMarketCapB
        self.requireInsiderBuying = requireInsiderBuying
        self.requireGovContract = requireGovContract
        self.requireFdaCatalyst = requireFdaCatalyst
        self.requireEarningsInflection = requireEarningsInflection
        self.requireAnalystUpgrade = requireAnalystUpgrade
        self.requireBullConsensus = requireBullConsensus
        self.notifyTier1 = notifyTier1; self.notifyTier2 = notifyTier2
        self.isActive = isActive; self.matchCount = matchCount
        self.lastMatchedAt = lastMatchedAt; self.createdAt = createdAt
    }

    static func blank(userId: String) -> CustomThesis {
        CustomThesis(
            id: 0, userId: userId, name: "", description: nil, templateId: nil,
            detectionLanes: [], minScore: 75, minUpside: 100, minProbability: 60,
            sectorFilter: [], tierFilter: [1, 2], requireTripleSignal: false,
            maxAnalystCount: nil, minMarketCapB: nil, maxMarketCapB: nil,
            requireInsiderBuying: false, requireGovContract: false, requireFdaCatalyst: false,
            requireEarningsInflection: false, requireAnalystUpgrade: false, requireBullConsensus: false,
            notifyTier1: true, notifyTier2: true, isActive: true, matchCount: 0,
            lastMatchedAt: nil, createdAt: nil
        )
    }
}

// MARK: - Write payload (insert/update) — writable columns only.
// Omits id (BIGSERIAL), match_count, last_matched_at, created_at.

struct ThesisWritePayload: Encodable {
    let thesis: CustomThesis

    init(_ thesis: CustomThesis) { self.thesis = thesis }

    enum CodingKeys: String, CodingKey {
        case name, description
        case userId = "user_id"
        case templateId = "template_id"
        case detectionLanes = "detection_lanes"
        case minScore = "min_score"
        case minUpside = "min_upside"
        case minProbability = "min_probability"
        case sectorFilter = "sector_filter"
        case tierFilter = "tier_filter"
        case requireTripleSignal = "require_triple_signal"
        case maxAnalystCount = "max_analyst_count"
        case minMarketCapB = "min_market_cap_b"
        case maxMarketCapB = "max_market_cap_b"
        case requireInsiderBuying = "require_insider_buying"
        case requireGovContract = "require_gov_contract"
        case requireFdaCatalyst = "require_fda_catalyst"
        case requireEarningsInflection = "require_earnings_inflection"
        case requireAnalystUpgrade = "require_analyst_upgrade"
        case requireBullConsensus = "require_bull_consensus"
        case notifyTier1 = "notify_tier1"
        case notifyTier2 = "notify_tier2"
        case isActive = "is_active"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(thesis.userId, forKey: .userId)
        try c.encode(thesis.name, forKey: .name)
        try c.encodeIfPresent(thesis.description, forKey: .description)
        try c.encodeIfPresent(thesis.templateId, forKey: .templateId)
        try c.encode(thesis.detectionLanes, forKey: .detectionLanes)
        try c.encode(thesis.minScore, forKey: .minScore)
        try c.encode(thesis.minUpside, forKey: .minUpside)
        try c.encode(thesis.minProbability, forKey: .minProbability)
        try c.encode(thesis.sectorFilter, forKey: .sectorFilter)
        try c.encode(thesis.tierFilter, forKey: .tierFilter)
        try c.encode(thesis.requireTripleSignal, forKey: .requireTripleSignal)
        try c.encodeIfPresent(thesis.maxAnalystCount, forKey: .maxAnalystCount)
        try c.encodeIfPresent(thesis.minMarketCapB, forKey: .minMarketCapB)
        try c.encodeIfPresent(thesis.maxMarketCapB, forKey: .maxMarketCapB)
        try c.encode(thesis.requireInsiderBuying, forKey: .requireInsiderBuying)
        try c.encode(thesis.requireGovContract, forKey: .requireGovContract)
        try c.encode(thesis.requireFdaCatalyst, forKey: .requireFdaCatalyst)
        try c.encode(thesis.requireEarningsInflection, forKey: .requireEarningsInflection)
        try c.encode(thesis.requireAnalystUpgrade, forKey: .requireAnalystUpgrade)
        try c.encode(thesis.requireBullConsensus, forKey: .requireBullConsensus)
        try c.encode(thesis.notifyTier1, forKey: .notifyTier1)
        try c.encode(thesis.notifyTier2, forKey: .notifyTier2)
        try c.encode(thesis.isActive, forKey: .isActive)
    }
}

// MARK: - Prebuilt templates
// Kept manually in sync with TEMPLATES in server/src/routes/thesis.ts.
// Lane strings must be canonical detection lanes from the radar prompt.

struct ThesisTemplate: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let icon: String

    var detectionLanes: [String] = []
    var sectorFilter: [String] = []
    var tierFilter: [Int] = [1, 2]
    var minScore: Int = 75
    var minUpside: Double = 100
    var maxAnalystCount: Int? = nil
    var maxMarketCapB: Double? = nil
    var requireInsiderBuying = false
    var requireGovContract = false
    var requireFdaCatalyst = false
    var requireEarningsInflection = false
    var requireBullConsensus = false

    func makeThesis(userId: String) -> CustomThesis {
        var t = CustomThesis.blank(userId: userId)
        t.name = name
        t.description = blurb
        t.templateId = id
        t.detectionLanes = detectionLanes
        t.sectorFilter = sectorFilter
        t.tierFilter = tierFilter
        t.minScore = minScore
        t.minUpside = minUpside
        t.maxAnalystCount = maxAnalystCount
        t.maxMarketCapB = maxMarketCapB
        t.requireInsiderBuying = requireInsiderBuying
        t.requireGovContract = requireGovContract
        t.requireFdaCatalyst = requireFdaCatalyst
        t.requireEarningsInflection = requireEarningsInflection
        t.requireBullConsensus = requireBullConsensus
        return t
    }

    static let all: [ThesisTemplate] = [
        ThesisTemplate(id: "underfollowed-gem", name: "The Underfollowed Gem",
                       blurb: "Tiny analyst coverage, insiders buying, huge upside",
                       icon: "diamond.fill",
                       minUpside: 150, maxAnalystCount: 3, requireInsiderBuying: true),
        ThesisTemplate(id: "gov-contract-play", name: "Government Contract Play",
                       blurb: "Small caps catching government & regulatory tailwinds",
                       icon: "building.columns.fill",
                       detectionLanes: ["Government & Regulatory Support"], maxMarketCapB: 5),
        ThesisTemplate(id: "earnings-turnaround", name: "Earnings Turnaround",
                       blurb: "Revenue inflecting positive with a strong score",
                       icon: "chart.line.uptrend.xyaxis",
                       tierFilter: [2], minScore: 78, requireEarningsInflection: true),
        ThesisTemplate(id: "deep-value-activist", name: "Deep Value Activist",
                       blurb: "Under-covered names with 3x+ upside potential",
                       icon: "scope",
                       minUpside: 200, maxAnalystCount: 5),
        ThesisTemplate(id: "ai-infrastructure", name: "AI Infrastructure Pick",
                       blurb: "Picks-and-shovels for the AI buildout",
                       icon: "cpu.fill",
                       sectorFilter: ["AI & Data Infrastructure", "Semiconductors"],
                       tierFilter: [2], minUpside: 150),
        ThesisTemplate(id: "biotech-catalyst", name: "Biotech Binary Catalyst",
                       blurb: "FDA events with full AI council conviction",
                       icon: "cross.case.fill",
                       sectorFilter: ["Biotech"],
                       requireFdaCatalyst: true, requireBullConsensus: true),
        ThesisTemplate(id: "insider-cluster", name: "Insider Accumulation Cluster",
                       blurb: "Multiple insiders buying in the open market",
                       icon: "person.3.fill",
                       requireInsiderBuying: true),
        ThesisTemplate(id: "defense-ai", name: "Defense × AI Convergence",
                       blurb: "Autonomy and defense tech with government backing",
                       icon: "shield.lefthalf.filled",
                       detectionLanes: ["Government & Regulatory Support"],
                       sectorFilter: ["Defense Tech", "AI & Data Infrastructure"]),
        ThesisTemplate(id: "renaissance-rebrand", name: "Renaissance Company",
                       blurb: "Legacy businesses the market still prices as the old company",
                       icon: "arrow.triangle.2.circlepath",
                       detectionLanes: ["Renaissance / Rebrand"],
                       minUpside: 200, maxAnalystCount: 6),
        ThesisTemplate(id: "short-squeeze", name: "Short Squeeze Setup",
                       blurb: "Insider conviction on under-covered, shorted names",
                       icon: "flame.fill",
                       maxAnalystCount: 4, requireInsiderBuying: true),
    ]
}
