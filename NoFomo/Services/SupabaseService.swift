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

    // MARK: - Feed

    func fetchFeed(isPremium: Bool, limit: Int = 20, offset: Int = 0) async throws -> [Opportunity] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/opportunity_feed"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        if !isPremium {
            components.queryItems?.append(URLQueryItem(name: "is_premium", value: "eq.false"))
        }
        var req = URLRequest(url: components.url!)
        req.addCommonHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Opportunity].self, from: data)
    }

    func fetchOpportunity(id: String) async throws -> Opportunity {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/v1/opportunity_feed"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: components.url!)
        req.addCommonHeaders()
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let results = try decoder.decode([Opportunity].self, from: data)
        guard let first = results.first else { throw AppError.notFound }
        return first
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

    // MARK: - Seed data (for bootstrapping)

    func seedOpportunities() async throws {
        let opportunities = Opportunity.mocks
        for opp in opportunities {
            var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1/opportunity_feed"))
            req.httpMethod = "POST"
            req.addCommonHeaders()
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            req.httpBody = try JSONEncoder().encode(opp)
            let (_, response) = try await session.data(for: req)
            try validate(response: response, data: nil)
        }
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
