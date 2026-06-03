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
                    // Grabber
                    grabber

                    // Scrollable body
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            stickyHeader
                            blufSection
                                .padding(.top, 10)
                            metricsSection
                                .padding(.top, 12)

                            // Expandable sections
                            councilSection
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
            Divider()
                .background(DS.Color.border)
                .opacity(0)
        }
    }

    // MARK: Sticky header
    private var stickyHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                // Badge row
                HStack(spacing: 7) {
                    TierBadge(tier: opportunity.tier)
                    if opportunity.tripleSignal {
                        TripleSignalBadge(pulse: false)
                    }
                }

                // Ticker + upside
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(opportunity.ticker)
                        .font(DS.Font.mono(26))
                        .foregroundColor(.white)
                    Text("+\(Int(opportunity.upside))%")
                        .font(DS.Font.mono(15))
                        .foregroundColor(DS.Color.bull)
                }

                // Name + sector
                Text("\(opportunity.companyName) · \(opportunity.sector)")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Color.textSecondary)
            }

            Spacer()

            VStack(spacing: 8) {
                ScoreGauge(score: opportunity.score, tier: opportunity.tier, size: 62)

                HStack(spacing: 7) {
                    // Bookmark button
                    Button(action: { saved.toggle() }) {
                        Circle()
                            .fill(saved
                                  ? DS.Color.tier1.opacity(0.16)
                                  : DS.Color.elevated)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(saved
                                            ? DS.Color.tier1.opacity(0.4)
                                            : DS.Color.border,
                                            lineWidth: 0.5)
                            )
                            .overlay(
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(saved ? DS.Color.tier1 : DS.Color.textSecondary)
                            )
                    }

                    // Close button
                    Button(action: { onClose?() ?? dismiss() }) {
                        Circle()
                            .fill(DS.Color.elevated)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(DS.Color.border, lineWidth: 0.5)
                            )
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DS.Color.textSecondary)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: BLUF
    private var blufSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLUF · BOTTOM LINE UP FRONT")
                .font(.system(size: 10.5))
                .foregroundColor(DS.Color.textMuted)
                .tracking(0.6)

            Text(opportunity.bluf)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    // MARK: Metrics strip
    private var metricsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)) {
            DetailMetric(label: "Price", value: "$\(String(format: "%.2f", opportunity.price))")
            DetailMetric(label: "Upside", value: "+\(Int(opportunity.upside))%", color: DS.Color.bull)
            DetailMetric(label: "Mkt Cap", value: "$\(opportunity.marketCap)")
            DetailMetric(label: "Prob", value: "\(Int(opportunity.probability))%", color: DS.Color.accent)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(DS.Color.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
    }

    // MARK: AI Council Debate section
    private var councilSection: some View {
        ExpandableSection(
            title: "AI Council Debate",
            badge: AnyView(
                HStack(spacing: 4) {
                    let bulls = [opportunity.council.gemini, opportunity.council.deepseek, opportunity.council.cio]
                        .filter { $0 == .bull }.count
                    Text("\(bulls)/3 bull")
                        .font(DS.Font.mono(11))
                        .foregroundColor(bulls >= 2 ? DS.Color.bull : DS.Color.bear)
                }
            ),
            defaultOpen: true
        ) {
            VStack(spacing: 14) {
                CaseBlock(verdict: .bull, text: opportunity.bullCase)
                CaseBlock(verdict: .bear, text: opportunity.bearCase)
            }
        }
    }

    // MARK: Financials section
    private var financialsSection: some View {
        ExpandableSection(title: "Financials") {
            VStack(spacing: 0) {
                ForEach(Array(opportunity.financials.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row[0])
                            .font(.system(size: 13))
                            .foregroundColor(DS.Color.textSecondary)
                        Spacer()
                        Text(row[1])
                            .font(DS.Font.mono(13))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(i % 2 == 0 ? Color.clear : DS.Color.card)
                    if i < opportunity.financials.count - 1 {
                        Divider()
                            .background(DS.Color.border)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Color.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: Buy Zones section
    private var buyZonesSection: some View {
        ExpandableSection(
            title: "Buy Zones",
            badge: isPro ? nil : AnyView(LockBadge()),
            defaultOpen: true
        ) {
            BuyZoneCards(
                buyZones: opportunity.buyZones,
                isLocked: !isPro,
                onUnlock: onTogglePro,
                compact: false
            )
        }
    }

    // MARK: Bear Case section
    private var bearCaseSection: some View {
        ExpandableSection(
            title: "Bear Case",
            badge: AnyView(
                Text("\(opportunity.redFlags.count) flags")
                    .font(DS.Font.mono(11))
                    .foregroundColor(DS.Color.bear)
            )
        ) {
            VStack(spacing: 10) {
                ForEach(Array(opportunity.redFlags.enumerated()), id: \.offset) { i, flag in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(DS.Color.bear)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(flag)
                            .font(.system(size: 14))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineSpacing(3)
                    }
                }

                // Invalidation trigger
                VStack(alignment: .leading, spacing: 5) {
                    Text("INVALIDATION TRIGGER")
                        .font(.system(size: 10.5))
                        .foregroundColor(DS.Color.bear)
                        .tracking(0.5)
                    Text(opportunity.invalidation)
                        .font(.system(size: 13.5))
                        .foregroundColor(.white)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.bear.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DS.Color.bear.opacity(0.22), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: — Case block (bull/bear)

struct CaseBlock: View {
    let verdict: Verdict
    let text: String

    private var color: Color { verdict.color }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 6) {
                VerdictChip(verdict: verdict)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 11)
        }
    }
}

// MARK: — Expandable section (type-erased for simplicity)

struct ExpandableSection: View {
    let title: String
    let defaultOpen: Bool
    let badge: AnyView?
    let content: AnyView

    @State private var isOpen: Bool

    init<C: View>(
        title: String,
        defaultOpen: Bool = false,
        badge: AnyView? = nil,
        @ViewBuilder content: @escaping () -> C
    ) {
        self.title = title
        self.defaultOpen = defaultOpen
        self.badge = badge
        self.content = AnyView(content())
        self._isOpen = State(initialValue: defaultOpen)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DS.Color.border)

            Button(action: { withAnimation(.spring(response: 0.28)) { isOpen.toggle() } }) {
                HStack(spacing: 9) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    if let badge { badge }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Color.textMuted)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.vertical, 16)
            }

            if isOpen {
                content
                    .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: Detail metric

private struct DetailMetric: View {
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
