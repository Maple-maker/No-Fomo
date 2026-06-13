import Foundation
import AuthenticationServices
import Security

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var currentToken: String?

    private let supabaseURL = "https://jmtkygwvmrolfvwueggs.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptdGt5Z3d2bXJvbGZ2d3VlZ2dzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzMzAxODUsImV4cCI6MjA5NTkwNjE4NX0.JUbsLc_KHHdfXWDSAl9Rf00Da-axpSj4Nw4DvXGNBvk"

    private init() {
        // Clear any stale UserDefaults tokens from before Keychain migration
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "auth_user_id")
        loadStoredSession()
    }

    // MARK: - Sign in with Apple

    func handleAppleSignIn(_ authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AppError.unauthorized
        }

        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode([
            "provider": "apple",
            "id_token": identityToken,
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.throwIfAuthError(data: data, response: resp)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        await handleAuthResponse(response)
    }

    // MARK: - Email/password (fallback)

    func signInWithEmail(_ email: String, password: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.throwIfAuthError(data: data, response: resp)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        await handleAuthResponse(response)
    }

    func signUp(email: String, password: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.throwIfAuthError(data: data, response: resp)
        if let response = try? JSONDecoder().decode(AuthResponse.self, from: data) {
            await handleAuthResponse(response)
        } else {
            // No session in the response — project requires email confirmation first.
            throw AuthError.emailConfirmationPending
        }
    }

    private static func throwIfAuthError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode >= 400 else { return }
        let payload = try? JSONDecoder().decode(SupabaseAuthErrorPayload.self, from: data)
        throw AuthError.serverMessage(payload?.message ?? "Something went wrong. Try again.")
    }

    #if DEBUG
    func forceDevSession() {
        signInAnonymously(subscriptionTier: .pro)
        currentUser = AppUser(
            id: currentUser?.id ?? "dev-user-0001",
            email: "dev@nofomo.local",
            subscriptionTier: .pro,
            apnsToken: nil
        )
    }
    #endif

    func signInAnonymously(subscriptionTier: SubscriptionTier = .free) {
        let existingId = Keychain.load(key: "anon_user_id")
        let userId = existingId ?? UUID().uuidString
        Keychain.delete(key: "auth_user_id")
        Keychain.save(userId, key: "anon_user_id")
        Keychain.save("anon", key: "auth_token")
        currentToken = "anon"
        currentUser = AppUser(id: userId, email: nil, subscriptionTier: subscriptionTier, apnsToken: nil)
        isAuthenticated = true
    }

    func signOut() {
        currentToken = nil
        currentUser = nil
        isAuthenticated = false
        Keychain.delete(key: "auth_token")
        Keychain.delete(key: "auth_user_id")
        Keychain.delete(key: "anon_user_id")
        UserDefaults.standard.set(false, forKey: "hasSeenNotificationPrimer")
    }

    // MARK: - Private

    private func handleAuthResponse(_ response: AuthResponse) async {
        currentToken = response.accessToken
        Keychain.save(response.accessToken, key: "auth_token")
        Keychain.save(response.user.id, key: "auth_user_id")
        currentUser = AppUser(
            id: response.user.id,
            email: response.user.email,
            subscriptionTier: .free,
            apnsToken: nil
        )
        isAuthenticated = true
    }

    private func loadStoredSession() {
        guard let token = Keychain.load(key: "auth_token") else { return }
        if token == "dev-skip-token" || token == "anon" {
            signInAnonymously()
            return
        }
        guard token.split(separator: ".").count == 3 else {
            signInAnonymously()
            return
        }
        guard let userId = Keychain.load(key: "auth_user_id") else {
            signInAnonymously()
            return
        }
        currentToken = token
        currentUser = AppUser(id: userId, email: nil, subscriptionTier: .free, apnsToken: nil)
        isAuthenticated = true
    }
}

// MARK: - Keychain helper

private enum Keychain {
    private static let service = "com.nofomo.app"

    static func save(_ value: String, key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum AuthError: LocalizedError {
    case serverMessage(String)
    case emailConfirmationPending

    var errorDescription: String? {
        switch self {
        case .serverMessage(let msg): return msg
        case .emailConfirmationPending:
            return "Check your inbox to confirm your email, then sign in."
        }
    }
}

private struct SupabaseAuthErrorPayload: Decodable {
    let msg: String?
    let errorDescription: String?
    var message: String? { msg ?? errorDescription }

    enum CodingKeys: String, CodingKey {
        case msg
        case errorDescription = "error_description"
    }
}

private struct AuthResponse: Codable {
    let accessToken: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

private struct AuthUser: Codable {
    let id: String
    let email: String?
}
