import Foundation
import AuthenticationServices

// MARK: - Models

struct AuthSession {
    let accessToken: String
    let refreshToken: String
    let userID: String
    let expiresAt: Date

    var isExpired: Bool { Date() >= expiresAt }
}

enum OAuthProvider: String {
    case apple  = "apple"
    case google = "google"
}

// MARK: - Service

@Observable
final class AuthService: NSObject {
    private(set) var session: AuthSession?

    var isAuthenticated: Bool { session != nil }

    private let client = SupabaseClient.shared
    private var webAuthSession: ASWebAuthenticationSession?

    private enum StorageKey {
        static let accessToken  = "supabase_access_token"
        static let refreshToken = "supabase_refresh_token"
        static let userID       = "supabase_user_id"
        static let expiresAt    = "supabase_expires_at"
    }

    override init() {
        super.init()
        loadStoredSession()
    }

    // MARK: - OAuth sign in

    @MainActor
    func signIn(with provider: OAuthProvider) async throws {
        let urlString = "\(SupabaseConfig.projectURL)/auth/v1/authorize"
            + "?provider=\(provider.rawValue)"
            + "&redirect_to=\(SupabaseConfig.redirectURL)"
        guard let authorizeURL = URL(string: urlString) else {
            throw SupabaseError.badURL
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let webSession = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: "spendr"
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: SupabaseError.noData)
                }
            }
            webSession.presentationContextProvider = self
            webSession.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = webSession
            webSession.start()
        }

        try parseAndStoreSession(from: callbackURL)
    }

    // MARK: - Magic link (email)

    func sendMagicLink(to email: String) async throws {
        struct Body: Encodable { let email: String }
        let body = try client.encoder.encode(Body(email: email))
        let _: EmptyResponse = try await client.authRequest(
            path: "/magiclink",
            method: "POST",
            body: body
        )
    }

    // MARK: - Sign out

    func signOut() async {
        if let token = session?.accessToken {
            let _: EmptyResponse? = try? await client.authRequest(
                path: "/logout",
                method: "POST",
                accessToken: token
            )
        }
        clearStoredSession()
    }

    // MARK: - Token refresh

    func refreshIfNeeded() async throws {
        guard let current = session, current.isExpired else { return }

        struct Body: Encodable { let refresh_token: String }
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
            let user: UserPayload
        }
        struct UserPayload: Decodable { let id: String }

        let body = try client.encoder.encode(Body(refresh_token: current.refreshToken))
        let response: TokenResponse = try await client.authRequest(
            path: "/token?grant_type=refresh_token",
            method: "POST",
            body: body
        )

        let refreshed = AuthSession(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            userID: response.user.id,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in))
        )
        storeSession(refreshed)
    }

    // MARK: - Private helpers

    private func parseAndStoreSession(from url: URL) throws {
        // Supabase returns tokens in the URL fragment:
        // spendr://auth#access_token=xxx&refresh_token=yyy&expires_in=3600&...
        let raw = url.fragment ?? url.query ?? ""
        var params: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key   = String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                params[key] = value
            }
        }

        guard
            let accessToken  = params["access_token"],
            let refreshToken = params["refresh_token"],
            let expiresInStr = params["expires_in"],
            let expiresIn    = Double(expiresInStr)
        else { throw SupabaseError.parseError }

        let userID = params["user_id"] ?? extractUserID(from: accessToken) ?? ""

        storeSession(AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            expiresAt: Date().addingTimeInterval(expiresIn)
        ))
    }

    /// Decode the `sub` claim from a JWT without a third-party library.
    private func extractUserID(from jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder > 0 { payload += String(repeating: "=", count: 4 - remainder) }
        guard
            let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub  = json["sub"] as? String
        else { return nil }
        return sub
    }

    private func storeSession(_ newSession: AuthSession) {
        session = newSession
        let ud = UserDefaults.standard
        ud.set(newSession.accessToken,                  forKey: StorageKey.accessToken)
        ud.set(newSession.refreshToken,                 forKey: StorageKey.refreshToken)
        ud.set(newSession.userID,                       forKey: StorageKey.userID)
        ud.set(newSession.expiresAt.timeIntervalSince1970, forKey: StorageKey.expiresAt)
    }

    private func loadStoredSession() {
        let ud = UserDefaults.standard
        guard
            let accessToken  = ud.string(forKey: StorageKey.accessToken),
            let refreshToken = ud.string(forKey: StorageKey.refreshToken),
            let userID       = ud.string(forKey: StorageKey.userID)
        else { return }
        let expiresAt = Date(timeIntervalSince1970: ud.double(forKey: StorageKey.expiresAt))
        session = AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            expiresAt: expiresAt
        )
    }

    private func clearStoredSession() {
        session = nil
        let ud = UserDefaults.standard
        ud.removeObject(forKey: StorageKey.accessToken)
        ud.removeObject(forKey: StorageKey.refreshToken)
        ud.removeObject(forKey: StorageKey.userID)
        ud.removeObject(forKey: StorageKey.expiresAt)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

// MARK: - Helpers

private struct EmptyResponse: Decodable {}
