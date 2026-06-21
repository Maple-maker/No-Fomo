import Foundation
import Security

// MARK: - Supabase Configuration

private let SUPABASE_URL = "https://jmtkygwvmrolfvwueggs.supabase.co"
private let SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptdGt5Z3d2bXJvbGZ2d3VlZ2dzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzMzAxODUsImV4cCI6MjA5NTkwNjE4NX0.JUbsLc_KHHdfXWDSAl9Rf00Da-axpSj4Nw4DvXGNBvk"

// MARK: - Supabase API Client

final class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL: URL
    private let session: URLSession

    private init() {
        baseURL = URL(string: SUPABASE_URL)!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Feed (reads from radar_feed_public view — readable by anon, contains all fields)

    func fetchFeed(isPremium: Bool, limit: Int = 20, offset: Int = 0) async throws -> [Opportunity] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/radar_feed_public"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        var req = URLRequest(url: components.url!)
        req.addPublicHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let rows = try decoder.decode([RadarRow].self, from: data)
            return rows.map { $0.toOpportunity() }
        } catch {
            // One malformed row crashed the array — decode per-row and skip bad ones
            guard let rawArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
            return rawArray.compactMap { dict -> Opportunity? in
                guard let rowData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                return (try? decoder.decode(RadarRow.self, from: rowData))?.toOpportunity()
            }
        }
    }

    func fetchOpportunity(id: Int) async throws -> Opportunity {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/radar_feed_public"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: components.url!)
        req.addPublicHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        let rows = try decoder.decode([RadarRow].self, from: data)
        guard let first = rows.first else { throw AppError.notFound }
        return first.toOpportunity()
    }

    // MARK: - Watchlist

    func fetchWatchlist(userId: String) async throws -> [Opportunity] {
        var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1/rpc/get_watchlist"))
        req.httpMethod = "POST"
        req.addCommonHeaders()
        req.httpBody = try JSONEncoder().encode(["user_id": userId])
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Opportunity].self, from: data)
    }

    func addToWatchlist(userId: String, opportunityId: String, ticker: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1/user_watchlist"))
        req.httpMethod = "POST"
        req.addCommonHeaders()
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let body: [String: String] = [
            "user_id": userId,
            "opportunity_id": opportunityId,
            "ticker": ticker,
        ]
        req.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: req)
        try validate(response: response, data: nil)
    }

    func removeFromWatchlist(userId: String, ticker: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/user_watchlist"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "ticker", value: "eq.\(ticker)"),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "DELETE"
        req.addCommonHeaders()
        let (_, response) = try await session.data(for: req)
        try validate(response: response, data: nil)
    }

    // MARK: - Push token registration

    func registerPushToken(_ token: String, userId: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1/push_tokens"))
        req.httpMethod = "POST"
        req.addCommonHeaders()
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode([
            "user_id": userId,
            "apns_token": token,
        ])
        _ = try await session.data(for: req)
    }

    // MARK: - Custom Theses (user_theses table)

    func fetchTheses(userId: String) async throws -> [CustomThesis] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/user_theses"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
        ]
        var req = URLRequest(url: components.url!)
        req.addCommonHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([CustomThesis].self, from: data)
    }

    func createThesis(_ thesis: CustomThesis) async throws -> CustomThesis {
        var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1/user_theses"))
        req.httpMethod = "POST"
        req.addCommonHeaders()
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(ThesisWritePayload(thesis))
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        guard let saved = try JSONDecoder().decode([CustomThesis].self, from: data).first else {
            throw AppError.notFound
        }
        return saved
    }

    func updateThesis(_ thesis: CustomThesis) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/user_theses"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(thesis.id)")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "PATCH"
        req.addCommonHeaders()
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(ThesisWritePayload(thesis))
        let (_, response) = try await session.data(for: req)
        try validate(response: response, data: nil)
    }

    func deleteThesis(id: Int) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/user_theses"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "DELETE"
        req.addCommonHeaders()
        let (_, response) = try await session.data(for: req)
        try validate(response: response, data: nil)
    }

    // MARK: - Community trade ideas (reads Supabase directly — no server deploy required)

    func fetchTradeIdeas(limit: Int = 30) async throws -> [TradeIdea] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/trade_ideas"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "status", value: "in.(open,won,lost)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        var req = URLRequest(url: components.url!)
        req.addPublicHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rows = try decoder.decode([TradeIdea].self, from: data)
        return try await attachProfiles(to: rows)
    }

    func fetchLeaderboard(limit: Int = 20) async throws -> [LeaderboardEntry] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/user_profiles"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "reputation_score.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        var req = URLRequest(url: components.url!)
        req.addPublicHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([LeaderboardEntry].self, from: data)
    }

    private func attachProfiles(to ideas: [TradeIdea]) async throws -> [TradeIdea] {
        let userIds = Array(Set(ideas.map(\.userId)))
        guard !userIds.isEmpty else { return ideas }

        let idList = userIds.joined(separator: ",")
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/user_profiles"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "user_id,display_name,avatar_url,reputation_score,current_streak"),
            URLQueryItem(name: "user_id", value: "in.(\(idList))"),
        ]
        var req = URLRequest(url: components.url!)
        req.addPublicHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profiles = try decoder.decode([TradeIdeaProfile].self, from: data)
        let byUser = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })

        return ideas.map { idea in
            TradeIdea(
                id: idea.id,
                userId: idea.userId,
                ticker: idea.ticker,
                body: idea.body,
                direction: idea.direction,
                entryPrice: idea.entryPrice,
                targetPrice: idea.targetPrice,
                timeframeDays: idea.timeframeDays,
                status: idea.status,
                performanceScore: idea.performanceScore,
                upvoteCount: idea.upvoteCount,
                createdAt: idea.createdAt,
                resolvedAt: idea.resolvedAt,
                profile: byUser[idea.userId]
            )
        }
    }
}

