import SwiftUI
import UIKit
import UserNotifications

// MARK: — NotificationRouter (deep-link bridge)
// Set on tap via UNUserNotificationCenterDelegate; WP-E wires the presentation side.

final class NotificationRouter: ObservableObject {
    @Published var pendingTicker: String?
    static let shared = NotificationRouter()
    private init() {}
}

// MARK: — AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register as the UNUserNotificationCenter delegate so foreground banners +
        // tap handling are routed here instead of being silently dropped.
        UNUserNotificationCenter.current().delegate = self

        // Never prompt at launch — the primer after onboarding owns the ask.
        // Silently re-register if the user already granted permission.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        Task {
            try? await SupabaseService.shared.registerPushToken(token, userId: userId)
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banner + play sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle tap on a notification — extract the ticker and publish it for deep-linking.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let ticker = userInfo["ticker"] as? String {
            DispatchQueue.main.async {
                // TODO(WP-E): observe NotificationRouter.shared.pendingTicker to present DetailSheet
                NotificationRouter.shared.pendingTicker = ticker
            }
        }
        completionHandler()
    }
}

// MARK: — App entry point

@main
struct NoFomoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var notificationRouter = NotificationRouter.shared
    @AppStorage("hasSeenNotificationPrimer") private var hasSeenNotificationPrimer = false

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated {
                    if hasSeenNotificationPrimer {
                        MainTabView()
                            .environmentObject(auth)
                            .environmentObject(notificationRouter)
                    } else {
                        NotificationPrimerView { hasSeenNotificationPrimer = true }
                    }
                } else {
                    OnboardingView()
                        .environmentObject(auth)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: — Notification primer (shown once, after onboarding/auth)

struct NotificationPrimerView: View {
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(DS.Color.tier1.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: [DS.Color.tier1, DS.Color.tier1.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Never miss alpha again.")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Enable notifications to get the BLUF the moment a Tier 1 or Tier 2 signal fires. The full debate and buy zones are waiting in the app.")
                        .font(DS.Font.body(16))
                        .foregroundColor(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.paddingScreen)

                Spacer()
                Spacer()

                VStack(spacing: 16) {
                    Button(action: requestPermission) {
                        Text("Enable Notifications")
                            .font(DS.Font.displayMedium(16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DS.Color.tier1)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onFinish) {
                        Text("Maybe later")
                            .font(DS.Font.body(14))
                            .foregroundColor(DS.Color.textSecondary)
                    }
                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.bottom, 48)
            }
        }
        .task {
            // Already granted or denied (e.g. via Settings) — nothing to ask, skip through.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus != .notDetermined {
                onFinish()
            }
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                onFinish()
            }
        }
    }
}
