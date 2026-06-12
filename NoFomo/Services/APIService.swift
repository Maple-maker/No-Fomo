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

        enum CodingKeys: String, CodingKey {
            case ticker, tier, score, bluf, price, volume, currency, signals
            case tripleSignal = "triple_signal"
            case changePct = "change_pct"
        }
    }

    struct RadarSignals: Codable {
        let signals: [String: Bool]?
    }

    private struct ThesisMatchResponse: Codable {
        let matches: [RadarRow]
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
            priceHistory: [],
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
}