// MARK: - Radar table row (matches radar_opportunities schema)

struct RadarRow: Codable {
    let id: Int?
    let ticker: String
    let tier: Int?
    let overallScore: Double?
    let thesis: String?
    let geminiAnalysis: String?
    let scoreBreakdown: ScoreBreakdown?
    let repriceGap: RepriceGap?
    let councilExplanation: CouncilExplanation?
    let regimeFlags: [String]?
    let dataSnapshot: Snapshot?

    struct Snapshot: Codable {
        let companyName: String?
        let sector: String?
        let tripleSignal: Bool?
        let price: Double?
        let upside: Double?
        let marketCap: String?
        let probability: Double?
        let catalyst: String?
        let council: CouncilData?
        let buyZones: BuyZonesData?
        let bullCase: String?
        let bearCase: String?
        let financials: [[String]]?
        let keyMetrics: KeyMetricsData?
        let redFlags: [String]?
        let invalidation: String?
        let priceChangePct: Double?
        let taSummary: String?
        let aiSynopsis: String?
        let geminiReasoning: String?
        let deepseekReasoning: String?
        let cioReasoning: String?
        let recentHeadlines: [[String]]?
        let sources: [[String]]?
        let tags: [String]?
        let upcomingEvents: [[String]]?
        let rsiValue: Double?
        let rsiSignal: String?
        let macdTrend: String?
        let volumeVsAvg: Double?
        let supportLevel: Double?
        let resistanceLevel: Double?
        let institutionalOwnershipPct: Double?
        let institutionalFlow: String?
        let topHolder: String?
        let analystConsensus: String?
        let analystCount: Int?
        let avgPriceTarget: Double?
        let analystHighTarget: Double?
        let analystLowTarget: Double?
        let recentAnalystActions: [[String]]?
        let radarDossier: String?
        let researchedAt: String?
        let bullCaseItems: [String]?
        let bearCaseItems: [String]?
        let businessModelSummary: String?
        let macroContext: String?
        let insiderActivity: String?
        let governmentSupport: String?
        let indirectCatalysts: String?
        let overlookedAnalysis: String?
        let detectionLane: String?
        let asymmetryScore: Int?
        let convictionScore: Int?
        let catalystScore: Int?
        let managementScore: Int?
        let smartMoneyScore: Int?
        let governmentScore: Int?
        let asymmetryRationale: String?
        let convictionRationale: String?
        let catalystRationale: String?
        let managementRationale: String?
        let smartMoneySignal: String?
        let governmentSignal: String?
        let priceHistory: [Double]?
        let scoreBreakdown: ScoreBreakdown?
        let repriceGap: RepriceGap?
        let councilExplanation: CouncilExplanation?
        let regimeFlags: [String]?
        // ── Valuation + Wall-Street (Phase 0) ──
        let valuation: Valuation?
        let wallStreet: WallStreet?
        let peerComparison: [PeerCompany]?
        let peerPercentileRank: Int?
        let peerVerdict: String?
    }

