import SwiftUI

// MARK: — Price chart time horizon

enum PriceChartHorizon: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"

    var tradingDays: Int {
        switch self {
        case .oneMonth: return 21
        case .threeMonths: return 63
        case .sixMonths: return 126
        case .oneYear: return 252
        case .all: return Int.max
        }
    }

    var label: String { rawValue }

    var timeLabel: String {
        switch self {
        case .oneMonth: return "Past month"
        case .threeMonths: return "Past 3 months"
        case .sixMonths: return "Past 6 months"
        case .oneYear: return "Past year"
        case .all: return "All data"
        }
    }

    var startLabel: String {
        switch self {
        case .oneMonth: return "1 mo ago"
        case .threeMonths: return "3 mo ago"
        case .sixMonths: return "6 mo ago"
        case .oneYear: return "1 yr ago"
        case .all: return "Earliest"
        }
    }

    var endLabel: String {
        switch self {
        case .all: return "Latest"
        default: return "Now"
        }
    }
}

// MARK: — Detail sheet (matches prototype drawer layout)

struct DetailSheet: View {
    let opportunity: Opportunity
    let isPro: Bool
    var onTogglePro: () -> Void = {}
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var saved = false
    @State private var selectedScore: ScoreDetail? = nil
    @State private var selectedHorizon: PriceChartHorizon = .threeMonths

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    grabber

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            stickyHeader
                            blufSection.padding(.top, 10)
                            priceChartSection          // Price sparkline — visual context
                            // ── SCORING (moved up — this is the signal) ──
                            upsidePotentialSection     // Asymmetry / Conviction / Catalyst / Mgmt
                            // ── UPSIDE ──
                            bullCaseSection            // Why it could 3x+
                            competitiveAdvantagesSection // Moat — why they can pull it off
                            catalystsSection           // Upcoming events that reprice
                            buyZonesSection            // Entry points
                            // ── NEGATIVES ──
                            bearCaseSection            // Risks, bear case + invalidation
                            // ── NEWS ──
                            headlinesSection           // Recent headlines (clickable)
                            // ── DEEP DIVE (collapsed) ──
                            councilSummarySection           // AI debate verdict
                            insiderActivitySection          // Form 4 transactions
                            analystSection                 // Wall Street consensus
                            // ── KEY METRICS (bottom) ──
                            keyMetricsSection              // With contextual explainers
                            financialsSection              // Raw financials table
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
                HStack(alignment: .center, spacing: 12) {
                    TickerLogo(ticker: opportunity.ticker, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(opportunity.ticker)
                                .font(DS.Font.mono(26)).foregroundColor(.white)
                            Text("$\(String(format: "%.2f", opportunity.price))")
                                .font(DS.Font.mono(15)).foregroundColor(DS.Color.textSecondary)
                        }
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+\(Int(opportunity.upside))% upside")
                        .font(DS.Font.mono(15)).foregroundColor(DS.Color.bull)
                    if opportunity.upside > 0 {
                        Text("· potential \(Int(opportunity.upside))% return")
                            .font(.system(size: 12)).foregroundColor(DS.Color.tier1.opacity(0.8))
                    }
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

    // MARK: Price chart with TA overlay + time horizon selector
    private var priceChartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !opportunity.priceHistory.isEmpty {
                Divider().background(DS.Color.border)

                let fullData = opportunity.priceHistory
                let horizonCount = selectedHorizon.tradingDays
                let data = Array(fullData.suffix(min(horizonCount, fullData.count)))
                let dataMin = data.min() ?? 0
                let dataMax = data.max() ?? 1
                let range = max(dataMax - dataMin, 0.01)
                let up = (data.last ?? 0) >= (data.first ?? 0)
                let pctChange = data.first.map { f in ((data.last ?? f) - f) / f * 100 } ?? 0

                // ── Horizon selector row (above chart) ──
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(DS.Color.textMuted)
                        Text(selectedHorizon.timeLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Color.textSecondary)
                    }
                    Spacer()
                    // % change for selected period
                    Text(String(format: "%+.1f%%", pctChange))
                        .font(DS.Font.mono(13))
                        .foregroundColor(pctChange >= 0 ? DS.Color.bull : DS.Color.bear)
                    Spacer()
                    // RSI + MACD mini
                    HStack(spacing: 8) {
                        Text("RSI \(String(format: "%.0f", opportunity.rsiValue))")
                            .font(.system(size: 9)).foregroundColor(opportunity.rsiValue > 70 ? .red : opportunity.rsiValue < 30 ? .green : DS.Color.textMuted)
                        Text("MACD \(opportunity.macdTrend)")
                            .font(.system(size: 9)).foregroundColor(opportunity.macdTrend == "bullish" ? .green : .red)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)

                // ── Chart ──
                VStack(spacing: 2) {
                    HStack {
                        Text("$\(String(format: "%.0f", dataMax))")
                            .font(.system(size: 9)).foregroundColor(DS.Color.textMuted)
                        Spacer()
                    }

                    ZStack {
                        // Grid line at 50%
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 50))
                            path.addLine(to: CGPoint(x: 300, y: 50))
                        }
                        .stroke(Color.white.opacity(0.04), style: StrokeStyle(lineWidth: 0.5))

