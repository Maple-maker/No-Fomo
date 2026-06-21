import SwiftUI

struct TradeIdeaCard: View {
    let idea: TradeIdea
    var onUpvote: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(DS.Color.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(idea.authorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DS.Color.accent)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.authorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(relativeTime(idea.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(DS.Color.textMuted)
                }
                Spacer()
                if let streak = idea.profile?.currentStreak, streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(streak)")
                            .font(DS.Font.mono(11))
                            .foregroundColor(.orange)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("$\(idea.ticker)")
                    .font(DS.Font.mono(13))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(DS.Color.elevated)
                    .clipShape(Capsule())
                Text(idea.isLong ? "LONG" : "SHORT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(idea.isLong ? DS.Color.bull : DS.Color.bear)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((idea.isLong ? DS.Color.bull : DS.Color.bear).opacity(0.12))
                    .clipShape(Capsule())
                if idea.isResolved {
                    Text(idea.status.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(idea.status == "won" ? DS.Color.bull : DS.Color.bear)
                } else {
                    Text("OPEN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DS.Color.textMuted)
                }
            }

            Text(idea.body)
                .font(.system(size: 14))
                .foregroundColor(DS.Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Text("Entry $\(String(format: "%.2f", idea.entryPrice))")
                    .font(DS.Font.mono(11))
                    .foregroundColor(DS.Color.textMuted)
                Text("Target $\(String(format: "%.2f", idea.targetPrice))")
                    .font(DS.Font.mono(11))
                    .foregroundColor(DS.Color.tier1)
                if let score = idea.performanceScore, idea.isResolved {
                    Text("Score \(Int(score))")
                        .font(DS.Font.mono(11))
                        .foregroundColor(score >= 0 ? DS.Color.bull : DS.Color.bear)
                }
            }

            HStack {
                Button(action: onUpvote) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(idea.upvoteCount)")
                            .font(DS.Font.mono(12))
                    }
                    .foregroundColor(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Educational discussion. Not investment advice.")
                    .font(.system(size: 9))
                    .foregroundColor(DS.Color.textMuted)
            }
        }
        .padding(14)
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border, lineWidth: 0.5))
    }

    private func relativeTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)h ago" }
        return "\(hrs / 24)d ago"
    }
}
