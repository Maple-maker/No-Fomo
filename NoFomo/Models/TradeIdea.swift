import Foundation

struct TradeIdeaProfile: Codable {
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let reputationScore: Int
    let currentStreak: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case reputationScore = "reputation_score"
        case currentStreak = "current_streak"
    }
}

struct TradeIdea: Identifiable, Codable {
    let id: Int
    let userId: String
    let ticker: String
    let body: String
    let direction: String
    let entryPrice: Double
    let targetPrice: Double
    let timeframeDays: Int
    let status: String
    let performanceScore: Double?
    let upvoteCount: Int
    let createdAt: String
    let resolvedAt: String?
    let profile: TradeIdeaProfile?

    enum CodingKeys: String, CodingKey {
        case id, ticker, body, direction, status, profile
        case userId = "user_id"
        case entryPrice = "entry_price"
        case targetPrice = "target_price"
        case timeframeDays = "timeframe_days"
        case performanceScore = "performance_score"
        case upvoteCount = "upvote_count"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }

    var isLong: Bool { direction == "long" }
    var authorName: String { profile?.displayName ?? "Trader" }
    var isResolved: Bool { status == "won" || status == "lost" }

    static let mocks: [TradeIdea] = [
        TradeIdea(
            id: 1, userId: "seed", ticker: "MRVL", body: "AI networking backlog not priced in — custom silicon cycle accelerating.",
            direction: "long", entryPrice: 72.5, targetPrice: 95, timeframeDays: 45, status: "open",
            performanceScore: nil, upvoteCount: 12, createdAt: ISO8601DateFormatter().string(from: Date()),
            resolvedAt: nil,
            profile: TradeIdeaProfile(userId: "seed", displayName: "Jaiden", avatarUrl: nil, reputationScore: 240, currentStreak: 3)
        ),
    ]
}

struct LeaderboardEntry: Identifiable, Codable {
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let reputationScore: Int
    let currentStreak: Int
    let longestStreak: Int
    let winCount: Int
    let ideasPosted: Int

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case reputationScore = "reputation_score"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case winCount = "win_count"
        case ideasPosted = "ideas_posted"
    }
}