                        // Support/resistance lines
                        if opportunity.supportLevel > 0 && opportunity.resistanceLevel > 0 {
                            Path { path in
                                let h: CGFloat = 100
                                let y = h * (1 - CGFloat((opportunity.resistanceLevel - dataMin) / range))
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: 300, y: y))
                            }
                            .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4,4]))
                            Path { path in
                                let h: CGFloat = 100
                                let y = h * (1 - CGFloat((opportunity.supportLevel - dataMin) / range))
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: 300, y: y))
                            }
                            .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4,4]))
                        }

                        // Price line
                        GeometryReader { geo in
                            // Gradient fill below line
                            Path { path in
                                guard data.count > 1 else { return }
                                let w = geo.size.width / CGFloat(data.count - 1)
                                for i in 0..<data.count {
                                    let x = CGFloat(i) * w
                                    let y = CGFloat((dataMax - data[i]) / range) * geo.size.height
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (up ? DS.Color.bull : DS.Color.bear).opacity(0.10),
                                        (up ? DS.Color.bull : DS.Color.bear).opacity(0.0),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                            // Price line stroke
                            Path { path in
                                guard data.count > 1 else { return }
                                let w = geo.size.width / CGFloat(data.count - 1)
                                for i in 0..<data.count {
                                    let x = CGFloat(i) * w
                                    let y = CGFloat((dataMax - data[i]) / range) * geo.size.height
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(
                                up ? DS.Color.bull : DS.Color.bear,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .frame(height: 100)

                    HStack {
                        Text("$\(String(format: "%.0f", dataMin))")
                            .font(.system(size: 9)).foregroundColor(DS.Color.textMuted)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)

                // ── X-axis time markers ──
                HStack(spacing: 0) {
                    Text(selectedHorizon.startLabel)
                        .font(.system(size: 8)).foregroundColor(DS.Color.textMuted)
                    Spacer()
                    Text(selectedHorizon.endLabel)
                        .font(.system(size: 8)).foregroundColor(DS.Color.textMuted)
                }
                .padding(.horizontal, 20).padding(.top, 2)

                // ── Horizon selector chips ──
                HStack(spacing: 8) {
                    ForEach(PriceChartHorizon.allCases, id: \.self) { horizon in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedHorizon = horizon
                            }
                        }) {
                            Text(horizon.label)
                                .font(.system(size: 12, weight: selectedHorizon == horizon ? .bold : .medium))
                                .foregroundColor(selectedHorizon == horizon ? .white : DS.Color.textMuted)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(
                                    selectedHorizon == horizon
                                        ? DS.Color.accent
                                        : DS.Color.elevated
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
        }
    }

    // MARK: Council Summary (AI debate verdict)
    private var councilSummarySection: some View {
        let summary = opportunity.councilSummary ?? ""
        if summary.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Divider().background(DS.Color.border)
                sectionLabel("AI COUNCIL DEBATE")
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        )
    }

    // MARK: Headlines (2-3 clickable)
    private var headlinesSection: some View {
        let items = opportunity.recentHeadlines.filter { $0.count >= 2 && !$0[0].isEmpty }
        if items.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Divider().background(DS.Color.border)
                sectionLabel("RECENT HEADLINES")
                ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                    Button(action: {
                        if let url = URL(string: item[1]) { UIApplication.shared.open(url) }
                    }) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "link").font(.system(size: 10)).foregroundColor(DS.Color.accent).padding(.top, 3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item[0]).font(.system(size: 13, weight: .medium)).foregroundColor(.white).lineLimit(2)
                                Text("\(item[2]) · \(item[3])").font(.system(size: 10)).foregroundColor(DS.Color.textMuted)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)
        )
    }

    // MARK: Catalysts (2-3 upcoming events)
    private var catalystsSection: some View {
        let items = opportunity.upcomingEvents.filter { $0.count >= 2 && !$0[0].isEmpty }
        if items.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Divider().background(DS.Color.border)
                sectionLabel("UPCOMING")
                ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Circle().fill(DS.Color.tier1).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item[1]).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                            Text(item[2]).font(.system(size: 11)).foregroundColor(DS.Color.textSecondary).lineLimit(2)
                            if item.count > 0 { Text(item[0]).font(.system(size: 10)).foregroundColor(DS.Color.textMuted) }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)
        )
    }

    // MARK: Happening Now
    private var happeningNowSection: some View {
        let isMarketOpen = abs(opportunity.priceChangePct) > 0.01
        return VStack(alignment: .leading, spacing: 10) {
            Divider().background(DS.Color.border)
            sectionLabel("HAPPENING NOW")
            if isMarketOpen {
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
            } else {
                Text("Market Closed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
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

    // MARK: Bull Case — always visible
    private var bullCaseSection: some View {
        let items = opportunity.bullCaseItems
        let paragraph = opportunity.bullCase
        let hasItems = !items.isEmpty
        let hasText = !paragraph.isEmpty

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Divider().background(DS.Color.border)
                HStack(spacing: 9) {
                    Text("Bull Case")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text(hasItems ? "\(items.count) drivers" : "thesis")
                        .font(DS.Font.mono(11)).foregroundColor(DS.Color.tier1)
                    Spacer()
                }
                .padding(.vertical, 16)

                if hasItems {
                    // Structured bullet points from radar research
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { i, flag in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(DS.Color.tier1).frame(width: 5, height: 5).padding(.top, 7)
                                Text(cleanSentence(flag))
                                    .font(.system(size: 14)).foregroundColor(DS.Color.textSecondary).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else if hasText {
                    // Paragraph bull case — display as-is, no sentence splitting
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(DS.Color.tier1).frame(width: 2)
                        Text(paragraph)
                            .font(.system(size: 14))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 11)
                    }
                }
            }
            .padding(.horizontal, 20)
        )
    }

    // MARK: Risks & Bear Case — always visible, merged
    private var bearCaseSection: some View {
        let riskText = opportunity.investmentRisks ?? ""
        return VStack(alignment: .leading, spacing: 0) {
            Divider().background(DS.Color.border)
            HStack(spacing: 9) {
                Text("Risks & Bear Case")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text("\(opportunity.redFlags.count) flags")
                    .font(DS.Font.mono(11)).foregroundColor(DS.Color.bear)
                Spacer()
            }
            .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 10) {
                // Red flags — scannable bullets
                ForEach(Array(opportunity.redFlags.enumerated()), id: \.offset) { i, flag in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(DS.Color.bear).frame(width: 5, height: 5).padding(.top, 7)
                        Text(flag).font(.system(size: 14)).foregroundColor(DS.Color.textSecondary).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Investment risks — deeper analysis
                if !riskText.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(DS.Color.bear.opacity(0.5)).frame(width: 2)
                        Text(riskText)
                            .font(.system(size: 13.5))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 11)
                    }
                    .padding(.top, 6)
                }

                // Invalidation trigger — what breaks the thesis
                VStack(alignment: .leading, spacing: 5) {
                    Text("WHAT BREAKS THE THESIS").font(.system(size: 10.5)).foregroundColor(DS.Color.bear).tracking(0.5)
                    Text(opportunity.invalidation).font(.system(size: 13.5)).foregroundColor(.white).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.bear.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Color.bear.opacity(0.22), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 20)
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

    private func cleanSentence(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip leading bullet markers: "•", "-", "1.", "1)", etc.
        while s.hasPrefix("-") || s.hasPrefix("•") || s.hasPrefix("*") {
            s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        if let firstChar = s.first, firstChar.isNumber {
            if let dotIdx = s.firstIndex(of: "."), dotIdx < s.index(s.startIndex, offsetBy: 3) {
                s = String(s[s.index(after: dotIdx)...]).trimmingCharacters(in: .whitespaces)
            } else if let parenIdx = s.firstIndex(of: ")"), parenIdx < s.index(s.startIndex, offsetBy: 3) {
                s = String(s[s.index(after: parenIdx)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        guard !s.isEmpty else { return "" }
        // Capitalize first letter
        s = s.prefix(1).uppercased() + s.dropFirst()
        // Ensure ends with period
        if !s.hasSuffix(".") && !s.hasSuffix("!") && !s.hasSuffix("?") {
            s += "."
        }
        return s
    }

    private func formatRadarDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .abbreviated
        return relFormatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: — Competitive Landscape (always visible — moat, edge, risks vs peers)
    private var competitiveAdvantagesSection: some View {
        let moatText = opportunity.competitiveAdvantages ?? ""
        let riskText = opportunity.investmentRisks ?? ""
        // Extract competitive edge from bull case if no dedicated moat text
        let edgeFromBull: String = {
            guard moatText.isEmpty else { return "" }
            let bull = opportunity.bullCase
            guard !bull.isEmpty else { return "" }
            // Grab first 2-3 sentences as the competitive thesis
            let sentences = bull
                .components(separatedBy: ". ")
                .filter { !$0.isEmpty }
                .prefix(3)
            guard !sentences.isEmpty else { return "" }
            return sentences.joined(separator: ". ") + "."
        }()

        // Nothing to show at all
        if moatText.isEmpty && edgeFromBull.isEmpty && riskText.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Divider().background(DS.Color.border)
                HStack(spacing: 9) {
                    Image(systemName: "shield.checkered").font(.system(size: 11)).foregroundColor(DS.Color.tier1)
                    Text("Competitive Landscape")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 16)

                // ── Moat / Edge ──
                if !moatText.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(DS.Color.tier1).frame(width: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MOAT & EDGE")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(DS.Color.tier1)
                                .tracking(0.5)
                            Text(moatText)
                                .font(.system(size: 13.5))
                                .foregroundColor(DS.Color.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 11)
                    }
                } else if !edgeFromBull.isEmpty {
                    // Fallback: synthesize edge from bull case
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(DS.Color.tier1).frame(width: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WHAT THEY BRING TO THE TABLE")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(DS.Color.tier1)
                                .tracking(0.5)
                            Text(edgeFromBull)
                                .font(.system(size: 13.5))
                                .foregroundColor(DS.Color.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 11)
                    }
                }

                // ── Competitive Risks ──
                if !riskText.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(DS.Color.bear.opacity(0.6)).frame(width: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COMPETITIVE RISKS")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(DS.Color.bear)
                                .tracking(0.5)
                            Text(riskText)
                                .font(.system(size: 13.5))
                                .foregroundColor(DS.Color.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 11)
                    }
                    .padding(.top, (!moatText.isEmpty || !edgeFromBull.isEmpty) ? 16 : 0)
                }
            }
            .padding(.horizontal, 20)
        )
    }

    // MARK: — Key Metrics with ? explainers
    private var keyMetricsSection: some View {
        let km = opportunity.keyMetrics
        let fin = opportunity.financials
        // Show if we have keyMetrics or financials
        let hasKeyMetrics = km != nil && ((km?.revenue?.isEmpty == false) || (km?.eps?.isEmpty == false))
        let hasFinancials = !fin.isEmpty
        if !hasKeyMetrics && !hasFinancials { return AnyView(EmptyView()) }

        return AnyView(
            ExpandableSection(
                title: "Key Metrics",
                defaultOpen: true,
                badge: AnyView(
                    Text("?").font(.system(size: 11, weight: .bold))
                        .foregroundColor(DS.Color.accent)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(DS.Color.accent.opacity(0.12)))
                )
            ) {
                VStack(spacing: 0) {
                    // Dedicated key metrics with explainers
                    if let km = km {
                        metricRow("Revenue", km.revenue, explainer: "How much money the company brought in last year. Growing fast = demand is strong. Shrinking = losing customers or cutting prices.")
                        metricRow("Net Income", km.netIncome, explainer: "What's left after paying everyone — employees, suppliers, taxes. The actual profit. If this is positive, the business pays for itself. If negative, they're burning cash.")
                        metricRow("EPS", km.eps, explainer: "Your share of the profit. Each share you own represents this much earnings. If EPS grows 30% a year, the stock price should follow — unless something breaks the story.")
                        metricRow("P/E (Trailing)", km.peTrailing, explainer: "How many dollars you're paying for $1 of last year's profit. A typical company trades at 20-25x. Anything above 50x means investors expect earnings to grow several times over before this price makes sense. The bet: growth will catch up to the price before the music stops.")
                        metricRow("P/E (Forward)", km.peForward, explainer: "What you're paying for NEXT year's expected profit. If forward P/E is much lower than trailing, earnings are expected to jump significantly. Still high? The market is pricing in years of explosive growth — execution has to be nearly perfect.")
                        metricRow("EV/EBITDA", km.evEbitda, explainer: "The company's total price tag (including debt) divided by its operating profit. The S&P 500 averages ~15x. A high number like 50x+ means you're paying for a future that hasn't happened yet — the business needs to grow into this valuation over many years.")
                        metricRow("Gross Margin", km.grossMargin, explainer: "For every $100 of sales, how much is left after making the product. Software companies typically run 70-85% — that's excellent. Below 30% suggests a low-margin business (retail, manufacturing) where profits can be squeezed easily.")
                        metricRow("Operating Margin", km.operatingMargin, explainer: "After paying for the product AND running the business (offices, salaries, sales), what % is profit. Above 20% is strong — the business has real operating leverage. Below 10% means thin margins where a small cost increase can wipe out profits.")
                        metricRow("Cash", km.cashAndEquivalents, explainer: "Money in the bank. Companies with lots of cash can survive downturns, acquire competitors, or buy back stock. Companies with little cash are one bad quarter away from needing to raise money — which usually means diluting your shares.")
                        metricRow("Total Debt", km.totalDebt, explainer: "Money the company owes. Zero debt means no interest payments eating profits and no risk of default. High debt is fine IF revenue is growing faster than interest costs. High debt + shrinking revenue = a potential death spiral.")
                        metricRow("Dividend Yield", km.dividendYield, explainer: "How much cash you get paid each year just for holding. 0% means every dollar of profit goes back into growing the business — common for fast-growing companies. 3%+ is more typical of mature, slower-growing businesses returning cash to shareholders.")
                    }
                    // Fallback: existing financials array
                    if hasFinancials {
                        ForEach(Array(fin.enumerated()), id: \.offset) { i, row in
                            HStack {
                                Text(row[0]).font(.system(size: 13)).foregroundColor(DS.Color.textSecondary)
                                Spacer()
                                Text(row[1]).font(DS.Font.mono(13)).foregroundColor(.white)
                            }
                            .padding(.horizontal, 13).padding(.vertical, 11)
                            .background(i % 2 == 0 ? Color.clear : DS.Color.card)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border, lineWidth: 0.5))
            }
        )
    }

    private func metricRow(_ label: String, _ value: String?, explainer: String) -> some View {
        guard let value = value, !value.isEmpty, value != "N/A" else { return AnyView(EmptyView()) }
        return AnyView(
            MetricRow(label: label, value: value, explainer: explainer)
        )
    }

    // MARK: — Upside Potential (lead with this)
    private var upsidePotentialSection: some View {
        let hasCoreScores = opportunity.asymmetryScore > 0 || opportunity.convictionScore > 0
            || opportunity.catalystScore > 0 || opportunity.managementScore > 0
        let sms = opportunity.smartMoneyScore ?? 0
        let gs = opportunity.governmentScore ?? 0
        let hasExtraScores = sms > 0 || gs > 0

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Divider().background(DS.Color.border)
                sectionLabel("UPSIDE ASYMMETRY — TAP FOR DETAILS")
                if !hasCoreScores {
                    // No scores populated yet — show pending state
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass").font(.system(size: 11)).foregroundColor(DS.Color.textMuted)
                        Text("Scores pending — radar analysis in progress")
                            .font(.system(size: 12)).foregroundColor(DS.Color.textMuted)
                    }
                    .padding(.vertical, 8)
                } else {
                    HStack(spacing: 0) {
                        scoreBlock(label: "Asymmetry", score: opportunity.asymmetryScore, color: DS.Color.tier1,
                            detail: "Reward vs Risk\n\nHow lopsided is the upside compared to the downside? A score of 8+ means the potential gain is several times larger than what you could lose. This is the single most important number — it answers 'is this bet worth taking?'\n\n\(opportunity.aiSynopsis.prefix(200))")
                        scoreBlock(label: "Conviction", score: opportunity.convictionScore, color: DS.Color.bull,
                            detail: "Evidence Quality\n\nHow much hard data backs this thesis? A 8+ means multiple primary sources (SEC filings, contracts, insider trades) all point the same way. Below 5 means the story sounds good but lacks proof. The AI council's disagreement level also factors in — more disagreement = lower conviction.\n\nAI Council: \(opportunity.council.gemini == .bull ? "Gemini says buy" : "Gemini says sell"), \(opportunity.council.deepseek == .bull ? "DeepSeek says buy" : "DeepSeek says sell"), \(opportunity.council.cio == .bull ? "CIO says buy" : "CIO says sell")")
                        scoreBlock(label: "Catalyst", score: opportunity.catalystScore, color: DS.Color.accent,
                            detail: "Catalyst Strength\n\nHow soon and how certain is the event that could reprice this stock? A 8+ means a concrete, dated catalyst within 6 months (FDA decision, earnings inflection, contract award). Below 5 means the thesis is real but the timing is vague — could take years to play out.\n\nKey catalyst: \(opportunity.catalyst)")
                        scoreBlock(label: "Mgmt", score: opportunity.managementScore, color: DS.Color.tier2,
                            detail: "Management Quality\n\nDo the people running this company have a track record of success? Are they aligned with shareholders (own lots of stock)? Do they allocate capital wisely or waste it on empire-building? Founder-led companies with skin in the game typically score higher.\n\nInsider signal: \(opportunity.insiderSignal)")
                    }
                }
                // Always show Smart Money + Gov row if either has data, or show it anyway for unscored stocks
                HStack(spacing: 0) {
                    scoreBlock(label: "Smart Money", score: sms, color: Color(red: 1.0, green: 0.75, blue: 0.3),
                        detail: "Smart Money Signal\n\nAre insiders buying? Are top funds accumulating? Congress members trading? This measures whether the people with the best information are betting their own money on this outcome.\n\nInsider buys: \(opportunity.insiderTotalBuys) | Sells: \(opportunity.insiderTotalSells)")
                    scoreBlock(label: "Gov", score: gs, color: Color(red: 0.5, green: 0.6, blue: 1.0),
                        detail: "Government Support\n\nFederal contracts, grants, regulatory approvals, or policy tailwinds. A 8+ means the government is effectively a customer or partner. Defense, energy, and healthcare companies often score highest here.\n\n\(opportunity.governmentSupport?.prefix(200) ?? "No government data available")")
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)
        )
    }

    private func scoreBlock(label: String, score: Int, color: Color, detail: String) -> some View {
        Button(action: { selectedScore = ScoreDetail(scoreKey: label, content: detail) }) {
            VStack(spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 8.5)).foregroundColor(DS.Color.textMuted).tracking(0.4)
                Text("\(score)/10")
                    .font(DS.Font.mono(16)).foregroundColor(color)
                GeometryReader { geo in
                    Capsule()
                        .fill(color.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * CGFloat(score) / 10)
                        }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10).padding(.horizontal, 6)
            .background(DS.Color.card)
        }
        .buttonStyle(.plain)
        .sheet(item: $selectedScore) { detail in
            ScoreDetailView(detail: detail)
        }
    }

    // MARK: — Insider Activity (Form 4 moves)
    private var insiderActivitySection: some View {
        if opportunity.insiderTotalBuys == 0 && opportunity.insiderTotalSells == 0
            && opportunity.insiderSignal.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            ExpandableSection(
                title: "Insider Moves",
                badge: AnyView(
                    HStack(spacing: 4) {
                        let sentiment = opportunity.insiderNetSentiment
                        Circle().fill(sentiment == "bullish" ? DS.Color.bull : sentiment == "bearish" ? DS.Color.bear : DS.Color.textMuted).frame(width: 6, height: 6)
                        Text(sentiment.uppercased())
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(sentiment == "bullish" ? DS.Color.bull : sentiment == "bearish" ? DS.Color.bear : DS.Color.textMuted)
                    }
                )
            ) {
                VStack(spacing: 12) {
                    // Signal summary
                    if !opportunity.insiderSignal.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: opportunity.insiderNetSentiment == "bullish" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(opportunity.insiderNetSentiment == "bullish" ? DS.Color.bull : DS.Color.bear)
                            Text(opportunity.insiderSignal)
                                .font(.system(size: 13)).foregroundColor(.white).lineSpacing(3)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.elevated).clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Buy/Sell summary
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("\(opportunity.insiderTotalBuys) BUYS")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(DS.Color.bull)
                            Text("\(opportunity.insiderBuyVolume.formatted()) shares")
                                .font(DS.Font.mono(10)).foregroundColor(DS.Color.textMuted)
                            if !opportunity.insiderBuyingNames.isEmpty {
                                Text(opportunity.insiderBuyingNames.prefix(2).joined(separator: ", "))
                                    .font(.system(size: 9)).foregroundColor(DS.Color.textSecondary).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Divider().frame(height: 30).background(DS.Color.border)
                        VStack(spacing: 4) {
                            Text("\(opportunity.insiderTotalSells) SELLS")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(DS.Color.bear)
                            Text("\(opportunity.insiderSellVolume.formatted()) shares")
                                .font(DS.Font.mono(10)).foregroundColor(DS.Color.textMuted)
                            if !opportunity.insiderSellingNames.isEmpty {
                                Text(opportunity.insiderSellingNames.prefix(2).joined(separator: ", "))
                                    .font(.system(size: 9)).foregroundColor(DS.Color.textSecondary).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(8)
                    .background(DS.Color.elevated).clipShape(RoundedRectangle(cornerRadius: 8))

                    // Cluster score
                    if opportunity.insiderClusterScore >= 4 {
                        HStack {
                            Text("CLUSTER SCORE")
                                .font(.system(size: 9.5)).foregroundColor(DS.Color.textMuted).tracking(0.5)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<10, id: \.self) { i in
                                    Capsule().fill(i < opportunity.insiderClusterScore ? DS.Color.tier1 : DS.Color.border)
                                        .frame(width: 8, height: 4)
                                }
                            }
                            Text("\(opportunity.insiderClusterScore)/10")
                                .font(DS.Font.mono(12)).foregroundColor(DS.Color.tier1)
                        }
                    }

                    // Recent transactions
                    if !opportunity.insiderTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RECENT FORM 4 FILINGS")
                                .font(.system(size: 9.5)).foregroundColor(DS.Color.textMuted).tracking(0.5)
                            ForEach(Array(opportunity.insiderTransactions.prefix(5).enumerated()), id: \.offset) { _, tx in
                                let name = tx.count > 0 ? tx[0] : ""
                                let role = tx.count > 1 ? tx[1] : ""
                                let action = tx.count > 2 ? tx[2] : ""
                                let shares = tx.count > 3 ? tx[3] : ""
                                let price = tx.count > 4 ? tx[4] : ""
                                let date = tx.count > 5 ? tx[5] : ""
                                HStack(spacing: 8) {
                                    Text(date).font(DS.Font.mono(10)).foregroundColor(DS.Color.textMuted).frame(width: 52, alignment: .leading)
                                    Text(name).font(.system(size: 11, weight: .medium)).foregroundColor(.white).lineLimit(1)
                                    Text(role).font(.system(size: 9)).foregroundColor(DS.Color.textMuted)
                                    Spacer()
                                    Text("\(action) \(shares)")
                                        .font(DS.Font.mono(10))
                                        .foregroundColor(action == "P" ? DS.Color.bull : action == "S" ? DS.Color.bear : DS.Color.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        )
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

// MARK: - Metric row with contextual explainer

private struct MetricRow: View {
    let label: String
    let value: String
    let explainer: String
    @State private var showExplainer = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showExplainer.toggle() } }) {
                HStack {
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.textSecondary)
                        Text("?")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DS.Color.accent)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(DS.Color.accent.opacity(0.15)))
                    }
                    Spacer()
                    Text(value)
                        .font(DS.Font.mono(13))
                        .foregroundColor(.white)
                    Image(systemName: showExplainer ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(DS.Color.textMuted)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 13).padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if showExplainer {
                Text(explainer)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.accent.opacity(0.06))
            }
        }
    }
}

// MARK: - Score Detail (for popup explainers)

struct ScoreDetail: Identifiable {
    let id = UUID()
    let scoreKey: String
    let content: String
}

struct ScoreDetailView: View {
    let detail: ScoreDetail

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Circle().fill(colorForScoreKey(detail.scoreKey)).frame(width: 10, height: 10)
                        Text(detail.scoreKey.uppercased())
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    }
                    Text(detail.content)
                        .font(.system(size: 15))
                        .foregroundColor(DS.Color.textSecondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }
            .background(DS.Color.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DS.Color.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @Environment(\.dismiss) private var dismiss

    private func colorForScoreKey(_ key: String) -> Color {
        switch key {
        case "Asymmetry": return DS.Color.tier1
        case "Conviction": return DS.Color.bull
        case "Catalyst": return DS.Color.accent
        case "Mgmt": return DS.Color.tier2
        case "Smart Money": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "Gov": return Color(red: 0.5, green: 0.6, blue: 1.0)
        default: return DS.Color.textSecondary
        }
    }
}