    struct CouncilData: Codable {
        let gemini: String?
        let deepseek: String?
        let cio: String?
    }

    struct BuyZonesData: Codable {
        let aggressive: Double?
        let base: Double?
        let conservative: Double?
    }

    func toOpportunity() -> Opportunity {
        let snap = dataSnapshot
        let idStr = id.map(String.init) ?? ticker.lowercased()
        let coName = snap?.companyName ?? ticker
        let sect = snap?.sector ?? ""
        let t = tier ?? 2
        let sc = overallScore ?? 0
        let ts = snap?.tripleSignal ?? false
        let th = thesis ?? ""
        let pr = snap?.price ?? 0
        let up = snap?.upside ?? 0
        let mc = snap?.marketCap ?? "N/A"
        let prob = snap?.probability ?? 0
        let cat = snap?.catalyst ?? ""
        let council = AICouncil(
            gemini: parseVerdict(snap?.council?.gemini ?? geminiAnalysis),
            deepseek: parseVerdict(snap?.council?.deepseek ?? "BULL"),
            cio: parseVerdict(snap?.council?.cio ?? "BULL")
        )
        let zones = BuyZones(
            aggressive: snap?.buyZones?.aggressive ?? 0,
            base: snap?.buyZones?.base ?? 0,
            conservative: snap?.buyZones?.conservative ?? 0
        )
        let bc = snap?.bullCase ?? ""
        let bear = snap?.bearCase ?? ""
        let fin = snap?.financials ?? []
        let km = snap?.keyMetrics
        let rf = snap?.redFlags ?? []
        let inv = snap?.invalidation ?? ""
        let pcp = snap?.priceChangePct ?? 0
        let ta = snap?.taSummary ?? ""
        let ai = snap?.aiSynopsis ?? ""
        let gr = snap?.geminiReasoning ?? ""
        let dr = snap?.deepseekReasoning ?? ""
        let cr = snap?.cioReasoning ?? ""
        let rh = snap?.recentHeadlines ?? []
        let src = snap?.sources ?? []
        let ue = snap?.upcomingEvents ?? []
        let tg = snap?.tags ?? []
        let rsiV = snap?.rsiValue ?? 50
        let rsiS = snap?.rsiSignal ?? "neutral"
        let macd = snap?.macdTrend ?? "neutral"
        let vva = snap?.volumeVsAvg ?? 1.0
        let sl = snap?.supportLevel ?? 0
        let rl = snap?.resistanceLevel ?? 0
        let iop = snap?.institutionalOwnershipPct ?? 0
        let iflow = snap?.institutionalFlow ?? "flat"
        let tholder = snap?.topHolder ?? ""
        let acons = snap?.analystConsensus ?? ""
        let acnt = snap?.analystCount ?? 0
        let apt = snap?.avgPriceTarget ?? 0
        let ahigh = snap?.analystHighTarget ?? 0
        let alow = snap?.analystLowTarget ?? 0
        let raa = snap?.recentAnalystActions ?? []
        let rd = snap?.radarDossier
        let ra = snap?.researchedAt
        let bci = snap?.bullCaseItems ?? []
        let bci2 = snap?.bearCaseItems ?? []
        let bms = snap?.businessModelSummary
        let mcx = snap?.macroContext
        let ia = snap?.insiderActivity
        let gs = snap?.governmentSupport
        let ic = snap?.indirectCatalysts
        let oa = snap?.overlookedAnalysis
        let dl = snap?.detectionLane
        let gsc = snap?.governmentScore
        let asym = snap?.asymmetryScore ?? 0
        let conv = snap?.convictionScore ?? 0
        let cats = snap?.catalystScore ?? 0
        let mgmt = snap?.managementScore ?? 0
        let sms = snap?.smartMoneyScore
        let ph = snap?.priceHistory
        let v2Score = scoreBreakdown ?? snap?.scoreBreakdown
        let v2Reprice = repriceGap ?? snap?.repriceGap ?? v2Score?.repriceGap
        let v2Council = councilExplanation ?? snap?.councilExplanation
        let v2Flags = regimeFlags ?? snap?.regimeFlags ?? v2Score?.regimeFlags ?? []

        return Opportunity(
            id: idStr, ticker: ticker, companyName: coName, sector: sect,
            tier: t, score: v2Score?.radarScore ?? sc, tripleSignal: v2Score?.confluence?.tripleSignal ?? ts, bluf: th,
            price: pr, upside: up, marketCap: mc, probability: prob,
            catalyst: cat, council: council, buyZones: zones,
            bullCase: bc, bearCase: bear, financials: fin,
            redFlags: rf, invalidation: inv,
            priceChangePct: pcp, taSummary: ta, aiSynopsis: ai,
            geminiReasoning: gr, deepseekReasoning: dr, cioReasoning: cr,
            recentHeadlines: rh, sources: src, upcomingEvents: ue, tags: tg,
            priceHistory: ph ?? [],
            rsiValue: rsiV, rsiSignal: rsiS, macdTrend: macd,
            volumeVsAvg: vva, supportLevel: sl, resistanceLevel: rl,
            analystConsensus: acons, analystCount: acnt, avgPriceTarget: apt,
            analystHighTarget: ahigh, analystLowTarget: alow, recentAnalystActions: raa,
            institutionalOwnershipPct: iop, institutionalFlow: iflow, topHolder: tholder,
            isPremium: true, publishedAt: Date(),
            asymmetryScore: asym, convictionScore: conv, catalystScore: cats, managementScore: mgmt,
            smartMoneyScore: sms,
            radarDossier: rd, researchedAt: ra,
            bullCaseItems: bci, bearCaseItems: bci2,
            businessModelSummary: bms, macroContext: mcx,
            insiderActivity: ia, governmentSupport: gs,
            indirectCatalysts: ic, overlookedAnalysis: oa,
            detectionLane: dl, governmentScore: gsc,
            scoreBreakdown: v2Score, repriceGap: v2Reprice,
            councilExplanation: v2Council, regimeFlags: v2Flags,
            keyMetrics: km,
            asymmetryRationale: snap?.asymmetryRationale, convictionRationale: snap?.convictionRationale,
            catalystRationale: snap?.catalystRationale, managementRationale: snap?.managementRationale,
            smartMoneySignal: snap?.smartMoneySignal, governmentSignal: snap?.governmentSignal,
            valuation: snap?.valuation, wallStreet: snap?.wallStreet,
            peerComparison: snap?.peerComparison, peerPercentileRank: snap?.peerPercentileRank,
            peerVerdict: snap?.peerVerdict
        )
    }

