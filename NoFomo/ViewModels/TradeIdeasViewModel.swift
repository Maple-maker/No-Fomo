import Foundation

@MainActor
final class TradeIdeasViewModel: ObservableObject {
    @Published var ideas: [TradeIdea] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPosting = false

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            ideas = try await SupabaseService.shared.fetchTradeIdeas()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLeaderboard() async {
        do {
            leaderboard = try await SupabaseService.shared.fetchLeaderboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func vote(ideaId: Int) async {
        guard let token = AuthService.shared.currentToken, token != "anon" else { return }
        do {
            let result = try await APIService.shared.voteTradeIdea(id: ideaId, token: token)
            if let idx = ideas.firstIndex(where: { $0.id == ideaId }) {
                let old = ideas[idx]
                ideas[idx] = TradeIdea(
                    id: old.id, userId: old.userId, ticker: old.ticker, body: old.body,
                    direction: old.direction, entryPrice: old.entryPrice, targetPrice: old.targetPrice,
                    timeframeDays: old.timeframeDays, status: old.status, performanceScore: old.performanceScore,
                    upvoteCount: result.upvoteCount, createdAt: old.createdAt, resolvedAt: old.resolvedAt,
                    profile: old.profile
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func post(ticker: String, body: String, direction: String, targetPrice: Double, timeframeDays: Int, token: String) async throws {
        isPosting = true
        defer { isPosting = false }
        let idea = try await APIService.shared.postTradeIdea(
            ticker: ticker, body: body, direction: direction,
            targetPrice: targetPrice, timeframeDays: timeframeDays, token: token
        )
        ideas.insert(idea, at: 0)
    }
}
