import SwiftUI

struct OpportunityCard: View {
    let opportunity: Opportunity
    var onOpen: () -> Void = {}
    var onUnlock: () -> Void = {}
    var onBookmark: ((Opportunity) -> Void)? = nil
    var density: CardDensity = .regular
    var gaugeStyle: ScoreGauge.GaugeStyle = .ring
    var isLocked: Bool = true

    enum CardDensity: String, CaseIterable {
        case compact
        case regular
    }

    @State private var isPressed = false
    @State private var isBookmarked = false
    @State private var showScoreTooltip = false
    @State private var showBLUFTooltip = false
    @State private var showTripleTooltip = false

    private var pad: CGFloat { density == .compact ? 14 : 17 }
    private var gap: CGFloat { density == .compact ? 12 : 15 }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: gap) {
                headerRow
                blufText
                notificationSubline
                happeningNowSection
                upcomingCompact
                metricsStrip
                radarFreshnessLine
                AICouncilRow(council: opportunity.council)
                buyZonesFooter
            }
            .padding(pad)
            .background(DS.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusCard))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusCard)
                    .stroke(DS.Color.border, lineWidth: 0.5)
            )
            .scaleEffect(isPressed ? 0.992 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.12)) { isPressed = pressing }
        }, perform: {})
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    TierBadge(tier: opportunity.tier)
                    if opportunity.tripleSignal {
                        TripleSignalBadge()
                        Button { showTripleTooltip = true } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textMuted)
                        }
                        .popover(isPresented: $showTripleTooltip) {
                            Text("Triple Signal — three independent indicators fired simultaneously: insider buying, analyst divergence, and a near-term catalyst. Rare and high-conviction.")
                                .font(DS.Font.caption())
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(maxWidth: 220)
                                .background(DS.Color.elevated)
                        }
                    }
                    if let lane = opportunity.detectionLane, !lane.isEmpty {
                        RadarDetectionBadge(lane: lane)
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    TickerLogo(ticker: opportunity.ticker, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(opportunity.ticker)
                            .font(DS.Font.mono(21))
                            .foregroundColor(.white)
                        Text(opportunity.companyName)
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.textSecondary)
                    }
                }

                Text(opportunity.sector)
                    .font(.system(size: 11))
                    .foregroundColor(DS.Color.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    isBookmarked.toggle()
                    onBookmark?(opportunity)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15))
                        .foregroundColor(isBookmarked ? DS.Color.tier1 : DS.Color.textMuted)
                }
                .buttonStyle(PlainButtonStyle())

                HStack(spacing: 4) {
                    Button { showScoreTooltip = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Color.textMuted)
                    }
                    .popover(isPresented: $showScoreTooltip) {
                        Text("Conviction Score — how strongly the AI council backs this idea, 0–100. 75+ = high conviction.")
                            .font(DS.Font.caption())
                            .foregroundColor(.white)
                            .padding(12)
                            .frame(maxWidth: 220)
                            .background(DS.Color.elevated)
                    }

                    ScoreGauge(
                        score: opportunity.score,
                        tier: opportunity.tier,
                        size: 58,
                        style: gaugeStyle
                    )
                }

                if let label = opportunity.confidenceLabel {
                    ConfidenceDot(label: label)
                }
            }
        }
    }

    private var blufText: some View {
        HStack(alignment: .top, spacing: 5) {
            Text(opportunity.bluf)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button { showBLUFTooltip = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Color.textMuted)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showBLUFTooltip) {
                Text("BLUF — Bottom Line Up Front. The single most important thing to know about this opportunity.")
                    .font(DS.Font.caption())
                    .foregroundColor(.white)
                    .padding(12)
                    .frame(maxWidth: 220)
                    .background(DS.Color.elevated)
            }
        }
    }

    private var notificationSubline: some View {
        Group {
            if !opportunity.notificationLine.isEmpty {
                Text(opportunity.notificationLine)
                    .font(.system(size: 11.5))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.elevated)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(DS.Color.border, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    @ViewBuilder
    private var happeningNowSection: some View {
        if !opportunity.aiSynopsis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("HAPPENING NOW")
                    .font(.system(size: 10.5))
                    .foregroundColor(DS.Color.textMuted)
                    .tracking(0.6)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(opportunity.priceChangePct >= 0 ? "▲" : "▼")
                            .font(.system(size: 10))
                        Text(String(format: "%+.1f%%", opportunity.priceChangePct))
                            .font(DS.Font.mono(12))
                    }
                    .foregroundColor(
                        opportunity.priceChangePct >= 0
                            ? DS.Color.bull
                            : DS.Color.bear
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (opportunity.priceChangePct >= 0
                            ? DS.Color.bull
                            : DS.Color.bear
                        ).opacity(0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                (opportunity.priceChangePct >= 0
                                    ? DS.Color.bull
                                    : DS.Color.bear
                                ).opacity(0.3),
                                lineWidth: 0.5
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    Text(opportunity.taSummary)
                        .font(DS.Font.mono(11))
                        .foregroundColor(DS.Color.textSecondary)
                        .lineLimit(1)
                }

                let synopsisText = (try? AttributedString(markdown: opportunity.aiSynopsis))
                    .map { Text($0) } ?? Text(opportunity.aiSynopsis)
                synopsisText
                    .font(DS.Font.body(14))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in
                        UIApplication.shared.open(url); return .handled
                    })
            }
        }
    }

    private var upcomingCompact: some View {
        Group {
            if !opportunity.upcomingEvents.isEmpty {
                let next = opportunity.upcomingEvents.prefix(2)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(next), id: \.self) { event in
                        let date = event.count > 0 ? event[0] : ""
                        let desc = event.count > 1 ? event[1] : ""
                        let type = event.count > 2 ? event[2] : ""
                        HStack(spacing: 7) {
                            Text(date.uppercased())
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(type == "earnings" ? DS.Color.tier1 : type == "sector" ? DS.Color.accent : DS.Color.tier2)
                            Text(desc)
                                .font(.system(size: 12))
                                .foregroundColor(DS.Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var metricsStrip: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: opportunity.repriceGap?.expectedDriftRemainingPct == nil ? 4 : 5), spacing: 0) {
            MetricPill(label: "Price", value: "$\(fmtPrice(opportunity.price))")
            MetricPill(label: "Upside", value: "+\(Int(opportunity.upside))%", color: DS.Color.bull)
            MetricPill(label: "Mkt Cap", value: "$\(opportunity.marketCap)")
            MetricPill(label: "Prob", value: "\(Int(opportunity.probability))%", color: DS.Color.accent)
            if let gap = opportunity.repriceGap?.expectedDriftRemainingPct {
                MetricPill(label: "Gap", value: "\(gap >= 0 ? "+" : "")\(Int(gap))%", color: DS.Color.tier1)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(DS.Color.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var radarFreshnessLine: some View {
        if let lane = opportunity.detectionLane, !lane.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 9))
                    .foregroundColor(DS.Color.accent)
                Text("RADAR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(DS.Color.accent)
                    .tracking(0.6)
                if let researchedAt = opportunity.researchedAt {
                    Text("·")
                        .foregroundColor(DS.Color.textMuted)
                    Text(formatRelativeDate(researchedAt))
                        .font(DS.Font.mono(10))
                        .foregroundColor(DS.Color.textMuted)
                }
                Spacer()
                Text(lane)
                    .font(.system(size: 9))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.Color.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        if !opportunity.regimeFlags.isEmpty {
            HStack(spacing: 6) {
                ForEach(opportunity.regimeFlags.prefix(3), id: \.self) { flag in
                    Text(flag.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DS.Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.Color.elevated)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func formatRelativeDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    private var buyZonesFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BUY ZONES")
                    .font(.system(size: 10.5))
                    .foregroundColor(DS.Color.textMuted)
                    .tracking(0.6)
                Spacer()
                Text("Open brief →")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Color.textSecondary)
            }

            BuyZoneCards(buyZones: opportunity.buyZones, isLocked: isLocked, onUnlock: onUnlock)
        }
    }
}

// MARK: — Supporting views

private struct MetricPill: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9.5))
                .foregroundColor(DS.Color.textMuted)
                .tracking(0.6)
                .textCase(.uppercase)
            Text(value)
                .font(DS.Font.mono(14))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AICouncilRow: View {
    let council: AICouncil

    private var members: [(name: String, verdict: Verdict)] {
        [("Gemini", council.gemini), ("DeepSeek", council.deepseek), ("CIO", council.cio)]
    }

    var body: some View {
        HStack(spacing: 7) {
            Text("COUNCIL")
                .font(.system(size: 10.5))
                .foregroundColor(DS.Color.textMuted)
                .tracking(0.6)

            HStack(spacing: 6) {
                ForEach(members, id: \.name) { member in
                    CouncilChip(name: member.name, verdict: member.verdict)
                }
            }
        }
    }
}

struct CouncilChip: View {
    let name: String
    let verdict: Verdict

    private var color: Color { verdict.color }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(DS.Color.elevated)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.22), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct BuyZoneCards: View {
    let buyZones: BuyZones
    let isLocked: Bool
    var onUnlock: () -> Void = {}
    var compact: Bool = true

    private var zones: [(label: String, price: Double)] {
        [("Aggressive", buyZones.aggressive), ("Base", buyZones.base), ("Conservative", buyZones.conservative)]
    }

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(zones, id: \.label) { zone in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(zone.label)
                            .font(.system(size: 9.5))
                            .foregroundColor(DS.Color.textMuted)
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text("$\(fmtPrice(zone.price))")
                            .font(DS.Font.mono(compact ? 13 : 15))
                            .foregroundColor(.white)
                    }
                    .padding(compact ? 10 : 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.elevated)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(DS.Color.border, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
            .blur(radius: isLocked ? 7 : 0)
            .opacity(isLocked ? 0.55 : 1.0)

            if isLocked {
                Button(action: onUnlock) {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 11))
                        Text("Unlock buy zones")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(DS.Color.bull)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(DS.Color.bull.opacity(0.12).background(DS.Color.card))
                    .overlay(Capsule().stroke(DS.Color.bull.opacity(0.4), lineWidth: 0.5))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

struct RadarDetectionBadge: View {
    let lane: String

    private var color: Color {
        if lane.lowercased().contains("insider") { return DS.Color.tier1 }
        if lane.lowercased().contains("government") || lane.lowercased().contains("regulatory") { return Color(red: 0.5, green: 0.6, blue: 1.0) }
        if lane.lowercased().contains("indirect") || lane.lowercased().contains("beneficiary") { return DS.Color.accent }
        if lane.lowercased().contains("overlook") || lane.lowercased().contains("underfollow") { return DS.Color.tier2 }
        return DS.Color.accent
    }

    private var icon: String {
        if lane.lowercased().contains("insider") { return "person.2.fill" }
        if lane.lowercased().contains("government") || lane.lowercased().contains("regulatory") { return "building.columns.fill" }
        if lane.lowercased().contains("indirect") || lane.lowercased().contains("beneficiary") { return "link.circle.fill" }
        if lane.lowercased().contains("overlook") || lane.lowercased().contains("underfollow") { return "eye.fill" }
        return "antenna.radiowaves.left.and.right"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7))
            Text(lane.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.5)
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 5)
        .frame(height: 16)
        .background(color.opacity(0.12))
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
        .clipShape(Capsule())
    }
}

struct ConfidenceDot: View {
    let label: String

    private var dotColor: Color {
        switch label {
        case "high": return .green
        case "medium": return .yellow
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundColor(dotColor)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(dotColor)
                .tracking(0.4)
        }
    }
}

private func fmtPrice(_ n: Double) -> String {
    String(format: "%.2f", n)
}
