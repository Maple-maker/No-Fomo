import SwiftUI

struct ThesisDetailView: View {
    let thesis: CustomThesis
    @ObservedObject var vm: RadarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var matches: [Opportunity] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var detailOpp: Opportunity? = nil

    // Always render the live copy — edits land in vm.theses while this sheet is up
    private var current: CustomThesis {
        vm.theses.first { $0.id == thesis.id } ?? thesis
    }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    summaryChips
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    if isScanning {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(DS.Color.textMuted)
                            Text("Scanning the radar...")
                                .font(.system(size: 13))
                                .foregroundColor(DS.Color.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else if matches.isEmpty && hasScanned {
                        emptyState
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(matches) { opp in
                                OpportunityCard(
                                    opportunity: opp,
                                    onOpen: { detailOpp = opp },
                                    density: .compact,
                                    isLocked: false
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 32)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ThesisEditorView(vm: vm, draft: current)
        }
        .sheet(item: $detailOpp) { opp in
            DetailSheet(opportunity: opp, isPro: true, onTogglePro: {})
        }
        .confirmationDialog("Delete this thesis?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await vm.delete(current)
                    dismiss()
                }
            }
        }
        .task { await scan() }
    }

    private func scan() async {
        isScanning = true
        matches = await vm.fetchMatches(for: current)
        isScanning = false
        hasScanned = true
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(current.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                Text(hasScanned
                     ? "\(matches.count) match\(matches.count == 1 ? "" : "es") right now"
                     : "\(current.matchCount) match\(current.matchCount == 1 ? "" : "es") all-time")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.textMuted)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: { showEditor = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DS.Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DS.Color.elevated)
                        .clipShape(Circle())
                }
                Button(action: { confirmDelete = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DS.Color.bear)
                        .frame(width: 32, height: 32)
                        .background(DS.Color.elevated)
                        .clipShape(Circle())
                }
                Button(action: { Task { await scan() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("Scan Now")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(DS.Color.tier1)
                    .clipShape(Capsule())
                }
                .disabled(isScanning)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Filter summary

    private var summaryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Score ≥ \(current.minScore)")
                chip("Tier \(current.tierFilter.map(String.init).joined(separator: ", "))")
                if current.minUpside > 0 { chip("Upside ≥ \(Int(current.minUpside))%") }
                ForEach(current.sectorFilter, id: \.self) { chip($0) }
                ForEach(current.detectionLanes, id: \.self) { chip($0) }
                if let max = current.maxAnalystCount { chip("≤ \(max) analysts") }
                if current.requireInsiderBuying { chip("Insider buying", highlight: true) }
                if current.requireGovContract { chip("Gov contract", highlight: true) }
                if current.requireFdaCatalyst { chip("FDA catalyst", highlight: true) }
                if current.requireEarningsInflection { chip("Earnings inflection", highlight: true) }
                if current.requireAnalystUpgrade { chip("Analyst upgrade", highlight: true) }
                if current.requireBullConsensus { chip("Bull consensus", highlight: true) }
                if current.requireTripleSignal { chip("Triple signal", highlight: true) }
            }
        }
    }

    private func chip(_ label: String, highlight: Bool = false) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(highlight ? DS.Color.tier1 : DS.Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(highlight ? DS.Color.tier1.opacity(0.12) : DS.Color.elevated)
            .clipShape(Capsule())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundColor(DS.Color.textMuted.opacity(0.4))
            Text("No matches yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DS.Color.textMuted)
            Text("The radar is scanning for you — it sweeps the market daily at 15:00 UTC.")
                .font(.system(size: 13))
                .foregroundColor(DS.Color.textMuted.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
        }
        .frame(maxWidth: .infinity)
    }
}
