import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @State private var isPro = false
    @State private var alerts: [String: Bool] = [
        "t1": true,
        "triple": true,
        "council": false,
        "watch": true,
    ]

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    SettingsHeader()

                    VStack(spacing: 18) {
                        // Subscription card
                        subscriptionCard

                        // Alerts section
                        alertsSection

                        // Sign out
                        Button(action: { auth.signOut() }) {
                            Text("Sign out")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DS.Color.bear)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 44)
                }
            }
        }
    }

    // MARK: Subscription card
    private var subscriptionCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SUBSCRIPTION")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Color.textMuted)
                        .tracking(0.5)
                    Text(isPro ? "No Fomo Pro" : "Free tier")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                    Text(isPro
                         ? "Full briefs · buy zones · alerts"
                         : "Buy zones locked · upgrade to unlock")
                        .font(.system(size: 13))
                        .foregroundColor(DS.Color.textSecondary)
                }
                Spacer()
                if isPro {
                    VerdictChip(verdict: .bull, label: "Active")
                }
            }

            Button(action: { isPro.toggle() }) {
                Text(isPro ? "Manage subscription" : "Unlock Pro — $29/mo")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isPro ? DS.Color.textSecondary : Color(hex: "#06120c"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        isPro
                            ? DS.Color.elevated
                            : DS.Color.bull
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding(16)
        .background(
            isPro
                ? DS.Color.bull.opacity(0.09)
                : DS.Color.card
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DS.Color.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Alerts section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALERTS")
                .font(.system(size: 11))
                .foregroundColor(DS.Color.textMuted)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                AlertToggleRow(
                    title: "Tier 1 opportunities",
                    sub: "Push when an exceptional play clears",
                    isOn: Binding(
                        get: { alerts["t1"] ?? true },
                        set: { alerts["t1"] = $0 }
                    )
                )
                alertDivider
                AlertToggleRow(
                    title: "Triple Signal alerts",
                    sub: "Rare — the highest-conviction flag",
                    isOn: Binding(
                        get: { alerts["triple"] ?? true },
                        set: { alerts["triple"] = $0 }
                    )
                )
                alertDivider
                AlertToggleRow(
                    title: "Council disagreements",
                    sub: "When a model breaks from consensus",
                    isOn: Binding(
                        get: { alerts["council"] ?? false },
                        set: { alerts["council"] = $0 }
                    )
                )
                alertDivider
                AlertToggleRow(
                    title: "Watchlist buy zones",
                    sub: "Price enters a tracked buy range",
                    isOn: Binding(
                        get: { alerts["watch"] ?? true },
                        set: { alerts["watch"] = $0 }
                    )
                )
            }
            .background(DS.Color.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DS.Color.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var alertDivider: some View {
        Divider()
            .background(DS.Color.border)
            .padding(.leading, 14)
    }
}

// MARK: — Settings header

struct SettingsHeader: View {
    var body: some View {
        HStack {
            Text("Account")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .tracking(-0.5)
            Spacer()
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
        .padding(.bottom, 18)
    }
}

// MARK: — Alert toggle row

struct AlertToggleRow: View {
    let title: String
    let sub: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(sub)
                    .font(.system(size: 11.5))
                    .foregroundColor(DS.Color.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(DS.Color.bull)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
        .preferredColorScheme(.dark)
}
