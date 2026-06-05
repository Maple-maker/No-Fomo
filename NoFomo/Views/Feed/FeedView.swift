import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject var auth: AuthService

    @State private var activeFilter = "all"
    @State private var activeTag: String? = nil
    @State private var detailOpp: Opportunity? = nil
    @State private var isPro = false

    private let filters: [(id: String, label: String, bolt: Bool)] = [
        ("all", "All", false),
        ("t1", "Tier 1", false),
        ("t2", "Tier 2", false),
        ("ts", "Triple Signal", true),
        ("radar", "Radar", true),
    ]

    private var allTags: [String] {
        Array(Set(vm.opportunities.flatMap { $0.tags })).sorted()
    }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable feed
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        FeedHeader(count: vm.opportunities.count)

                        // Filter chips
                        FilterChips(
                            filters: filters,
                            active: activeFilter,
                            onChange: { activeFilter = $0 }
                        )
                        .padding(.bottom, 4)

                        // Industry dropdown
                        HStack(spacing: 8) {
                            Menu {
                                Button(action: { activeTag = nil }) {
                                    HStack {
                                        Text("All Industries")
                                        if activeTag == nil { Image(systemName: "checkmark") }
                                    }
                                }
                                Divider()
                                ForEach(allTags, id: \.self) { tag in
                                    Button(action: { activeTag = tag }) {
                                        HStack {
                                            Text(tag)
                                            if activeTag == tag { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(activeTag ?? "Industry")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(activeTag != nil ? DS.Color.background : DS.Color.textSecondary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(activeTag != nil ? DS.Color.background : DS.Color.textMuted)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(activeTag != nil ? DS.Color.accent : DS.Color.elevated)
                                .clipShape(Capsule())
                            }

                            if activeTag != nil {
                                Button(action: { activeTag = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(DS.Color.textSecondary)
                                        .frame(width: 22, height: 22)
                                        .background(DS.Color.elevated)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Cards
                        LazyVStack(spacing: 14) {
                            ForEach(filtered) { opp in
                                OpportunityCard(
                                    opportunity: opp,
                                    onOpen: { detailOpp = opp },
                                    onUnlock: { isPro = true },
                                    density: .regular,
                                    gaugeStyle: .ring,
                                    isLocked: !isPro
                                )
                                .padding(.horizontal, 16)
                            }

                            // Footer
                            let radarCount = vm.opportunities.filter { $0.detectionLane != nil && !$0.detectionLane!.isEmpty }.count
                            Text("AEGIS Radar scanning 8 lanes · \(filtered.count) cleared · \(radarCount) radar detected")
                                .font(.system(size: 11.5))
                                .foregroundColor(DS.Color.textMuted)
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                        }
                    }
                }

                // Tab bar spacer
                Color.clear.frame(height: 22)
            }
        }
        .sheet(item: $detailOpp) { opp in
            DetailSheet(
                opportunity: opp,
                isPro: isPro,
                onTogglePro: { isPro.toggle() }
            )
        }
        .task {
            vm.opportunities = Opportunity.mocks
        }
    }

    private var filtered: [Opportunity] {
        var result: [Opportunity]
        switch activeFilter {
        case "t1": result = vm.opportunities.filter { $0.tier == 1 }
        case "t2": result = vm.opportunities.filter { $0.tier == 2 }
        case "ts": result = vm.opportunities.filter { $0.tripleSignal }
        case "radar": result = vm.opportunities.filter { $0.detectionLane != nil && !$0.detectionLane!.isEmpty }
        default: result = vm.opportunities
        }
        if let tag = activeTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        return result
    }
}

// MARK: — Feed header

struct FeedHeader: View {
    let count: Int
    private var tripleCount: Int {
        Opportunity.mocks.filter { $0.tripleSignal }.count
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("No Fomo")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                Text("\(count) live · \(tripleCount) triple-signal")
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

// MARK: — Filter chips

struct FilterChips: View {
    let filters: [(id: String, label: String, bolt: Bool)]
    let active: String
    let onChange: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.id) { filter in
                    Button(action: { onChange(filter.id) }) {
                        HStack(spacing: 5) {
                            if filter.bolt {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(DS.Color.tier1)
                            }
                            Text(filter.label)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(active == filter.id ? DS.Color.background : DS.Color.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(
                            active == filter.id
                                ? Color.white
                                : DS.Color.elevated
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    active == filter.id
                                        ? Color.white
                                        : DS.Color.border,
                                    lineWidth: 0.5
                                )
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(AuthService.shared)
        .preferredColorScheme(.dark)
}
