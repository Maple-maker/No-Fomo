import SwiftUI

// MARK: — Detail sheet (matches prototype drawer layout)

struct DetailSheet: View {
    let opportunity: Opportunity
    let isPro: Bool
    var onTogglePro: () -> Void = {}
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    grabber

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            stickyHeader
                            blufSection
                                .padding(.top, 10)
                            metricsSection
                                .padding(.top, 12)

                            happeningNowSection
                            priceChartSection
                            technicalsSection
                            institutionalSection
                            analystSection
                            upcomingSection
                            newsSection
                            sourcesSection
                            councilSection
                            radarDossierSection
                            financialsSection
                            buyZonesSection
                            bearCaseSection
                        }
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: Grabber
    private var grabber: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)
            Divider().background(DS.Color.border).opacity(0)
        }
    }

    // MARK: Sticky header
    private var stickyHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    TierBadge(tier: opportunity.tier)
                    if opportunity.tripleSignal { TripleSignalBadge(pulse: false) }
                }
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(opportunity.ticker)
                        .font(DS.Font.mono(26)).foregroundColor(.white)
                    Text("+\(Int(opportunity.upside))%")
                        .font(DS.Font.mono(15)).foregroundColor(DS.Color.bull)
                }
                Text("\(opportunity.companyName) · \(opportunity.sector)")
                    .font(.system(size: 13)).foregroundColor(DS.Color.textSecondary)
            }
            Spacer()
            VStack(spacing: 8) {
                ScoreGauge(score: opportunity.score, tier: opportunity.tier, size: 62)
                HStack(spacing: 7) {
                    Button(action: { saved.toggle() }) {
                        Circle().fill(saved ? DS.Color.tier1.opacity(0.16) : DS.Color.elevated)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(saved ? DS.Color.tier1.opacity(0.4) : DS.Color.border, lineWidth: 0.5))
                            .overlay(Image(systemName: "bookmark.fill").font(.system(size: 12)).foregroundColor(saved ? DS.Color.tier1 : DS.Color.textSecondary))
                    }
                    Button(action: { onClose?() ?? dismiss() }) {
                        Circle().fill(DS.Color.elevated).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(DS.Color.border, lineWidth: 0.5))
                            .overlay(Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(DS.Color.textSecondary))
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 16)
    }

    // MARK: BLUF
    private var blufSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLUF · BOTTOM LINE UP FRONT")
                .font(.system(size: 10.5)).foregroundColor(DS.Color.textMuted).tracking(0.6)
            Text(opportunity.bluf)
                .font(.system(size: 16)).foregroundColor(.white).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20).padding(.bottom, 18)
    }

    // MARK: Metrics strip
    private var metricsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)) {
            DetailMetric(label: "Price", value: "$\(String(format: "%.2f", opportunity.price))")
            DetailMetric(label: "Upside", value: "+\(Int(opportunity.upside))%", color: DS.Color.bull)
            DetailMetric(label: "Mkt Cap", value: "$\(opportunity.marketCap)")
            DetailMetric(label: "Prob", value: "\(Int(opportunity.probability))%", color: DS.Color.accent)
        }
        .padding(.vertical, 11).padding(.horizontal, 13)
        .background(DS.Color.elevated).clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
    }

    // MARK: Price chart
    private var priceChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !opportunity.priceHistory.isEmpty {
                Divider().background(DS.Color.border)
                let data = opportunity.priceHistory
                let minV = data.min() ?? 0
                let maxV = data.max() ?? 1
                let r = max(maxV - minV, 0.01)
                let up = (data.last ?? 0) >= (data.first ?? 0)
                VStack(spacing: 2) {
                    HStack {
                        Text("$\(String(format: "%.0f", maxV))").font(.system(size: 9)).foregroundColor(DS.Color.textMuted)
                        Spacer()
                    }
                    GeometryReader { geo in
                        Path { path in
                            guard data.count > 1 else { return }
                            let w = geo.size.width / CGFloat(data.count - 1)
                            for i in 0..<data.count {
                                let x = CGFloat(i) * w
                                let y = CGFloat((maxV - data[i]) / r) * geo.size.height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(up ? DS.Color.bull : DS.Color.bear, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: 50)
                    HStack {
                        Text("$\(String(format: "%.0f", minV))").font(.system(size: 9)).foregroundColor(DS.Color.textMuted)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16)
            }
        }
    }

    // MARK: Happening Now
    private var happeningNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(DS.Color.border)
            sectionLabel("HAPPENING NOW")
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(opportunity.priceChangePct >= 0 ? "▲" : "▼").font(.system(size: 11))
                    Text(String(format: "%+.1f%% today", opportunity.priceChangePct)).font(DS.Font.mono(13))
                }
                .foregroundColor(opportunity.priceChangePct >= 0 ? DS.Color.bull : DS.Color.bear)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((opportunity.priceChangePct >= 0 ? DS.Color.bull : DS.Color.bear).opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke((opportunity.priceChangePct >= 0 ? DS.Color.bull : DS.Color.bear).opacity(0.3), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(opportunity.taSummary).font(DS.Font.mono(12)).foregroundColor(DS.Color.textSecondary)
            }
            if !opportunity.aiSynopsis.isEmpty {
                if let attr = try? AttributedString(markdown: opportunity.aiSynopsis) {
                    Text(attr).font(DS.Font.body(14)).foregroundColor(DS.Color.textSecondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        .environment(\.openURL, OpenURLAction { url in UIApplication.shared.open(url); return .handled })
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    // MARK: Technical Analysis
    private var technicalsSection: some View {
        ExpandableSection(title: "Trading Indicators", defaultOpen: false) {
            VStack(spacing: 0) {
                taRow("RSI (14)", String(format: "%.0f", opportunity.rsiValue), signal: opportunity.rsiSignal)
                taRow("MACD Trend", "", signal: opportunity.macdTrend)
                taRow("Volume vs Avg", String(format: "%.1fx", opportunity.volumeVsAvg), signal: opportunity.volumeVsAvg > 1.2 ? "high" : opportunity.volumeVsAvg < 0.8 ? "low" : "normal")
                taRow("Support", "$\(String(format: "%.2f", opportunity.supportLevel))")
                taRow("Resistance", "$\(String(format: "%.2f", opportunity.resistanceLevel))")
            }
        }
    }

    private func taRow(_ label: String, _ value: String, signal: String = "") -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(DS.Color.textSecondary)
            Spacer()
            Text(value).font(DS.Font.mono(13)).foregroundColor(.white)
            if !signal.isEmpty {
                Text(signal.uppercased())
                    .font(.system(size: 9.5, weight: .semibold)).tracking(0.5)
                    .foregroundColor(
                        signal == "oversold" || signal == "bearish" || signal == "low" || signal == "distribution"
                            ? DS.Color.bear
                            : signal == "overbought" || signal == "bullish" || signal == "high" || signal == "accumulation"
                                ? DS.Color.bull
                                : DS.Color.textMuted
                    )
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(DS.Color.elevated).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(DS.Color.card)
    }

    // MARK: Institutional Flow
    private var institutionalSection: some View {
        ExpandableSection(title: "Institutional Flow", defaultOpen: false) {
            VStack(spacing: 0) {
                taRow("Institutional Own.", "\(String(format: "%.1f", opportunity.institutionalOwnershipPct))%", signal: opportunity.institutionalOwnershipPct > 50 ? "high" : opportunity.institutionalOwnershipPct < 25 ? "low" : "normal")
                taRow("13F Flow", "", signal: opportunity.institutionalFlow)
                taRow("Top Holder", opportunity.topHolder)
            }
        }
    }

    // MARK: Analyst Consensus
    private var analystSection: some View {
        ExpandableSection(
            title: "Analyst Consensus",
            defaultOpen: false,
            badge: AnyView(
                HStack(spacing: 4) {
                    Text(opportunity.analystConsensus).font(.system(size: 10, weight: .bold))
                        .foregroundColor(opportunity.analystConsensus == "Bullish" ? DS.Color.bull : DS.Color.textSecondary)
                    Text("· \(opportunity.analystCount) analysts").font(DS.Font.mono(10)).foregroundColor(DS.Color.textMuted)
                }
            )
        ) {
            VStack(spacing: 12) {
                // Price target range bar
                if opportunity.avgPriceTarget > 0 {
                    let low = opportunity.analystLowTarget
                    let high = opportunity.analystHighTarget
                    let cur = opportunity.price
                    let range = max(high - low, 1)
                    VStack(spacing: 6) {
                        HStack {
                            Text("Price Targets vs Current").font(.system(size: 11)).foregroundColor(DS.Color.textMuted)
                            Spacer()
                            Text("Avg PT: $\(String(format: "%.0f", opportunity.avgPriceTarget))")
                                .font(DS.Font.mono(12)).foregroundColor(.white)
                        }
                        GeometryReader { geo in
                            let curX = CGFloat((cur - low) / range) * geo.size.width
                            let avgX = CGFloat((opportunity.avgPriceTarget - low) / range) * geo.size.width
                            ZStack(alignment: .leading) {
                                Capsule().fill(DS.Color.elevated).frame(height: 6)
                                if avgX > 0 && avgX < geo.size.width {
                                    Capsule().fill(DS.Color.accent.opacity(0.5)).frame(width: 4, height: 16)
                                        .offset(x: avgX - 2)
                                }
                                Circle().fill(DS.Color.bull).frame(width: 10, height: 10)
                                    .offset(x: max(0, min(curX - 5, geo.size.width - 10)))
                            }
                        }
                        .frame(height: 16)
                        HStack {
                            Text("$\(String(format: "%.0f", low))").font(.system(size: 10)).foregroundColor(DS.Color.bear)
                            Spacer()
                            Text("$\(String(format: "%.0f", high))").font(.system(size: 10)).foregroundColor(DS.Color.bull)
                        }
                        HStack {
                            Text("Current: $\(String(format: "%.2f", opportunity.price))")
                                .font(DS.Font.mono(11)).foregroundColor(DS.Color.bull)
                            Spacer()
                            Text("Upside to avg PT: \(String(format: "%.0f", ((opportunity.avgPriceTarget / opportunity.price) - 1) * 100))%")
                                .font(DS.Font.mono(11)).foregroundColor(DS.Color.accent)
                        }
                    }
                }

                // Recent analyst actions
                if !opportunity.recentAnalystActions.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RECENT ANALYST ACTIONS")
                            .font(.system(size: 9.5)).foregroundColor(DS.Color.textMuted).tracking(0.5)
                        ForEach(Array(opportunity.recentAnalystActions.enumerated()), id: \.offset) { i, action in
                            let firm = action.count > 0 ? action[0] : ""
                            let date = action.count > 1 ? action[1] : ""
                            let act = action.count > 2 ? action[2] : ""
                            let note = action.count > 3 ? action[3] : ""
                            HStack(alignment: .top, spacing: 8) {
                                Text(date).font(DS.Font.mono(10)).foregroundColor(DS.Color.textMuted).frame(width: 38, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(firm).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                                        Text(act).font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(act.lowercased().contains("buy") || act.lowercased().contains("outperform") || act.lowercased().contains("overweight") ? DS.Color.bull : act.lowercased().contains("sell") ? DS.Color.bear : DS.Color.textSecondary)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(DS.Color.elevated).clipShape(Capsule())
                                    }
                                    Text(note).font(.system(size: 11.5)).foregroundColor(DS.Color.textSecondary).lineSpacing(2)
                                }
                            }
                            .padding(.vertical, 7)
                            if i < opportunity.recentAnalystActions.count - 1 { Divider().background(DS.Color.border) }
                        }
                    }
                }

                // AI vs Analysts contrast
                if !opportunity.analystConsensus.isEmpty {
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("WALL STREET").font(.system(size: 9)).foregroundColor(DS.Color.textMuted).tracking(0.5)
                            Text(opportunity.analystConsensus.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(opportunity.analystConsensus == "Bullish" ? DS.Color.bull : DS.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            Text("AI COUNCIL").font(.system(size: 9)).foregroundColor(DS.Color.textMuted).tracking(0.5)
                            let bulls = [opportunity.council.gemini, opportunity.council.deepseek, opportunity.council.cio].filter { $0 == .bull }.count
                            Text("\(bulls)/3 BULL")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(bulls >= 2 ? DS.Color.bull : DS.Color.bear)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(10)
                    .background(DS.Color.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: Upcoming
    private var upcomingSection: some View {
        ExpandableSection(
            title: "Upcoming",
            defaultOpen: true,
            badge: AnyView(
                Text("\(opportunity.upcomingEvents.count)").font(DS.Font.mono(11)).foregroundColor(DS.Color.tier1)
            )
        ) {
            VStack(spacing: 0) {
                ForEach(Array(opportunity.upcomingEvents.enumerated()), id: \.offset) { i, event in
                    let date = event.count > 0 ? event[0] : ""
                    let desc = event.count > 1 ? event[1] : ""
                    let type = event.count > 2 ? event[2] : ""
                    HStack(spacing: 10) {
                        Text(date.uppercased())
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(type == "earnings" ? DS.Color.tier1 : type == "sector" ? DS.Color.accent : DS.Color.tier2)
                            .frame(width: 72, alignment: .leading)
                        Circle()
                            .fill(type == "earnings" ? DS.Color.tier1 : type == "sector" ? DS.Color.accent : DS.Color.tier2)
                            .frame(width: 4, height: 4)
                        Text(desc)
                            .font(.system(size: 13)).foregroundColor(.white).lineSpacing(2)
                        Spacer()
                        Text(type.uppercased())
                            .font(.system(size: 8.5, weight: .bold)).tracking(0.6)
                            .foregroundColor(type == "earnings" ? DS.Color.tier1 : type == "sector" ? DS.Color.accent : DS.Color.tier2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((type == "earnings" ? DS.Color.tier1 : type == "sector" ? DS.Color.accent : DS.Color.tier2).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(i % 2 == 0 ? Color.clear : DS.Color.card)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border, lineWidth: 0.5))
        }
    }

    // MARK: News
    private var newsSection: some View {
        ExpandableSection(
            title: "Recent Headlines",
            defaultOpen: true,
            badge: AnyView(
                Text("\(opportunity.recentHeadlines.count)").font(DS.Font.mono(11)).foregroundColor(DS.Color.accent)
            )
        ) {
            VStack(spacing: 0) {
                ForEach(Array(opportunity.recentHeadlines.enumerated()), id: \.offset) { i, item in
                    let date = item.count > 0 ? item[0] : ""
                    let headline = item.count > 1 ? item[1] : ""
                    let url = item.count > 2 ? item[2] : ""
                    Button(action: {
                        if let u = URL(string: url) { UIApplication.shared.open(u) }
                    }) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(date).font(DS.Font.mono(11)).foregroundColor(DS.Color.textMuted).frame(width: 45, alignment: .leading)
                            Text(headline).font(.system(size: 13)).foregroundColor(.white).lineSpacing(2).multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundColor(DS.Color.textMuted)
                        }
                        .padding(.horizontal, 13).padding(.vertical, 11)
                        .background(i % 2 == 0 ? Color.clear : DS.Color.card)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border, lineWidth: 0.5))
        }
    }

    // MARK: Sources
    private var sourcesSection: some View {
        ExpandableSection(
            title: "Sources & Evidence",
            badge: AnyView(
                Text("\(opportunity.sources.count)").font(DS.Font.mono(11)).foregroundColor(DS.Color.accent)
            )
        ) {
            VStack(spacing: 0) {
                ForEach(Array(opportunity.sources.enumerated()), id: \.offset) { i, item in
                    let label = item.count > 0 ? item[0] : ""
                    let url = item.count > 1 ? item[1] : ""
                    Button(action: {
                        if let u = URL(string: url) { UIApplication.shared.open(u) }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "link").font(.system(size: 10)).foregroundColor(DS.Color.accent)
                            Text(label).font(.system(size: 13)).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundColor(DS.Color.textMuted)
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .background(i % 2 == 0 ? Color.clear : DS.Color.card)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border, lineWidth: 0.5))
        }
    }

    // MARK: AI Council Debate (redesigned — individual model panels)
    private var councilSection: some View {
        ExpandableSection(
            title: "AI Council Debate",
            defaultOpen: true,
            badge: AnyView(
                HStack(spacing: 4) {
                    let bulls = [opportunity.council.gemini, opportunity.council.deepseek, opportunity.council.cio].filter { $0 == .bull }.count
                    Text("\(bulls)/3 bull").font(DS.Font.mono(11)).foregroundColor(bulls >= 2 ? DS.Color.bull : DS.Color.bear)
                }
            )
        ) {
            VStack(spacing: 14) {
                modelPanel(name: "Gemini", verdict: opportunity.council.gemini, reasoning: opportunity.geminiReasoning, color: opportunity.council.gemini.color)
                modelPanel(name: "DeepSeek", verdict: opportunity.council.deepseek, reasoning: opportunity.deepseekReasoning, color: opportunity.council.deepseek.color)
                modelPanel(name: "CIO Arbiter", verdict: opportunity.council.cio, reasoning: opportunity.cioReasoning, color: DS.Color.accent)
            }
        }
    }

    private func modelPanel(name: String, verdict: Verdict, reasoning: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(color).frame(width: 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(name.uppercased())
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                    VerdictChip(verdict: verdict)
                }
                Text(reasoning)
                    .font(.system(size: 13.5)).foregroundColor(DS.Color.textSecondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 11)
        }
    }

    // MARK: Financials
    private var financialsSection: some View {
        ExpandableSection(title: "Financials") {
            VStack(spacing: 0) {
                ForEach(Array(opportunity.financials.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row[0]).font(.system(size: 13)).foregroundColor(DS.Color.textSecondary)
                        Spacer()
                        Text(row[1]).font(DS.Font.mono(13)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(i % 2 == 0 ? Color.clear : DS.Color.card)
                    if i < opportunity.financials.count - 1 { Divider().background(DS.Color.border) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border, lineWidth: 0.5))
        }
    }

    // MARK: Buy Zones
    private var buyZonesSection: some View {
        ExpandableSection(title: "Buy Zones", defaultOpen: true, badge: isPro ? nil : AnyView(LockBadge())) {
            BuyZoneCards(buyZones: opportunity.buyZones, isLocked: !isPro, onUnlock: onTogglePro, compact: false)
        }
    }

    // MARK: Bear Case
    private var bearCaseSection: some View {
        ExpandableSection(
            title: "Bear Case",
            badge: AnyView(Text("\(opportunity.redFlags.count) flags").font(DS.Font.mono(11)).foregroundColor(DS.Color.bear))
        ) {
            VStack(spacing: 10) {
                ForEach(Array(opportunity.redFlags.enumerated()), id: \.offset) { i, flag in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(DS.Color.bear).frame(width: 5, height: 5).padding(.top, 7)
                        Text(flag).font(.system(size: 14)).foregroundColor(DS.Color.textSecondary).lineSpacing(3)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("INVALIDATION TRIGGER").font(.system(size: 10.5)).foregroundColor(DS.Color.bear).tracking(0.5)
                    Text(opportunity.invalidation).font(.system(size: 13.5)).foregroundColor(.white).lineSpacing(3)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.bear.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Color.bear.opacity(0.22), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Radar Dossier — AEGIS Deep Research
    @ViewBuilder
    private var radarDossierSection: some View {
        // Detection lane badge
        if let lane = opportunity.detectionLane, !lane.isEmpty {
            ExpandableSection(
                title: "Radar Detection",
                defaultOpen: true,
                badge: AnyView(
                    HStack(spacing: 4) {
                        Circle().fill(DS.Color.accent).frame(width: 5, height: 5)
                        Text(lane).font(DS.Font.mono(10)).foregroundColor(DS.Color.accent)
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Detection metadata
                    if let researchedAt = opportunity.researchedAt {
                        HStack(spacing: 6) {
                            Image(systemName: "clock").font(.system(size: 10)).foregroundColor(DS.Color.textMuted)
                            Text("Researched \(formatRadarDate(researchedAt))")
                                .font(DS.Font.mono(11)).foregroundColor(DS.Color.textMuted)
                        }
                    }

                    radarLaneCard(
                        icon: "eye.slash.fill",
                        label: "OVERLOOKED / UNDERFOLLOWED",
                        content: opportunity.overlookedAnalysis,
                        color: DS.Color.tier2
                    )

                    radarLaneCard(
                        icon: "link.circle.fill",
                        label: "INDIRECT BENEFICIARY",
                        content: opportunity.indirectCatalysts,
                        color: DS.Color.accent
                    )

                    radarLaneCard(
                        icon: "person.2.fill",
                        label: "INSIDER ACTIVITY & SMART MONEY",
                        content: opportunity.insiderActivity,
                        color: DS.Color.tier1
                    )

                    radarLaneCard(
                        icon: "building.columns.fill",
                        label: "GOVERNMENT & REGULATORY SUPPORT",
                        content: opportunity.governmentSupport,
                        color: Color(red: 0.5, green: 0.6, blue: 1.0)
                    )

                    // Scoring grid
                    radarScoringGrid
                }
            }
        }

        // Full dossier markdown
        if let dossier = opportunity.radarDossier, !dossier.isEmpty {
            ExpandableSection(
                title: "Full Radar Dossier",
                defaultOpen: false,
                badge: AnyView(
                    Text("AEGIS").font(DS.Font.mono(10)).foregroundColor(DS.Color.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(DS.Color.accent.opacity(0.12))
                        .clipShape(Capsule())
                )
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    if let attr = try? AttributedString(markdown: String(dossier.prefix(8000))) {
                        Text(attr)
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .environment(\.openURL, OpenURLAction { url in
                                UIApplication.shared.open(url)
                                return .handled
                            })
                    } else {
                        Text(String(dossier.prefix(8000)))
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func radarLaneCard(icon: String, label: String, content: String?, color: Color) -> some View {
        Group {
            if let content = content, !content.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle().fill(color).frame(width: 2)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                            Text(label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(color)
                                .tracking(0.4)
                        }
                        Text(content)
                            .font(.system(size: 12.5))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineSpacing(2.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 10)
                }
                .padding(10)
                .background(DS.Color.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var radarScoringGrid: some View {
        VStack(spacing: 0) {
            if opportunity.asymmetryScore > 0 || opportunity.convictionScore > 0
                || opportunity.catalystScore > 0 || opportunity.managementScore > 0 {
                HStack(spacing: 0) {
                    radarScoreCell(label: "Asymmetry", score: opportunity.asymmetryScore, color: DS.Color.tier1)
                    radarScoreCell(label: "Conviction", score: opportunity.convictionScore, color: DS.Color.bull)
                    radarScoreCell(label: "Catalyst", score: opportunity.catalystScore, color: DS.Color.accent)
                    radarScoreCell(label: "Mgmt", score: opportunity.managementScore, color: DS.Color.tier2)
                }
            }
            if let smartMoney = opportunity.smartMoneyScore, let govScore = opportunity.governmentScore {
                HStack(spacing: 0) {
                    radarScoreCell(label: "Smart Money", score: smartMoney, color: Color(red: 1.0, green: 0.75, blue: 0.3))
                    radarScoreCell(label: "Gov Support", score: govScore, color: Color(red: 0.5, green: 0.6, blue: 1.0))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Color.border, lineWidth: 0.5))
    }

    private func radarScoreCell(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8.5)).foregroundColor(DS.Color.textMuted).tracking(0.4)
            Text("\(score)/10")
                .font(DS.Font.mono(14)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DS.Color.card)
    }

    private func formatRadarDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .abbreviated
        return relFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: — Section label helper

private func sectionLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 10.5)).foregroundColor(DS.Color.textMuted).tracking(0.6)
}

// MARK: — Case block (bull/bear, kept for compatibility)

struct CaseBlock: View {
    let verdict: Verdict
    let text: String
    private var color: Color { verdict.color }
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(color).frame(width: 2)
            VStack(alignment: .leading, spacing: 6) {
                VerdictChip(verdict: verdict)
                Text(text).font(.system(size: 14)).foregroundColor(DS.Color.textSecondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 11)
        }
    }
}

// MARK: — Expandable section

struct ExpandableSection: View {
    let title: String
    let defaultOpen: Bool
    let badge: AnyView?
    let content: AnyView
    @State private var isOpen: Bool

    init<C: View>(title: String, defaultOpen: Bool = false, badge: AnyView? = nil, @ViewBuilder content: @escaping () -> C) {
        self.title = title; self.defaultOpen = defaultOpen; self.badge = badge
        self.content = AnyView(content()); self._isOpen = State(initialValue: defaultOpen)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(DS.Color.border)
            Button(action: { withAnimation(.spring(response: 0.28)) { isOpen.toggle() } }) {
                HStack(spacing: 9) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    if let badge { badge }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(DS.Color.textMuted).rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.vertical, 16)
            }
            if isOpen { content.padding(.bottom, 18) }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: Detail metric

private struct DetailMetric: View {
    let label: String; let value: String; var color: Color = .white
    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9.5)).foregroundColor(DS.Color.textMuted).tracking(0.6).textCase(.uppercase)
            Text(value).font(DS.Font.mono(14)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}
