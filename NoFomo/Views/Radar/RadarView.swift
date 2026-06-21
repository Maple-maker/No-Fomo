import SwiftUI

struct RadarView: View {
    @StateObject private var vm = RadarViewModel()
    @EnvironmentObject var auth: AuthService

    @State private var showEditor = false
    @State private var detailThesis: CustomThesis? = nil

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header

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

                        if vm.isLoading && vm.theses.isEmpty {
                            ProgressView()
                                .tint(DS.Color.textMuted)
                                .padding(.top, 80)
                        } else if vm.theses.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(vm.theses) { thesis in
                                    ThesisCard(
                                        thesis: thesis,
                                        onTap: { detailThesis = thesis },
                                        onToggleActive: { Task { await vm.toggleActive(thesis) } }
                                    )
                                }
                            }
                            .padding(.horizontal, DS.paddingScreen)
                            .padding(.top, 8)
                        }
                    }
                    .refreshable { await vm.load() }
                }

                // Tab bar spacer
                Color.clear.frame(height: 22)
            }
        }
        .sheet(isPresented: $showEditor) {
            ThesisEditorView(vm: vm, draft: .blank(userId: auth.currentUser?.id ?? ""))
        }
        .sheet(item: $detailThesis) { thesis in
            ThesisDetailView(thesis: thesis, vm: vm)
        }
        .task { await vm.load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Your Theses")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                Text("\(vm.theses.count) built · \(vm.theses.filter(\.isActive).count) active")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.textMuted)
            }
            Spacer()
            Button(action: { showEditor = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Color.tier1)
                    .frame(width: DS.minTouchTarget, height: DS.minTouchTarget)
                    .background(
                        Circle()
                            .fill(DS.Color.elevated)
                            .frame(width: 36, height: 36)
                    )
                    .overlay(
                        Circle()
                            .stroke(DS.Color.tier1.opacity(0.3), lineWidth: 0.5)
                            .frame(width: 36, height: 36)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)
            ZStack {
                Circle()
                    .fill(DS.Color.tier1.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 28)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(LinearGradient(
                        colors: [DS.Color.tier1, DS.Color.tier1.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom))
            }
            Text("Build your first thesis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("Define what you're hunting for and the radar will alert you the moment a pick matches.")
                .font(.system(size: 13))
                .foregroundColor(DS.Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Button(action: { showEditor = true }) {
                Text("Browse Templates")
                    .font(DS.Font.displayMedium(15))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(DS.Color.tier1)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Thesis card row

private struct ThesisCard: View {
    let thesis: CustomThesis
    let onTap: () -> Void
    let onToggleActive: () -> Void

    private var templateName: String? {
        guard let id = thesis.templateId else { return nil }
        return ThesisTemplate.all.first { $0.id == id }?.name
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thesis.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(templateName ?? "Custom")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(templateName != nil ? DS.Color.tier1 : DS.Color.textMuted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background((templateName != nil ? DS.Color.tier1 : DS.Color.textMuted).opacity(0.12))
                                .clipShape(Capsule())
                            Text("\(thesis.matchCount) match\(thesis.matchCount == 1 ? "" : "es")")
                                .font(DS.Font.mono(10))
                                .foregroundColor(DS.Color.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(DS.Color.elevated)
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { thesis.isActive },
                        set: { _ in onToggleActive() }
                    ))
                    .labelsHidden()
                    .tint(DS.Color.tier1)
                }

                HStack(spacing: 8) {
                    filterChip("Score ≥ \(thesis.minScore)")
                    filterChip("T\(thesis.tierFilter.map(String.init).joined(separator: "/T"))")
                    if !thesis.sectorFilter.isEmpty {
                        filterChip("\(thesis.sectorFilter.count) sector\(thesis.sectorFilter.count == 1 ? "" : "s")")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Color.textMuted)
                }
            }
            .padding(DS.paddingCompact)
            .background(DS.Color.card)
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusCard)
                    .stroke(thesis.isActive ? DS.Color.tier1.opacity(0.25) : DS.Color.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusCard))
            .opacity(thesis.isActive ? 1 : 0.6)
        }
        .buttonStyle(.plain)
    }

    private func filterChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(DS.Color.textMuted)
    }
}

#Preview {
    RadarView()
        .environmentObject(AuthService.shared)
        .preferredColorScheme(.dark)
}
