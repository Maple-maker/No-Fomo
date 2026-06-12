import Foundation

enum RadarError: LocalizedError {
    case thesisLimitReached
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .thesisLimitReached:
            return "Free accounts get 1 active thesis. Upgrade to Pro for unlimited theses."
        case .notSignedIn:
            return "Sign in to build a thesis."
        }
    }
}

@MainActor
final class RadarViewModel: ObservableObject {
    @Published var theses: [CustomThesis] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var userId: String? { AuthService.shared.currentUser?.id }
    private var isPro: Bool { AuthService.shared.currentUser?.subscriptionTier.hasFull ?? false }

    func load() async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            theses = try await SupabaseService.shared.fetchTheses(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Create (id == 0) or update a thesis. Free tier: 1 active thesis max.
    func save(_ thesis: CustomThesis) async throws {
        guard userId != nil else { throw RadarError.notSignedIn }
        if thesis.id == 0 && !isPro && theses.filter(\.isActive).count >= 1 {
            throw RadarError.thesisLimitReached
        }
        if thesis.id == 0 {
            let saved = try await SupabaseService.shared.createThesis(thesis)
            theses.insert(saved, at: 0)
        } else {
            try await SupabaseService.shared.updateThesis(thesis)
            if let idx = theses.firstIndex(where: { $0.id == thesis.id }) {
                theses[idx] = thesis
            }
        }
    }

    func delete(_ thesis: CustomThesis) async {
        do {
            try await SupabaseService.shared.deleteThesis(id: thesis.id)
            theses.removeAll { $0.id == thesis.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleActive(_ thesis: CustomThesis) async {
        var updated = thesis
        updated.isActive.toggle()
        do {
            try await SupabaseService.shared.updateThesis(updated)
            if let idx = theses.firstIndex(where: { $0.id == thesis.id }) {
                theses[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// On-demand scan against the radar server.
    func fetchMatches(for thesis: CustomThesis) async -> [Opportunity] {
        do {
            return try await APIService.shared.matchThesis(thesis)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}
