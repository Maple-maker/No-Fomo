import SwiftUI

struct LeaderboardSheet: View {
    let entries: [LeaderboardEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()
                List {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(DS.Font.mono(14))
                                .foregroundColor(DS.Color.textMuted)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("\(entry.winCount) wins · \(entry.ideasPosted) ideas")
                                    .font(.system(size: 11))
                                    .foregroundColor(DS.Color.textMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(entry.reputationScore)")
                                    .font(DS.Font.mono(14))
                                    .foregroundColor(DS.Color.tier1)
                                if entry.currentStreak > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 9))
                                        Text("\(entry.currentStreak)")
                                            .font(DS.Font.mono(10))
                                    }
                                    .foregroundColor(.orange)
                                }
                            }
                        }
                        .listRowBackground(DS.Color.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
