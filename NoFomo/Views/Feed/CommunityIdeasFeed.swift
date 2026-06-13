import SwiftUI

struct CommunityIdeasFeed: View {
    @StateObject private var vm = TradeIdeasViewModel()
    @EnvironmentObject var auth: AuthService
    @State private var showCompose = false
    @State private var showLeaderboard = false
    @State private var showAuthPrompt = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("Community Ideas")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { Task { await vm.loadLeaderboard(); showLeaderboard = true } }) {
                        Image(systemName: "trophy")
                            .font(.system(size: 16))
                            .foregroundColor(DS.Color.tier1)
                    }
                    Button(action: { handleComposeTap() }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16))
                            .foregroundColor(DS.Color.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if vm.isLoading && vm.ideas.isEmpty {
                    ProgressView()
                        .tint(DS.Color.accent)
                        .padding(.top, 40)
                } else if let error = vm.errorMessage, vm.ideas.isEmpty {
                    VStack(spacing: 10) {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.bear)
                        Button("Retry") { Task { await vm.loadFeed() } }
                            .foregroundColor(DS.Color.accent)
                    }
                    .padding()
                } else if vm.ideas.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 32))
                            .foregroundColor(DS.Color.textMuted.opacity(0.5))
                        Text("No trade ideas yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DS.Color.textSecondary)
                        Text("Be the first to post — tap the pencil icon.")
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.textMuted)
                    }
                    .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.ideas) { idea in
                            TradeIdeaCard(idea: idea) {
                                Task { await vm.vote(ideaId: idea.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .refreshable { await vm.loadFeed() }
        .task { await vm.loadFeed() }
        .sheet(isPresented: $showCompose) {
            if let token = auth.currentToken, token != "anon" {
                ComposeIdeaSheet(token: token) { ticker, body, direction, target, days in
                    try await vm.post(ticker: ticker, body: body, direction: direction, targetPrice: target, timeframeDays: days, token: token)
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardSheet(entries: vm.leaderboard)
        }
        .alert("Sign in required", isPresented: $showAuthPrompt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Post and vote on trade ideas with Apple or email sign-in.")
        }
    }

    private func handleComposeTap() {
        guard let token = auth.currentToken, token != "anon" else {
            showAuthPrompt = true
            return
        }
        showCompose = true
    }
}
