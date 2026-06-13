import Foundation

/// Calls the NoFomo Radar Server (Python MVP on port 3002)
final class APIService {
    static let shared = APIService()

    private let baseURL = "https://server-zeta-six-94.vercel.app"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    struct RadarResponse: Codable {
        let ticker: String
        let tier: Int
        let score: Int
        let tripleSignal: Bool?
        let bluf: String?
        let price: Double?
        let changePct: Double?
        let volume: Int?
        let currency: String?
        let signals: RadarSignals?
        let priceHistory: [Double]?

        enum CodingKeys: String, CodingKey {
            case ticker, tier, score, bluf, price, volume, currency, signals, priceHistory
            case tripleSignal = "triple_signal"
            case changePct = "change_pct"
        }
    }

    struct ChartResponse: Codable {
        let ticker: String
        let priceHistory: [Double]
        let price: Double
        let priceChangePct: Double

        enum CodingKeys: String, CodingKey {
            case ticker, price
            case priceHistory = "price_history"
            case priceChangePct = "price_change_pct"
        }
    }

    struct RadarSignals: Codable {
        let signals: [String: Bool]?
    }

    /// Minimal decode of Yahoo Finance's /v8/finance/chart payload — only the daily closes.
    private struct YahooChartResponse: Codable {
        let chart: Chart
        struct Chart: Codable { let result: [Result]? }
        struct Result: Codable { let indicators: Indicators }
        struct Indicators: Codable { let quote: [Quote] }
        struct Quote: Codable { let close: [Double?]? }
    }

    private struct ThesisMatchResponse: Codable {
        let matches: [RadarRow]
    }

    private struct IdeasFeedResponse: Codable {
        let ideas: [TradeIdea]
    }

    private struct IdeaPostResponse: Codable {
        let idea: TradeIdea
    }

    struct VoteResponse: Codable {
        let voted: Bool
        let upvoteCount: Int

        enum CodingKeys: String, CodingKey {
            case voted
            case upvoteCount = "upvote_count"
        }
    }

    private struct LeaderboardResponse: Codable {
        let leaderboard: [LeaderboardEntry]
    }

    /// Run a thesis against the server's /thesis/match endpoint.
    /// Sends the thesis with snake_case keys (the server normalizes either style)
    /// and decodes the returned radar_opportunities rows via RadarRow.
    func matchThesis(_ thesis: CustomThesis) async throws -> [Opportunity] {
        var req = URLRequest(url: URL(string: "\(baseURL)/thesis/match")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["thesis": thesis])

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Server returned error"])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ThesisMatchResponse.self, from: data).matches.map { $0.toOpportunity() }
    }