    private func parseVerdict(_ s: String?) -> Verdict {
        guard let s = s?.uppercased() else { return .bull }
        return s == "BEAR" ? .bear : .bull
    }
}

extension Opportunity {
    func toRadarRow() -> RadarRow {
        RadarRow(
            id: Int(id) ?? nil,
            ticker: ticker,
            tier: tier,
            overallScore: score,
            thesis: bluf,
            geminiAnalysis: council.cio.rawValue,
            scoreBreakdown: scoreBreakdown,
            repriceGap: repriceGap,
            councilExplanation: councilExplanation,
            regimeFlags: regimeFlags,
            dataSnapshot: RadarRow.Snapshot(
                companyName: companyName,
                sector: sector,
                tripleSignal: tripleSignal,
                price: price,
                upside: upside,
                marketCap: marketCap,
                probability: probability,
                catalyst: catalyst,
                council: RadarRow.CouncilData(
                    gemini: council.gemini.rawValue,
                    deepseek: council.deepseek.rawValue,
                    cio: council.cio.rawValue
                ),
                buyZones: RadarRow.BuyZonesData(
                    aggressive: buyZones.aggressive,
                    base: buyZones.base,
                    conservative: buyZones.conservative
                ),
                bullCase: bullCase,
                bearCase: bearCase,
                financials: financials,
                keyMetrics: keyMetrics,
                redFlags: redFlags,
                invalidation: invalidation,
                priceChangePct: priceChangePct,
                taSummary: taSummary,
                aiSynopsis: aiSynopsis,
                geminiReasoning: geminiReasoning,
                deepseekReasoning: deepseekReasoning,
                cioReasoning: cioReasoning,
                recentHeadlines: recentHeadlines,
                sources: sources,
                tags: tags,
                upcomingEvents: upcomingEvents,
                rsiValue: rsiValue,
                rsiSignal: rsiSignal,
                macdTrend: macdTrend,
                volumeVsAvg: volumeVsAvg,
                supportLevel: supportLevel,
                resistanceLevel: resistanceLevel,
                institutionalOwnershipPct: institutionalOwnershipPct,
                institutionalFlow: institutionalFlow,
                topHolder: topHolder,
                analystConsensus: analystConsensus,
                analystCount: analystCount,
                avgPriceTarget: avgPriceTarget,
                analystHighTarget: analystHighTarget,
                analystLowTarget: analystLowTarget,
                recentAnalystActions: recentAnalystActions,
                radarDossier: radarDossier,
                researchedAt: researchedAt,
                bullCaseItems: bullCaseItems,
                bearCaseItems: bearCaseItems,
                businessModelSummary: businessModelSummary,
                macroContext: macroContext,
                insiderActivity: insiderActivity,
                governmentSupport: governmentSupport,
                indirectCatalysts: indirectCatalysts,
                overlookedAnalysis: overlookedAnalysis,
                detectionLane: detectionLane,
                asymmetryScore: asymmetryScore,
                convictionScore: convictionScore,
                catalystScore: catalystScore,
                managementScore: managementScore,
                smartMoneyScore: smartMoneyScore,
                governmentScore: governmentScore,
                asymmetryRationale: asymmetryRationale,
                convictionRationale: convictionRationale,
                catalystRationale: catalystRationale,
                managementRationale: managementRationale,
                smartMoneySignal: smartMoneySignal,
                governmentSignal: governmentSignal,
                priceHistory: priceHistory,
                scoreBreakdown: scoreBreakdown,
                repriceGap: repriceGap,
                councilExplanation: councilExplanation,
                regimeFlags: regimeFlags,
                valuation: valuation,
                wallStreet: wallStreet,
                peerComparison: peerComparison,
                peerPercentileRank: peerPercentileRank,
                peerVerdict: peerVerdict
            )
        )
    }
}

