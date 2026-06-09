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
                        if showSupplyChain { supplyChainView }

                        // Filter chips
                        FilterChips(
                            filters: filters,
                            active: activeFilter,
                            onChange: { activeFilter = $0 }
                        )
                        .padding(.bottom, 4)

                        // Loading state
                        if vm.isLoading && vm.opportunities.isEmpty {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .tint(DS.Color.accent)
                                Text("Loading radar feed...")
                                    .font(.system(size: 13))
                                    .foregroundColor(DS.Color.textMuted)
                            }
                            .frame(height: 200)
                        }

                        // Error banner
                        if let error = vm.errorMessage {
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
            if let result = vm.scanResult { scanResultCard(result) }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Supply chain scanner

    private var supplyChainView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Color.tier1)
                Text("Supply-Chain Asymmetry Scanner")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("9 anchors · AI mapped")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Color.textMuted)
            }

            Text("Traces hyperscaler AI capex downstream to find neglected beneficiaries before the market prices them in.")
                .font(.system(size: 11))
                .foregroundColor(DS.Color.textSecondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button(action: {
                    Task { await vm.runSupplyChainScan() }
                }) {
                    HStack(spacing: 6) {
                        if vm.isSupplyChainScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(DS.Color.background)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(vm.isSupplyChainScanning ? "Scanning supply chains..." : "Run Supply-Chain Scan")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(DS.Color.background)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(vm.isSupplyChainScanning ? DS.Color.elevated : DS.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(vm.isSupplyChainScanning)

                Button(action: { showSupplyChain = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DS.Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(DS.Color.elevated)
                        .clipShape(Circle())
                }
            }

            // Scan results
            if let result = vm.supplyChainResult {
                VStack(spacing: 8) {
                    // Summary bar
                    HStack(spacing: 12) {
                        StatPill(label: "Candidates", value: "\(result.uniqueCandidates)")
                        StatPill(label: "Tier 1", value: "\(result.summary.tier1HighAsymmetry.count)", color: DS.Color.tier1)
                        StatPill(label: "Tier 2", value: "\(result.summary.tier2MediumAsymmetry.count)", color: DS.Color.accent)
                        StatPill(label: "Persisted", value: result.persisted > 0 ? "✓ \(result.persisted)" : "✗", color: result.persisted > 0 ? .green : .orange)
                    }

                    // Tier 1 picks
                    if !result.summary.tier1HighAsymmetry.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TIER 1 — HIGH ASYMMETRY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Color.tier1)
                            Text(result.summary.tier1HighAsymmetry.joined(separator: ", "))
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .lineLimit(3)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.tier1.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DS.Color.tier1.opacity(0.2), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Top picks list
                    ForEach(result.topPicks.prefix(8), id: \.ticker) { pick in
                        HStack(spacing: 8) {
                            Text(pick.ticker)
                                .font(DS.Font.mono(12))
                                .foregroundColor(DS.Color.accent)
                                .frame(width: 48, alignment: .leading)
                            Text(pick.company)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(pick.layer)
                                .font(.system(size: 10))
                                .foregroundColor(DS.Color.textMuted)
                                .lineLimit(1)
                            Text("\(pick.asymmetryScore)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(pick.asymmetryScore >= 30 ? DS.Color.tier1 : DS.Color.textSecondary)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.Color.card.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Scan result card (enriched)

    private func scanResultCard(_ result: RadarService.ScanResult) -> some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 10) {
                Text("\(Int(result.score))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(result.tier == 1 ? DS.Color.tier1 : DS.Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("$\(result.ticker) — Tier \(result.tier)")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    if let price = result.price {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(DS.Color.accent)
                        + Text(result.changePct.map { String(format: " %+.1f%%", $0) } ?? "")
                            .font(.system(size: 10)).foregroundColor((result.changePct ?? 0) >= 0 ? .green : .red)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        VerdictBadge(label: "B", verdict: result.council.bull)
                        VerdictBadge(label: "S", verdict: result.council.bear)
                        VerdictBadge(label: "N", verdict: result.council.neutral)
                    }
                    if result.persisted {
                        Text("✓ saved to Supabase").font(.system(size: 8)).foregroundColor(.green.opacity(0.6))
                    }
                }
            }

            // AI Snapshot
            if let snap = result.aiSnapshot {
                Text(snap)
                    .font(.system(size: 11)).foregroundColor(DS.Color.textSecondary).lineLimit(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.elevated.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Analyst consensus row
            if let a = result.analyst {
                HStack(spacing: 8) {
                    Text("🎯").font(.system(size: 11))
                    Text(a.consensus?.uppercased() ?? "N/A")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor((a.consensus ?? "") == "buy" ? .green : .orange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((a.consensus ?? "") == "buy" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                    Text("\(a.count ?? 0) analysts").font(.system(size: 10)).foregroundColor(DS.Color.textMuted)
                    if let t = a.targetMean {
                        Text("· Target $\(String(format: "%.0f", t))").font(.system(size: 10)).foregroundColor(DS.Color.textMuted)
                    }
                    Spacer()
                }
            }

            // Indicators row
            if let ind = result.indicators {
                HStack(spacing: 10) {
                    if let rsi = ind.rsi {
                        IndicatorPill(
                            label: "RSI", value: "\(Int(rsi.value ?? 50))",
                            color: (rsi.signal == "oversold") ? .green : (rsi.signal == "overbought") ? .red : .gray,
                            explainer: rsi.explainer ?? ""
                        )
                    }
                    if let macd = ind.macd {
                        IndicatorPill(
                            label: "MACD", value: macd.trend == "bullish" ? "↑" : "↓",
                            color: macd.trend == "bullish" ? .green : .red,
                            explainer: macd.explainer ?? ""
                        )
                    }
                    if let vol = ind.volume {
                        IndicatorPill(
                            label: "Vol", value: String(format: "%.1fx", vol.ratio ?? 1),
                            color: (vol.ratio ?? 1) > 1.2 ? .green : .gray,
                            explainer: vol.explainer ?? ""
                        )
                    }
                    Spacer()
                }
            }

            // Institutional & catalysts
            if let inst = result.institutional, !inst.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🏛 Top Holders").font(.system(size: 9, weight: .bold)).foregroundColor(DS.Color.textMuted)
                    ForEach(inst.prefix(3), id: \.name) { h in
                        HStack(spacing: 4) {
                            Text(h.name?.prefix(25) ?? "").font(.system(size: 10)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            Text("$\(String(format: "%.1fB", (h.value ?? 0) / 1e9))")
                                .font(.system(size: 10, weight: .medium)).foregroundColor(DS.Color.textSecondary)
                            if let chg = h.pctChange {
                                Text(String(format: "%+.1f%%", chg * 100))
                                    .font(.system(size: 9)).foregroundColor(chg >= 0 ? .green : .red)
                            }
                        }
                    }
                }
                .padding(8)
                .background(DS.Color.elevated.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Sources
            if !result.sources.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🔗 Clickable Sources").font(.system(size: 9, weight: .bold)).foregroundColor(DS.Color.textMuted)
                    ForEach(result.sources.prefix(4), id: \.url) { s in
                        HStack(spacing: 4) {
                            Image(systemName: "link").font(.system(size: 8)).foregroundColor(DS.Color.accent)
                            Text(s.label.prefix(60)).font(.system(size: 9)).foregroundColor(DS.Color.accent).lineLimit(1)
                        }
                    }
                }
                .padding(8)
                .background(DS.Color.elevated.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(DS.Color.card)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Color.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
