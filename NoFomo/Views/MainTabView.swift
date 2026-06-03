import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = "feed"

    private let tabs: [(id: String, label: String, icon: String)] = [
        ("feed", "Feed", "antenna.radiowaves.left.and.right"),
        ("watch", "Watchlist", "bookmark"),
        ("settings", "Account", "person"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag("feed")
                WatchlistView()
                    .tag("watch")
                SettingsView()
                    .tag("settings")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom tab bar — matches prototype
            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button(action: { withAnimation { selectedTab = tab.id } }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                            .fontWeight(selectedTab == tab.id ? .semibold : .regular)
                        Text(tab.label)
                            .font(.system(size: 10, weight: selectedTab == tab.id ? .semibold : .medium))
                    }
                    .foregroundColor(selectedTab == tab.id ? .white : DS.Color.textMuted)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 10)
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
        .preferredColorScheme(.dark)
}