// MARK: - Helpers

private extension URLRequest {
    mutating func addPublicHeaders() {
        setValue("application/json", forHTTPHeaderField: "Content-Type")
        setValue("application/json", forHTTPHeaderField: "Accept")
        setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
    }

    mutating func addCommonHeaders() {
        setValue("application/json", forHTTPHeaderField: "Content-Type")
        setValue("application/json", forHTTPHeaderField: "Accept")
        setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        setValue("Bearer \(supabaseBearer())", forHTTPHeaderField: "Authorization")
    }
}

private func supabaseBearer() -> String {
    guard let bearer = keychainLoad(key: "auth_token"),
          bearer != "anon",
          bearer != "dev-skip-token",
          bearer.split(separator: ".").count == 3 else {
        return SUPABASE_ANON_KEY
    }
    return bearer
}

private func keychainLoad(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.nofomo.app",
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}

private func validate(response: URLResponse, data: Data?) throws {
    guard let http = response as? HTTPURLResponse else {
        throw AppError.networkError("Invalid response")
    }
    switch http.statusCode {
    case 200...299: return
    case 401: throw AppError.unauthorized
    case 404: throw AppError.notFound
    case 409:
        // Conflict on seed — duplicate, ignore
        return
    default:
        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
        throw AppError.networkError("HTTP \(http.statusCode): \(body)")
    }
}

enum AppError: Error {
    case notFound
    case unauthorized
    case networkError(String)
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound: return "Resource not found"
        case .unauthorized: return "Unauthorized — check API key"
        case .networkError(let msg): return msg
        }
    }
}
