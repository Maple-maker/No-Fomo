import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var opportunities: [Opportunity] = []
    @Published var watchlisted: Set<String> = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var hasMore = true
    @Published var errorMessage: String? = nil

    private var page = 0
    private let pageSize = 15

    func loadFeed(isPremium: Bool) async {
        isLoading = true
        errorMessage = nil
        page = 0
        hasMore = true

        do {
            let results = try await SupabaseService.shared.fetchFeed(isPremium: isPremium, limit: pageSize, offset: 0)
            if results.isEmpty {
                // Database is empty — seed it, then retry
                try? await SupabaseService.shared.seedOpportunities()
                let retry = try? await SupabaseService.shared.fetchFeed(isPremium: isPremium, limit: pageSize, offset: 0)
                if let retryResults = retry, !retryResults.isEmpty {
                    opportunities = retryResults
                    hasMore = retryResults.count == pageSize
                } else {
                    // Supabase empty — fall back to local mocks
                    opportunities = Opportunity.mocks
                }
            } else {
                opportunities = results
                hasMore = results.count == pageSize
            }
        } catch {
            // Network/server error — use mock data
            print("[feed] Supabase error: \(error.localizedDescription)")
            opportunities = Opportunity.mocks
        }

        isLoading = false
        isScanning = false
    }

    func loadMore(isPremium: Bool) async {
        guard hasMore, !isLoading else { return }
        page += 1
        isLoading = true
        do {
            let more = try await SupabaseService.shared.fetchFeed(isPremium: isPremium, limit: pageSize, offset: page * pageSize)
            opportunities.append(contentsOf: more)
            hasMore = more.count == pageSize
        } catch {
            hasMore = false
        }
        isLoading = false
    }

    func toggleWatchlist(_ opportunity: Opportunity) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            if watchlisted.contains(opportunity.id) {
                watchlisted.remove(opportunity.id)
                try await SupabaseService.shared.removeFromWatchlist(userId: userId, ticker: opportunity.ticker)
            } else {
                watchlisted.insert(opportunity.id)
                try await SupabaseService.shared.addToWatchlist(userId: userId, opportunityId: opportunity.id, ticker: opportunity.ticker)
            }
        } catch {
            // Silently fail — watchlist is best-effort
        }
    }
}
