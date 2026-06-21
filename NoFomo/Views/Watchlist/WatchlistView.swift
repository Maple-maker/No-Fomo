import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var auth: AuthService
    @State private var items: [Opportunity] = []
    @State private var isLoading = false
    @State private var detailOpp: Opportunity? = nil

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 0) {
                    WatchlistHeader(count: 0)
                    Spacer()
                    ProgressView().tint(DS.Color.textMuted)
                    Spacer()
                }
            } else if items.isEmpty {
                emptyContent
            } else {
                VStack(spacing: 0) {
                    WatchlistHeader(count: items.count)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items) { opp in
                                WatchlistRow(
                                    opportunity: opp,
                                    isSaved: true,
                                    onToggleSave: { removeItem(opp) }
                                )
                                .onTapGesture { detailOpp = opp }
                                .padding(.horizontal, DS.paddingScreen)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 44)
                    }
                }
            }
        }
        .sheet(item: $detailOpp) { opp in
            DetailSheet(opportunity: opp, isPro: true)
        }
        .task {
            await loadWatchlist()
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 0) {
            WatchlistHeader(count: 0)
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "bookmark")
                    .font(.system(size: 34))
                    .foregroundColor(DS.Color.textMuted)
                VStack(spacing: 4) {
                    Text("Nothing tracked yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Bookmark an opportunity to follow its score and buy zones here.")
                        .font(.system(size: 13))
                        .foregroundColor(DS.Color.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
            }
            Spacer()
        }
    }

    private func loadWatchlist() async {
        guard let userId = auth.currentUser?.id else { return }
        isLoading = true
        items = (try? await SupabaseService.shared.fetchWatchlist(userId: userId)) ?? []
        isLoading = false
    }

    private func removeItem(_ opp: Opportunity) {
        Task {
            guard let userId = auth.currentUser?.id else { return }
            try? await SupabaseService.shared.removeFromWatchlist(userId: userId, ticker: opp.ticker)
            items.removeAll { $0.id == opp.id }
        }
    }
}

// MARK: — Watchlist header

struct WatchlistHeader: View {
    let count: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Watchlist")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                Text("\(count) tracked")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.textMuted)
            }
            Spacer()
            // Avatar
            Circle()
                .fill(DS.Color.elevated)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(DS.Color.border, lineWidth: 0.5)
                )
                .overlay(
                    Text("JD")
                        .font(DS.Font.mono(13))
                        .foregroundColor(DS.Color.textSecondary)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

// MARK: — Watchlist row (compact)

struct WatchlistRow: View {
    let opportunity: Opportunity
    let isSaved: Bool
    var onToggleSave: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            ScoreGauge(score: opportunity.score, tier: opportunity.tier, size: 42, stroke: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(opportunity.ticker)
                        .font(DS.Font.mono(16))
                        .foregroundColor(.white)
                    TierBadge(tier: opportunity.tier)
                        .scaleEffect(0.85)
                }
                Text(opportunity.companyName)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(String(format: "%.2f", opportunity.price))")
                    .font(DS.Font.mono(14))
                    .foregroundColor(.white)
                Text("+\(Int(opportunity.upside))%")
                    .font(DS.Font.mono(12))
                    .foregroundColor(DS.Color.bull)
            }
        }
        .padding(DS.paddingCompact)
        .background(DS.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusCard)
                .stroke(DS.Color.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusCard))
    }
}

#Preview {
    WatchlistView()
        .preferredColorScheme(.dark)
}
