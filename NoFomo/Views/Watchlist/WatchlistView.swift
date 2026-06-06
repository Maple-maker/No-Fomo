import SwiftUI

struct WatchlistView: View {
    @State private var savedIDs: Set<String> = ["crvo", "mrdn"]
    @State private var detailOpp: Opportunity? = nil

    private var items: [Opportunity] {
        []  // Real watchlist will sync from Supabase later
    }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            if items.isEmpty {
                emptyContent
            } else {
                VStack(spacing: 0) {
                    WatchlistHeader(count: items.count)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items) { opp in
                                WatchlistRow(
                                    opportunity: opp,
                                    isSaved: savedIDs.contains(opp.id),
                                    onToggleSave: { toggleSave(opp.id) }
                                )
                                .onTapGesture { detailOpp = opp }
                                .padding(.horizontal, 16)
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

    private func toggleSave(_ id: String) {
        if savedIDs.contains(id) {
            savedIDs.remove(id)
        } else {
            savedIDs.insert(id)
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
        .padding(13)
        .background(DS.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DS.Color.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    WatchlistView()
        .preferredColorScheme(.dark)
}
