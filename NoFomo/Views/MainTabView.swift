import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = "feed"

    // ── Notification deep-link ──
    // NotificationRouter is injected in NoFomoApp.swift as .environmentObject.
    // When a push notification is tapped, AppDelegate sets pendingTicker and
    // we present the DetailSheet for that ticker.
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @State private var deepLinkOpportunity: Opportunity? = nil

    private let tabs: [(id: String, label: String, icon: String)] = [
        ("feed", "Feed", "antenna.radiowaves.left.and.right"),
        ("watch", "Watchlist", "bookmark"),
        ("radar", "Radar", "scope"),
        ("settings", "Account", "person"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag("feed")
                WatchlistView()
                    .tag("watch")
                RadarView()
                    .tag("radar")
                SettingsView()
                    .tag("settings")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom tab bar — matches prototype
            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        // ── Present DetailSheet when a notification deep-links to a ticker ──
        .sheet(item: $deepLinkOpportunity) { opp in
            DetailSheet(opportunity: opp, isPro: true)
        }
        .onChange(of: notificationRouter.pendingTicker) { ticker in
            guard let ticker, !ticker.isEmpty else { return }
            Task {
                // Try fetching from Supabase by ticker name via feed lookup
                if let found = try? await SupabaseService.shared.fetchFeed(isPremium: true, limit: 50)
                    .first(where: { $0.ticker.uppercased() == ticker.uppercased() }) {
                    await MainActor.run {
                        deepLinkOpportunity = found
                        notificationRouter.pendingTicker = nil
                    }
                } else {
                    // Ticker not found in current feed — clear pending to avoid retry loop
                    await MainActor.run { notificationRouter.pendingTicker = nil }
                }
            }
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button(action: { withAnimation(DS.Animation.quick) { selectedTab = tab.id } }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                            .fontWeight(selectedTab == tab.id ? .semibold : .regular)
                        Text(tab.label)
                            .font(.system(size: 10, weight: selectedTab == tab.id ? .semibold : .medium))
                    }
                    .foregroundColor(selectedTab == tab.id ? .white : DS.Color.textMuted)
                    // Widen per-tab frame so each item's tap zone meets 44pt minimum height
                    .frame(maxWidth: .infinity, minHeight: DS.minTouchTarget)
                    .contentShape(Rectangle())
                    .animation(DS.Animation.quick, value: selectedTab)
                }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 30)
        .padding(.horizontal, 24)
        .background(
            DS.Color.background.opacity(0.8)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Divider()
                .background(DS.Color.border),
            alignment: .top
        )
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
        .environmentObject(NotificationRouter.shared)
        .preferredColorScheme(.dark)
}
