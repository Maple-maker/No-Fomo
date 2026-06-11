import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var opportunities: [Opportunity] = []
    @Published var watchlisted: Set<String> = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var hasMore = true
    @Published var errorMessage: String? = nil
    @Published var searchText = ""
    @Published var serverOnline = false

    private var page = 0
    private let pageSize = 15

    func loadFeed(isPremium: Bool) async {
        isLoading = true
        errorMessage = nil
        page = 0
        hasMore = true

        do {
            let results = try await SupabaseService.shared.fetchFeed(isPremium: isPremium, limit: pageSize, offset: 0)
            opportunities = results
            hasMore = results.count == pageSize
        } catch {
            errorMessage = "Feed error: \(error.localizedDescription)"
            opportunities = []
            hasMore = false
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

    /// Scan a new ticker via the radar server
    func scanTicker(_ ticker: String, isPremium: Bool = false) async {
        let cleaned = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            .replacingOccurrences(of: "$", with: "")
        guard !cleaned.isEmpty else { return }

        isScanning = true
        errorMessage = nil

        do {
            let result = try await APIService.shared.scanTicker(cleaned)
            // Insert at top of feed
            opportunities.insert(result, at: 0)
            searchText = ""
        } catch {
            errorMessage = "Scan failed: \(error.localizedDescription)"
        }

        isScanning = false
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