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
                // Supabase returned empty — try seeding, then use mocks
                try? await SupabaseService.shared.seedOpportunities()
                let retry = try? await SupabaseService.shared.fetchFeed(isPremium: isPremium, limit: pageSize, offset: 0)
                opportunities = retry?.isEmpty == false ? retry! : Opportunity.mocks
            } else {
                opportunities = results
                hasMore = results.count == pageSize
            }
        } catch {
            // Supabase unreachable or table doesn't exist — use mock data
            opportunities = Opportunity.mocks
            errorMessage = nil // mocks are fine, don't show error
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
