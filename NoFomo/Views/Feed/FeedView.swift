import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject var auth: AuthService

    @State private var activeFilter = "all"
    @State private var detailOpp: Opportunity? = nil
    @State private var isPro = false
    @State private var tickerInput = ""
    @State private var showScanner = false
    @State private var showSupplyChain = false

    private let filters: [(id: String, label: String, bolt: Bool)] = [
        ("all", "All", false),
        ("t1", "Tier 1", false),
        ("t2", "Tier 2", false),
        ("ts", "Triple Signal", true),
        ("radar", "Radar", true),
    ]

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable feed
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        FeedHeader(
                            count: vm.opportunities.count,
                            serverOnline: vm.serverOnline,
                            onScanTap: { showScanner.toggle() },
                            onSupplyChainTap: { showSupplyChain.toggle() }
                        )

                        // Scanner (collapsible)
                        if showScanner { scannerView }

                        // Supply chain scanner (collapsible)

                        // Filter chips
                        FilterChips(
                            filters: filters,
                            active: activeFilter,
                            onChange: { activeFilter = $0 }
                        )
                        .padding(.bottom, 4)

                        // Loading state
                        if vm.isLoading && vm.opportunities.isEmpty {
                            VStack(spacing: 16) {
                                // Skeleton rows — shimmer placeholder
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(DS.Color.elevated)
                                        .frame(height: 88)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0), Color.white.opacity(0.04), Color.white.opacity(0)],
                                                        startPoint: .leading, endPoint: .trailing
                                                    )
                                                )
                                        )
                                }
                                Text("Scanning the market...")
                                    .font(.system(size: 13))
                                    .foregroundColor(DS.Color.textMuted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        // Error banner
                        if let error = vm.errorMessage {
                            VStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                        .lineLimit(3)
                                    Spacer()
                                    Button(action: { vm.errorMessage = nil }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.orange.opacity(0.7))
                                    }
                                }
                                // Retry button
                                Button(action: {
                                    Task { await vm.loadFeed(isPremium: isPro) }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 11))
                                        Text("Retry")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .frame(height: 32)
                                    .background(DS.Color.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Empty state
                        if !vm.isLoading && vm.errorMessage == nil && vm.opportunities.isEmpty {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 40)
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(DS.Color.textMuted.opacity(0.4))
                                Text("No opportunities found")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(DS.Color.textMuted)
                                Text("Check back soon — the radar scans daily at 15:00 UTC.")
                                    .font(.system(size: 13))
                                    .foregroundColor(DS.Color.textMuted.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Button(action: {
                                    Task { await vm.loadFeed(isPremium: isPro) }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 11))
                                        Text("Refresh")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .frame(height: 36)
                                    .background(DS.Color.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .frame(maxWidth: .infinity)
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

                            // Footer
                            let radarCount = vm.opportunities.filter { $0.detectionLane != nil && !$0.detectionLane!.isEmpty }.count
                            Text("AEGIS Radar scanning 8 lanes · \(filtered.count) cleared · \(radarCount) radar detected")
                                .font(.system(size: 11.5))
                                .foregroundColor(DS.Color.textMuted)
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                        }
                    }
                    .refreshable { await vm.loadFeed(isPremium: isPro) }
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
            await vm.loadFeed(isPremium: isPro)
        }
    }

    // MARK: - Scanner view

    private var scannerView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Enter ticker...", text: $tickerInput)
                    .font(DS.Font.mono(14))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(DS.Color.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DS.Color.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(vm.isScanning)
                    .onSubmit { Task { await vm.scanTicker(tickerInput, isPremium: isPro) } }

                Button(action: {
                    Task { await vm.scanTicker(tickerInput, isPremium: isPro) }
                }) {
                    HStack(spacing: 6) {
                        if vm.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(DS.Color.background)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(vm.isScanning ? "Scanning..." : "Scan")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(DS.Color.background)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(vm.isScanning ? DS.Color.elevated : DS.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(vm.isScanning || tickerInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Scan result with enrichment
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
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
        return result
    }
}

// MARK: - Council verdict badge

struct VerdictBadge: View {
    let label: String
    let verdict: String

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(verdict == "BULL" ? DS.Color.tier1 : .red)
            .frame(width: 18, height: 18)
            .background((verdict == "BULL" ? Color.green : Color.red).opacity(0.15))
            .clipShape(Circle())
    }
}

// MARK: — Feed header

struct FeedHeader: View {
    let count: Int
    let serverOnline: Bool
    let onScanTap: () -> Void
    let onSupplyChainTap: () -> Void

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
                HStack(spacing: 6) {
                    Text("\(count) live · \(tripleCount) triple-signal")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Color.textMuted)
                    Circle()
                        .fill(serverOnline ? Color.green : Color.red)
                        .frame(width: 5, height: 5)
                }
            }
            Spacer()
            // Supply-chain scan button
            Button(action: onSupplyChainTap) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Color.tier1)
                    .frame(width: 34, height: 34)
                    .background(DS.Color.elevated)
                    .overlay(
                        Circle()
                            .stroke(DS.Color.tier1.opacity(0.3), lineWidth: 0.5)
                    )
                    .clipShape(Circle())
            }
            // Scan button
            Button(action: onScanTap) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Color.accent)
                    .frame(width: 34, height: 34)
                    .background(DS.Color.elevated)
                    .overlay(
                        Circle()
                            .stroke(DS.Color.border, lineWidth: 0.5)
                    )
                    .clipShape(Circle())
            }
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

// MARK: - Indicator pill with explainer

struct IndicatorPill: View {
    let label: String
    let value: String
    var color: Color = .gray
    var explainer: String = ""
    @State private var showExplainer = false

    var body: some View {
        Button(action: { showExplainer.toggle() }) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(DS.Color.textMuted)
                Text(value)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 8))
                    .foregroundColor(DS.Color.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
        .popover(isPresented: $showExplainer, arrowEdge: .top) {
            Text(explainer)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(12)
                .frame(width: 220)
                .background(DS.Color.card)
        }
    }
}

// MARK: - Stat pill

struct StatPill: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundColor(DS.Color.textMuted)
            Text(value).font(.system(size: 12, weight: .bold)).foregroundColor(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(DS.Color.elevated).clipShape(Capsule())
    }
}

#Preview {
    FeedView()
        .environmentObject(AuthService.shared)
        .preferredColorScheme(.dark)
}
