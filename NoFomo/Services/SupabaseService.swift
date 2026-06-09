import Foundation

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

    // MARK: - Feed (reads from radar_opportunities table)

    func fetchFeed(isPremium: Bool, limit: Int = 20, offset: Int = 0) async throws -> [Opportunity] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/radar_opportunities"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        var req = URLRequest(url: components.url!)
        req.addCommonHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([RadarRow].self, from: data)
        return rows.map { $0.toOpportunity() }
    }

    func fetchOpportunity(id: Int) async throws -> Opportunity {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/radar_opportunities"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: components.url!)
        req.addCommonHeaders()
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
}

// MARK: - Radar table row (matches radar_opportunities schema)

struct RadarRow: Codable {
    let id: Int?
    let ticker: String
    let tier: Int?
    let overallScore: Double?
    let thesis: String?
    let geminiAnalysis: String?
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
        let priceHistory: [Double]?
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

    enum CodingKeys: String, CodingKey {
        case id, ticker, tier, thesis
        case overallScore = "overall_score"
        case geminiAnalysis = "gemini_analysis"
        case dataSnapshot = "data_snapshot"
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

        return Opportunity(
            id: idStr, ticker: ticker, companyName: coName, sector: sect,
            tier: t, score: sc, tripleSignal: ts, bluf: th,
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
            detectionLane: dl, governmentScore: gsc
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
                priceHistory: priceHistory
            )
        )
    }
}

// MARK: - Helpers

private extension URLRequest {
    mutating func addCommonHeaders() {
        setValue("application/json", forHTTPHeaderField: "Content-Type")
        setValue("application/json", forHTTPHeaderField: "Accept")
        setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        // Read token from UserDefaults directly (nonisolated, avoids MainActor hop)
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        }
    }
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