    /// Fetch price chart history for a ticker (on-demand backfill).
    func fetchChart(ticker: String) async throws -> ChartResponse {
        let cleaned = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            .replacingOccurrences(of: "$", with: "")
        var components = URLComponents(string: "\(baseURL)/radar/chart")!
        components.queryItems = [URLQueryItem(name: "ticker", value: cleaned)]
        let (data, resp) = try await session.data(from: components.url!)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Chart fetch failed"])
        }
        return try JSONDecoder().decode(ChartResponse.self, from: data)
    }

    /// Fetch ~1 year of live daily closing prices straight from Yahoo Finance.
    ///
    /// This is the PRIMARY chart source. The radar server's backfill gets HTTP 429'd
    /// from Vercel's datacenter IPs, but a user's device IP is not rate-limited — so
    /// pulling closes directly on-device reliably returns daily history.
    func fetchYahooCloses(ticker: String) async throws -> [Double] {
        let cleaned = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            .replacingOccurrences(of: "$", with: "")
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(cleaned)")!
        components.queryItems = [
            URLQueryItem(name: "range", value: "1y"),
            URLQueryItem(name: "interval", value: "1d"),
        ]
        var req = URLRequest(url: components.url!)
        // Yahoo rejects requests without a browser-like User-Agent.
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Yahoo chart fetch failed"])
        }
        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        // Drop the nulls Yahoo emits for market holidays / data gaps.
        return decoded.chart.result?.first?.indicators.quote.first?.close?.compactMap { $0 } ?? []
    }

    /// Scan a ticker via the radar server. Returns an Opportunity.
    func scanTicker(_ ticker: String) async throws -> Opportunity {
        let cleaned = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            .replacingOccurrences(of: "$", with: "")

        var req = URLRequest(url: URL(string: "\(baseURL)/radar")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["ticker": cleaned])

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Server returned error"])
        }

        let radar = try JSONDecoder().decode(RadarResponse.self, from: data)

        // Map to Opportunity model
        var signalTags: [String] = []
        if let sigs = radar.signals?.signals {
            for (key, val) in sigs where val {
                signalTags.append(key.replacingOccurrences(of: "_", with: " ").capitalized)
            }
        }

        return Opportunity(
            id: radar.ticker.lowercased(),
            ticker: radar.ticker,
            companyName: radar.ticker,
            sector: "",
            tier: radar.tier,
            score: Double(radar.score),
            tripleSignal: radar.tripleSignal ?? false,
            bluf: radar.bluf ?? "\(radar.ticker) scored \(radar.score)/100",
            price: radar.price ?? 0,
            upside: 0,
            marketCap: "N/A",
            probability: 0,
            catalyst: "",
            council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
            buyZones: BuyZones(aggressive: 0, base: 0, conservative: 0),
            bullCase: "",
            bearCase: "",
            financials: [],
            redFlags: [],
            invalidation: "",
            priceChangePct: radar.changePct ?? 0,
            taSummary: "",
            aiSynopsis: "",
            geminiReasoning: "",
            deepseekReasoning: "",
            cioReasoning: "",
            recentHeadlines: [],
            sources: [],
            upcomingEvents: [],
            tags: signalTags,
            priceHistory: radar.priceHistory ?? [],
            rsiValue: 50,
            rsiSignal: "neutral",
            macdTrend: "neutral",
            volumeVsAvg: 1.0,
            supportLevel: 0,
            resistanceLevel: 0,
            analystConsensus: "",
            analystCount: 0,
            avgPriceTarget: 0,
            analystHighTarget: 0,
            analystLowTarget: 0,
            recentAnalystActions: [],
            institutionalOwnershipPct: 0,
            institutionalFlow: "flat",
            topHolder: "",
            isPremium: true,
            publishedAt: Date(),
            asymmetryScore: 0,
            convictionScore: 0,
            catalystScore: 0,
            managementScore: 0,
            smartMoneyScore: nil,
            radarDossier: nil,
            researchedAt: nil,
            bullCaseItems: [],
            bearCaseItems: [],
            businessModelSummary: nil,
            macroContext: nil,
            insiderActivity: nil,
            governmentSupport: nil,
            indirectCatalysts: nil,
            overlookedAnalysis: nil,
            detectionLane: nil,
            governmentScore: nil
        )
    }

    func fetchTradeIdeas(limit: Int = 30, offset: Int = 0) async throws -> [TradeIdea] {
        var components = URLComponents(string: "\(baseURL)/ideas")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        let (data, resp) = try await session.data(from: components.url!)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load ideas"])
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(IdeasFeedResponse.self, from: data).ideas
    }

    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        let url = URL(string: "\(baseURL)/ideas/leaderboard")!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load leaderboard"])
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(LeaderboardResponse.self, from: data).leaderboard
    }

    func postTradeIdea(ticker: String, body: String, direction: String, targetPrice: Double, timeframeDays: Int, token: String) async throws -> TradeIdea {
        var req = URLRequest(url: URL(string: "\(baseURL)/ideas")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = [
            "ticker": ticker,
            "body": body,
            "direction": direction,
            "target_price": targetPrice,
            "timeframe_days": timeframeDays,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to post idea"])
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(IdeaPostResponse.self, from: data).idea
    }

    func voteTradeIdea(id: Int, token: String) async throws -> VoteResponse {
        var req = URLRequest(url: URL(string: "\(baseURL)/ideas/\(id)/vote")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vote failed"])
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(VoteResponse.self, from: data)
    }
}