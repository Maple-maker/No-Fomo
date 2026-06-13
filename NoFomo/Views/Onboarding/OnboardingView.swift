import SwiftUI
import AuthenticationServices
import Combine

struct OnboardingView: View {
    private enum AuthMode { case signIn, signUp }

    @EnvironmentObject var auth: AuthService
    @State private var page = 0
    @State private var showAuth = false
    @State private var authMode: AuthMode = .signUp
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingConfirmation = false
    @State private var teaserIndex = 0
    private let teaserTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private struct PageInfo {
        let icon: String
        let title: String
        let subtitle: String
        let glowColor: Color
    }

    private let pageData: [PageInfo] = [
        PageInfo(icon: "antenna.radiowaves.left.and.right",
                 title: "Never miss alpha again.",
                 subtitle: "No Fomo scans government contracts, FDA approvals, earnings transcripts, and tech giant signals — 24/7.",
                 glowColor: DS.Color.bull),
        PageInfo(icon: "cpu.fill",
                 title: "AI council debates every pick.",
                 subtitle: "Gemini, DeepSeek, and an AI CIO each argue bull AND bear — you get the synthesis, not a single opinion.",
                 glowColor: DS.Color.accent),
        PageInfo(icon: "chart.bar.fill",
                 title: "Only the best surface.",
                 subtitle: "A 75/100 conviction gate filters noise. You see Tier 1 and Tier 2 opportunities only. No filler.",
                 glowColor: DS.Color.tier1),
    ]

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            if showAuth {
                authView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                onboardingPages
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            }
        }
        .animation(.spring(response: 0.4), value: showAuth)
    }

    // MARK: — Onboarding Pages

    private var onboardingPages: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                featurePage(index: 0).tag(0)
                featurePage(index: 1).tag(1)
                featurePage(index: 2).tag(2)
                signalTeaserPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.28), value: page)

            bottomBar
                .padding(.horizontal, DS.paddingScreen)
                .padding(.top, 16)
                .padding(.bottom, 48)
        }
    }

    private func featurePage(index: Int) -> some View {
        let info = pageData[index]
        return VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Glow + icon (horizontally centered despite leading VStack)
            ZStack {
                Circle()
                    .fill(info.glowColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                Image(systemName: info.icon)
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(LinearGradient(
                        colors: [info.glowColor, info.glowColor.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 48)

            // Left-aligned text
            VStack(alignment: .leading, spacing: 12) {
                Text(info.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(info.subtitle)
                    .font(DS.Font.body(16))
                    .foregroundColor(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.paddingScreen)

            Spacer()
            Spacer()
        }
    }

    private var signalTeaserPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("The radar is live.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("Three signals found this morning.")
                    .font(DS.Font.body(16))
                    .foregroundColor(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.paddingScreen)
            .padding(.top, 56)

            Spacer().frame(height: 28)

            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(Self.sampleOpportunities.enumerated()), id: \.element.id) { i, opp in
                                    OpportunityCard(opportunity: opp, density: .compact, isLocked: true)
                                        .frame(width: geo.size.width * 0.82)
                                        .id(i)
                                }
                            }
                            .padding(.horizontal, DS.paddingScreen)
                            .padding(.vertical, 4)
                        }
                        .onReceive(teaserTimer) { _ in
                            // Auto-rotate through the picks, only while this page is visible
                            guard page == 3 else { return }
                            teaserIndex = (teaserIndex + 1) % Self.sampleOpportunities.count
                            withAnimation(.easeInOut(duration: 0.8)) {
                                proxy.scrollTo(teaserIndex, anchor: .center)
                            }
                        }
                    }
                    // Right-edge fade to hint at more cards
                    LinearGradient(colors: [.clear, DS.Color.background],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 64)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 340)

            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Capsule page indicators (gold active, border inactive)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? DS.Color.tier1 : DS.Color.border)
                        .frame(width: i == page ? 24 : 6, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                }
            }

            // CTA — gold, label switches on last page
            Button(action: {
                withAnimation {
                    if page < 3 {
                        page += 1
                    } else {
                        authMode = .signUp
                        showAuth = true
                    }
                }
            }) {
                Text(page == 3 ? "Get Started — Free" : "Continue")
                    .font(DS.Font.displayMedium(16))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DS.Color.tier1)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(action: {
                withAnimation {
                    authMode = .signIn
                    showAuth = true
                }
            }) {
                (Text("Already have an account? ")
                    .foregroundColor(DS.Color.textSecondary)
                 + Text("Log in.")
                    .foregroundColor(.white)
                    .fontWeight(.semibold))
                    .font(DS.Font.body(14))
            }

            Button(action: { auth.signInAnonymously() }) {
                Text("Continue without account")
                    .font(DS.Font.caption(12))
                    .foregroundColor(DS.Color.textMuted)
                    .underline()
            }

            #if DEBUG
            Button(action: { auth.forceDevSession() }) {
                Text("Dev preview (Pro)")
                    .font(DS.Font.caption(11))
                    .foregroundColor(DS.Color.textMuted)
            }
            #endif
        }
    }

    // MARK: — Auth

    private var authView: some View {
        VStack(spacing: 0) {
            // Back
            HStack {
                Button(action: {
                    withAnimation {
                        showAuth = false
                        errorMessage = nil
                        pendingConfirmation = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.Color.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, DS.paddingScreen)
            .padding(.top, 60)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text(authMode == .signUp ? "Create your account." : "Welcome back.")
                    .font(DS.Font.displayBold(32))
                    .foregroundColor(.white)
                Text(authMode == .signUp
                     ? "Free forever. The radar starts scanning the moment you're in."
                     : "Sign in to access the radar.")
                    .font(DS.Font.body())
                    .foregroundColor(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.paddingScreen)

            Spacer()

            VStack(spacing: 12) {
                // Sign in with Apple (primary)
                SignInWithAppleButton(authMode == .signUp ? .signUp : .signIn) { req in
                    req.requestedScopes = [.email]
                } onCompletion: { result in
                    Task {
                        switch result {
                        case .success(let authorization):
                            isLoading = true
                            do {
                                try await AuthService.shared.handleAppleSignIn(authorization)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        case .failure(let err):
                            // Dismissing the Apple sheet isn't an error worth surfacing
                            if (err as? ASAuthorizationError)?.code != .canceled {
                                errorMessage = err.localizedDescription
                            }
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .id(authMode)

                // Divider
                HStack {
                    Rectangle().fill(DS.Color.border).frame(height: 0.5)
                    Text("or")
                        .font(DS.Font.caption())
                        .foregroundColor(DS.Color.textMuted)
                        .padding(.horizontal, 12)
                    Rectangle().fill(DS.Color.border).frame(height: 0.5)
                }

                // Email
                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .textFieldStyle(NFFTextField())
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textFieldStyle(NFFTextField())
                        .textContentType(authMode == .signUp ? .newPassword : .password)
                }

                if pendingConfirmation {
                    Text("Check your inbox to confirm your email, then sign in.")
                        .font(DS.Font.caption())
                        .foregroundColor(DS.Color.bull)
                        .multilineTextAlignment(.center)
                } else if let err = errorMessage {
                    Text(err)
                        .font(DS.Font.caption())
                        .foregroundColor(DS.Color.bear)
                        .multilineTextAlignment(.center)
                }

                Button(action: submitEmailAuth) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text(authMode == .signUp ? "Create Account" : "Sign In")
                                .font(DS.Font.displayMedium(16))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DS.Color.bull)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        authMode = authMode == .signUp ? .signIn : .signUp
                        errorMessage = nil
                        pendingConfirmation = false
                    }
                }) {
                    (authMode == .signUp
                     ? Text("Already have an account? ").foregroundColor(DS.Color.textSecondary)
                       + Text("Sign in.").foregroundColor(.white).fontWeight(.semibold)
                     : Text("New here? ").foregroundColor(DS.Color.textSecondary)
                       + Text("Create an account.").foregroundColor(.white).fontWeight(.semibold))
                        .font(DS.Font.body(14))
                }

                Button(action: {
                    auth.signInAnonymously()
                }) {
                    Text("Continue without account")
                        .font(DS.Font.caption(12))
                        .foregroundColor(DS.Color.textMuted)
                        .underline()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, DS.paddingScreen)
            .padding(.bottom, 48)
        }
    }

    private func submitEmailAuth() {
        Task {
            isLoading = true
            errorMessage = nil
            pendingConfirmation = false
            do {
                switch authMode {
                case .signIn:
                    try await AuthService.shared.signInWithEmail(email, password: password)
                case .signUp:
                    try await AuthService.shared.signUp(email: email, password: password)
                }
            } catch AuthError.emailConfirmationPending {
                // Account created — Supabase wants the email link tapped before a session exists
                pendingConfirmation = true
                authMode = .signIn
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: — Onboarding sample data (signal teaser carousel)

private extension OnboardingView {
    static let sampleOpportunities: [Opportunity] = [
        Opportunity(
            id: "onboard-1", ticker: "ANDR", companyName: "Andromeda Defense",
            sector: "Defense Tech", tier: 1, score: 87, tripleSignal: true,
            bluf: "Sole-source DoD contract for AI-enabled ISR drones. Q4 delivery milestone triggers $240M payment.",
            price: 23.40, upside: 310, marketCap: "1.1B", probability: 82,
            catalyst: "DoD milestone payment + NDAA inclusion vote",
            council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
            buyZones: BuyZones(aggressive: 20.50, base: 22.00, conservative: 24.10),
            notificationLine: "Triple Signal fired — insider cluster + DoD award + analyst divergence",
            priceChangePct: 4.2, taSummary: "RSI 61 — momentum building",
            aiSynopsis: "Unusual call activity detected this morning.",
            upcomingEvents: [["Jun 18", "Q2 earnings + contract update", "earnings"]],
            tags: ["Government Contract", "Insider Buying", "Triple Signal"],
            rsiValue: 61, macdTrend: "bullish", volumeVsAvg: 2.3,
            supportLevel: 20.50, resistanceLevel: 26.00,
            analystConsensus: "Buy", analystCount: 2, avgPriceTarget: 38.00,
            analystHighTarget: 52.00, analystLowTarget: 28.00,
            institutionalOwnershipPct: 14, institutionalFlow: "inflow", topHolder: "Renaissance Tech",
            asymmetryScore: 9, convictionScore: 8, catalystScore: 9, managementScore: 8,
            researchedAt: "2026-06-11T08:00:00Z",
            detectionLane: "Government Support"
        ),
        Opportunity(
            id: "onboard-2", ticker: "PLTR", companyName: "Palantir Technologies",
            sector: "Data Intelligence", tier: 2, score: 79,
            bluf: "AIP platform expanding into defense primes. Commercial ARR accelerating at 68% YoY.",
            price: 34.10, upside: 180, marketCap: "71B", probability: 74,
            catalyst: "Q2 earnings beat + new enterprise AIP deals",
            council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bear),
            buyZones: BuyZones(aggressive: 30.00, base: 33.00, conservative: 36.50),
            notificationLine: "Wedbush raises PT to $58 — cites AIP commercial traction.",
            priceChangePct: 1.8, taSummary: "Breaking out of 3-month base on volume",
            aiSynopsis: "Commercial customer adds accelerating heading into Q2.",
            tags: ["Data Platform", "AI Infrastructure"],
            rsiValue: 58, macdTrend: "bullish", volumeVsAvg: 1.6,
            analystConsensus: "Buy", analystCount: 18, avgPriceTarget: 48.00,
            analystHighTarget: 65.00, analystLowTarget: 22.00,
            institutionalOwnershipPct: 38, institutionalFlow: "inflow",
            asymmetryScore: 7, convictionScore: 7, catalystScore: 8, managementScore: 9,
            researchedAt: "2026-06-11T07:30:00Z",
            detectionLane: "Overlooked Analysis"
        ),
        Opportunity(
            id: "onboard-3", ticker: "RXMD", companyName: "RxMedical Dynamics",
            sector: "Biotech", tier: 2, score: 82,
            bluf: "FDA PDUFA date June 28 for lead oncology candidate. 3-of-4 analyst models show approvable.",
            price: 8.75, upside: 420, marketCap: "290M", probability: 71,
            catalyst: "FDA PDUFA decision June 28",
            council: AICouncil(gemini: .bull, deepseek: .bull, cio: .bull),
            buyZones: BuyZones(aggressive: 7.00, base: 8.50, conservative: 10.00),
            notificationLine: "CEO + 2 board members bought $1.2M combined last week.",
            priceChangePct: 6.1, taSummary: "RSI 68 — pre-catalyst squeeze",
            aiSynopsis: "Options implied move of ±45% priced in for PDUFA week.",
            upcomingEvents: [["Jun 28", "FDA PDUFA decision", "sector"]],
            tags: ["FDA Catalyst", "Insider Buying", "Binary Event"],
            rsiValue: 68, macdTrend: "bullish", volumeVsAvg: 3.1,
            analystConsensus: "Strong Buy", analystCount: 3, avgPriceTarget: 45.00,
            analystHighTarget: 62.00, analystLowTarget: 28.00,
            institutionalOwnershipPct: 9, institutionalFlow: "inflow",
            asymmetryScore: 9, convictionScore: 8, catalystScore: 9, managementScore: 7,
            researchedAt: "2026-06-11T06:45:00Z",
            detectionLane: "Indirect Catalyst"
        ),
    ]
}

// MARK: — Custom text field style

struct NFFTextField: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(DS.Font.body())
            .foregroundColor(.white)
            .padding(14)
            .background(DS.Color.card)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Color.border, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
