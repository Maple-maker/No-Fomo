import Foundation

// MARK: - Supabase Configuration

private let SUPABASE_URL = "https://lmgphebvungyqsnqitcg.supabase.co"
private let SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtZ3BoZWJ2dW5neXFzbnFpdGNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NjMwNzQsImV4cCI6MjA5NTAzOTA3NH0.yc9oLd6qBDuy-DCVuv0TjUFCeaowGZTrsiXLeqEnwqk"

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

    // MARK: - Seed data (posts to radar_opportunities)

    func seedOpportunities() async throws {
        let rows = Opportunity.mocks.map { $0.toRadarRow() }
        for row in rows {
            var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1/radar_opportunities"))
            req.httpMethod = "POST"
            req.addCommonHeaders()
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            req.httpBody = try JSONEncoder().encode(row)
            let (_, response) = try await session.data(for: req)
            try validate(response: response, data: nil)
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
        return Opportunity(
            id: id.map(String.init) ?? ticker.lowercased(),
            ticker: ticker,
            companyName: snap?.companyName ?? ticker,
            sector: snap?.sector ?? "",
            tier: tier ?? 2,
            score: overallScore ?? 0,
            tripleSignal: snap?.tripleSignal ?? false,
            bluf: thesis ?? "",
            price: snap?.price ?? 0,
            upside: snap?.upside ?? 0,
            marketCap: snap?.marketCap ?? "N/A",
            probability: snap?.probability ?? 0,
            catalyst: snap?.catalyst ?? "",
            council: council,
            buyZones: zones,
            bullCase: snap?.bullCase ?? "",
            bearCase: snap?.bearCase ?? "",
            financials: snap?.financials ?? [],
            redFlags: snap?.redFlags ?? [],
            invalidation: snap?.invalidation ?? "",
            isPremium: true,
            publishedAt: Date()
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
                invalidation: invalidation
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
