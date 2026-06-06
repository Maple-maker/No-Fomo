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
                // Search bar
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.Color.textMuted)
                        TextField("Search ticker (e.g. AAPL)", text: $vm.searchText)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onSubmit { Task { await vm.scanTicker(vm.searchText) } }
                        if !vm.searchText.isEmpty {
                            Button(action: { vm.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(DS.Color.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(DS.Color.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(action: { Task { await vm.scanTicker(vm.searchText) } }) {
                        if vm.isScanning {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(DS.Color.tier1.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .disabled(vm.searchText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isScanning)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

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

                        // Empty state
                        if vm.opportunities.isEmpty && !vm.isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(DS.Color.textMuted)
                                Text("No opportunities yet")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(DS.Color.textSecondary)
                                Text("Search a ticker above to scan for opportunities")
                                    .font(.system(size: 13))
                                    .foregroundColor(DS.Color.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                            .padding(.horizontal, 40)
                        }

                        // Error message
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }

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

                            if !vm.opportunities.isEmpty {
                                let radarCount = vm.opportunities.filter { $0.detectionLane != nil && !$0.detectionLane!.isEmpty }.count
                                Text("AEGIS Radar · \(filtered.count) opportunities · \(radarCount) radar detected")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(DS.Color.textMuted)
                                    .padding(.top, 8)
                                    .padding(.bottom, 24)
                            }
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
// MARK: — Feed header
    private struct FeedHeader: View {
        let count: Int

        var body: some View {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("No Fomo")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(-0.5)
                    Text(count > 0 ? "\(count) opportunities" : "Scan a ticker to start")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Color.textMuted)
                }
                Spacer()
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