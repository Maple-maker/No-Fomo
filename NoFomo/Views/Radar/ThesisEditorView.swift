import SwiftUI

struct ThesisEditorView: View {
    @ObservedObject var vm: RadarViewModel
    @State var draft: CustomThesis
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let sectorOptions = [
        "Technology", "Software", "AI/ML", "Data Center", "Semiconductors",
        "Defense", "Aerospace", "Space", "Biotech", "Healthcare",
        "Energy", "Crypto", "Fintech", "Industrial", "Consumer",
    ]

    init(vm: RadarViewModel, draft: CustomThesis) {
        self.vm = vm
        _draft = State(initialValue: draft)
        // Editing an existing thesis skips the template picker
        _step = State(initialValue: draft.id == 0 ? 0 : 1)
    }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $step) {
                    templateStep.tag(0)
                    nameStep.tag(1)
                    filtersStep.tag(2)
                    signalsStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.28), value: step)

                bottomBar
                    .padding(.horizontal, DS.paddingScreen)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Step 0 — Templates

    private var templateStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeader("Start from a template", subtitle: "Proven setups — tweak anything in the next steps.")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(ThesisTemplate.all) { template in
                        Button(action: { apply(template) }) {
                            templateCard(icon: template.icon, name: template.name, blurb: template.blurb,
                                         selected: draft.templateId == template.id)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { goCustom() }) {
                        templateCard(icon: "slider.horizontal.3", name: "Custom",
                                     blurb: "Start from a blank slate",
                                     selected: draft.templateId == nil && !draft.name.isEmpty)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.paddingScreen)
            }
            .padding(.bottom, 16)
        }
    }

    private func templateCard(icon: String, name: String, blurb: String, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DS.Color.tier1)
            Text(name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(blurb)
                .font(.system(size: 10.5))
                .foregroundColor(DS.Color.textMuted)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 116)
        .padding(12)
        .background(DS.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? DS.Color.tier1.opacity(0.6) : DS.Color.border, lineWidth: selected ? 1 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func apply(_ template: ThesisTemplate) {
        var t = template.makeThesis(userId: draft.userId)
        t.id = draft.id
        draft = t
        withAnimation { step = 1 }
    }

    private func goCustom() {
        let id = draft.id
        let userId = draft.userId
        draft = .blank(userId: userId)
        draft.id = id
        withAnimation { step = 1 }
    }

    // MARK: - Step 1 — Name

    private var nameStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeader("Name your thesis", subtitle: "What are you hunting for?")

                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(DS.Font.caption(10))
                        .foregroundColor(DS.Color.textMuted)
                    TextField("e.g. Defense AI Moonshots", text: $draft.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(DS.Color.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DS.Color.border, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, DS.paddingScreen)

                VStack(alignment: .leading, spacing: 6) {
                    Text("DESCRIPTION (OPTIONAL)")
                        .font(DS.Font.caption(10))
                        .foregroundColor(DS.Color.textMuted)
                    TextEditor(text: Binding(
                        get: { draft.description ?? "" },
                        set: { draft.description = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(DS.Color.textSecondary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 110)
                    .background(DS.Color.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DS.Color.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, DS.paddingScreen)
            }
        }
    }

    // MARK: - Step 2 — Filters

    private var filtersStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader("Set your filters", subtitle: "Narrow the radar to your universe.")

                // Sectors
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("SECTORS — \(draft.sectorFilter.isEmpty ? "ALL" : "\(draft.sectorFilter.count) SELECTED")")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(sectorOptions, id: \.self) { sector in
                            let on = draft.sectorFilter.contains(sector)
                            Button(action: {
                                if on { draft.sectorFilter.removeAll { $0 == sector } }
                                else { draft.sectorFilter.append(sector) }
                            }) {
                                Text(sector)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(on ? .black : DS.Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(on ? DS.Color.tier1 : DS.Color.elevated)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DS.paddingScreen)

                // Tiers
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("TIERS")
                    HStack(spacing: 10) {
                        tierToggle(1, label: "Tier 1 — Exceptional")
                        tierToggle(2, label: "Tier 2 — High Conviction")
                    }
                }
                .padding(.horizontal, DS.paddingScreen)

                // Min score
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel("MINIMUM SCORE")
                        Spacer()
                        Text("\(draft.minScore)")
                            .font(DS.Font.mono(14))
                            .foregroundColor(DS.Color.tier1)
                    }
                    Slider(value: Binding(
                        get: { Double(draft.minScore) },
                        set: { draft.minScore = Int($0) }
                    ), in: 50...95, step: 1)
                    .tint(DS.Color.tier1)
                }
                .padding(.horizontal, DS.paddingScreen)

                // Analyst coverage cap
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            sectionLabel("UNDERFOLLOWED ONLY")
                            Text("Cap how many analysts can already cover it")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { draft.maxAnalystCount != nil },
                            set: { draft.maxAnalystCount = $0 ? 5 : nil }
                        ))
                        .labelsHidden()
                        .tint(DS.Color.tier1)
                    }
                    if let max = draft.maxAnalystCount {
                        Stepper(value: Binding(
                            get: { draft.maxAnalystCount ?? 5 },
                            set: { draft.maxAnalystCount = $0 }
                        ), in: 0...15) {
                            Text("≤ \(max) analysts")
                                .font(DS.Font.mono(13))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(DS.Color.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, DS.paddingScreen)
            }
            .padding(.bottom, 16)
        }
    }

    private func tierToggle(_ tier: Int, label: String) -> some View {
        let on = draft.tierFilter.contains(tier)
        return Button(action: {
            if on {
                // Never allow zero tiers
                if draft.tierFilter.count > 1 { draft.tierFilter.removeAll { $0 == tier } }
            } else {
                draft.tierFilter.append(tier)
                draft.tierFilter.sort()
            }
        }) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(on ? .black : DS.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(on ? (tier == 1 ? DS.Color.tier1 : DS.Color.tier2) : DS.Color.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3 — Signals + notifications

    private var signalsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader("Require signals", subtitle: "Only match when these fire. Leave off for broader sweeps.")

                VStack(spacing: 2) {
                    signalRow("Insider buying", caption: "Cluster of open-market insider purchases", isOn: $draft.requireInsiderBuying)
                    signalRow("Government contract", caption: "Contract signal in the government lane", isOn: $draft.requireGovContract)
                    signalRow("FDA catalyst", caption: "FDA / PDUFA / approval event on deck", isOn: $draft.requireFdaCatalyst)
                    signalRow("Earnings inflection", caption: "Revenue growth accelerating", isOn: $draft.requireEarningsInflection)
                    signalRow("Analyst upgrade", caption: "Recent rating upgrade on the street", isOn: $draft.requireAnalystUpgrade)
                    signalRow("Bull consensus", caption: "All three AI council members bullish", isOn: $draft.requireBullConsensus)
                    signalRow("Triple signal", caption: "The radar's rare highest-conviction stamp", isOn: $draft.requireTripleSignal)
                }
                .padding(.horizontal, DS.paddingScreen)

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("ALERTS")
                    VStack(spacing: 2) {
                        signalRow("Tier 1 matches", caption: "Push the moment an exceptional pick matches", isOn: $draft.notifyTier1)
                        signalRow("Tier 2 matches", caption: "Push on high-conviction matches too", isOn: $draft.notifyTier2)
                    }
                }
                .padding(.horizontal, DS.paddingScreen)
            }
            .padding(.bottom, 16)
        }
    }

    private func signalRow(_ label: String, caption: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundColor(DS.Color.textMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DS.Color.tier1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Shared bits

    private func stepHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .tracking(-0.5)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(DS.Color.textMuted)
        }
        .padding(.horizontal, DS.paddingScreen)
        .padding(.top, 28)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.caption(10))
            .foregroundColor(DS.Color.textMuted)
            .tracking(0.5)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            // Capsule step indicator (matches onboarding)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? DS.Color.tier1 : DS.Color.border)
                        .frame(width: i == step ? 24 : 6, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
                }
            }

            HStack(spacing: 10) {
                if step > 0 {
                    Button(action: { withAnimation { step -= 1 } }) {
                        Text("Back")
                            .font(DS.Font.displayMedium(15))
                            .foregroundColor(DS.Color.textSecondary)
                            .frame(width: 90)
                            .padding(.vertical, 15)
                            .background(DS.Color.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                if step < 3 {
                    Button(action: { withAnimation { step += 1 } }) {
                        Text("Continue")
                            .font(DS.Font.displayMedium(15))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(DS.Color.tier1)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    Button(action: { save() }) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.black)
                            }
                            Text(isSaving ? "Saving..." : "Save Thesis")
                                .font(DS.Font.displayMedium(15))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSave ? DS.Color.tier1 : DS.Color.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await vm.save(draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
