import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var opportunities: [Opportunity] = []
    @Published var watchlisted: Set<String> = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var hasMore = true

    private var page = 0
    private let pageSize = 15

    func loadFeed(isPremium: Bool) async {
        isLoading = true
        page = 0
        hasMore = true
        // Use mock data — replace with Supabase when backend is ready
        opportunities = Opportunity.mocks
        isLoading = false
    }

    func loadMore(isPremium: Bool) async {
        // Mock: no more pages for now
        hasMore = false
    }

    func toggleWatchlist(_ opportunity: Opportunity) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        if watchlisted.contains(opportunity.id) {
            watchlisted.remove(opportunity.id)
            try? await SupabaseService.shared.removeFromWatchlist(userId: userId, ticker: opportunity.ticker)
        } else {
            watchlisted.insert(opportunity.id)
            try? await SupabaseService.shared.addToWatchlist(userId: userId, opportunityId: opportunity.id, ticker: opportunity.ticker)
        }
    }
}
