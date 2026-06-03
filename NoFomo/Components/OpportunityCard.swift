import SwiftUI

// MARK: — Opportunity Card (the atomic unit)
// Pixel-matched to No Fomo.html design prototype

struct OpportunityCard: View {
    let opportunity: Opportunity
    var onOpen: () -> Void = {}
    var onUnlock: () -> Void = {}
    var density: CardDensity = .regular
    var gaugeStyle: ScoreGauge.GaugeStyle = .ring
    var isLocked: Bool = true

    enum CardDensity: String, CaseIterable {
        case compact
        case regular
    }

    @State private var isPressed = false

    private var pad: CGFloat { density == .compact ? 14 : 17 }
    private var gap: CGFloat { density == .compact ? 12 : 15 }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: gap) {
                headerRow
                blufText
                metricsStrip
                councilRow
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

    // MARK: Header — tier badge + triple signal left, score gauge right
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // Badge row
                HStack(spacing: 7) {
                    TierBadge(tier: opportunity.tier)
                    if opportunity.tripleSignal {
                        TripleSignalBadge()
                    }
                }

                // Ticker (mono, no $ prefix)
                Text(opportunity.ticker)
                    .font(DS.Font.mono(21))
                    .foregroundColor(.white)

                // Company name
                Text(opportunity.companyName)
                    .font(.system(size: 13))
                    .foregroundColor(DS.Color.textSecondary)

                // Sector
                Text(opportunity.sector)
                    .font(.system(size: 11))
                    .foregroundColor(DS.Color.textMuted)
            }

            Spacer()

            ScoreGauge(
                score: opportunity.score,
                tier: opportunity.tier,
                size: 58,
                style: gaugeStyle
            )
        }
    }

    // MARK: BLUF — bottom line up front
    private var blufText: some View {
        Text(opportunity.bluf)
            .font(.system(size: 14.5))
            .foregroundColor(.white)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Metrics strip — Price | Upside | Mkt Cap | Prob
    private var metricsStrip: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: 0) {
            MetricPill(label: "Price", value: "$\(fmtPrice(opportunity.price))")
            MetricPill(label: "Upside", value: "+\(Int(opportunity.upside))%", color: DS.Color.bull)
            MetricPill(label: "Mkt Cap", value: "$\(opportunity.marketCap)")
            MetricPill(label: "Prob", value: "\(Int(opportunity.probability))%", color: DS.Color.accent)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(DS.Color.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: AI Council row
    private var councilRow: some View {
        AICouncilRow(council: opportunity.council)
    }

    // MARK: Buy zones footer
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

            BuyZoneCards(
                buyZones: opportunity.buyZones,
                isLocked: isLocked,
                onUnlock: onUnlock
            )
        }
    }
}

// MARK: — Metric pill (used in metrics strip)

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

// MARK: — AI Council row (COUNCIL label + 3 model chips)

struct AICouncilRow: View {
    let council: AICouncil

    private var members: [(name: String, verdict: Verdict)] {
        [
            ("Gemini", council.gemini),
            ("DeepSeek", council.deepseek),
            ("CIO", council.cio),
        ]
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
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(color.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: — Buy zone cards (3 levels)

struct BuyZoneCards: View {
    let buyZones: BuyZones
    let isLocked: Bool
    var onUnlock: () -> Void = {}
    var compact: Bool = true

    private var zones: [(label: String, price: Double)] {
        [
            ("Aggressive", buyZones.aggressive),
            ("Base", buyZones.base),
            ("Conservative", buyZones.conservative),
        ]
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(DS.Color.border, lineWidth: 0.5)
                    )
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
                    .background(
                        DS.Color.bull.opacity(0.12)
                            .background(DS.Color.card)
                    )
                    .overlay(
                        Capsule()
                            .stroke(DS.Color.bull.opacity(0.4), lineWidth: 0.5)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: — Formatting helpers

private func fmtPrice(_ n: Double) -> String {
    String(format: "%.2f", n)
    // Note: prototype uses toLocaleString but 2 decimals works for USD
}
