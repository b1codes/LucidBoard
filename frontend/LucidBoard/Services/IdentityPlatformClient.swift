import Foundation

// MARK: - Configuration

nonisolated struct IdentityPlatformConfig {
    /// Web API key of the GCP project (restricted to this app's bundle id in
    /// production). The Auth emulator accepts any value.
    let apiKey: String
    /// `host:port` of the Firebase Auth emulator, or nil to talk to the real
    /// Google Cloud Identity Platform endpoints.
    let emulatorHost: String?

    /// The emulator serves every Google auth API under
    /// `http://<emulator>/<real API host>/...`, so only the prefix changes.
    fileprivate func baseURL(apiHost: String) -> String {
        if let emulatorHost {
            return "http://\(emulatorHost)/\(apiHost)/v1"
        }
        return "https://\(apiHost)/v1"
    }

    fileprivate var identityToolkitBase: String { baseURL(apiHost: "identitytoolkit.googleapis.com") }
    fileprivate var secureTokenBase: String { baseURL(apiHost: "securetoken.googleapis.com") }
}

// MARK: - Session & errors

nonisolated struct AuthSession: Equatable, Sendable {
    let idToken: String
    let refreshToken: String
    let userId: String
}

nonisolated enum IdentityPlatformError: Error {
    case network(URLError)
    /// Identity Platform answered with an error, e.g. 400 `TOKEN_EXPIRED`,
    /// `USER_NOT_FOUND`, or `API_KEY_INVALID`.
    case rejected(status: Int, message: String?)
    case decoding(Error)

    /// True only when Identity Platform says a refresh token can never work
    /// again (expired/revoked, or its account deleted). Anything else, such as
    /// a bad API key, network trouble, or a disabled user, must not be
    /// mistaken for this, or the caller would abandon a still-valid account.
    var isRefreshTokenDead: Bool {
        guard case .rejected(_, let message?) = self else { return false }
        return ["TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND"]
            .contains { message.hasPrefix($0) }
    }
}

private nonisolated struct SignUpResponse: Decodable {
    let idToken: String
    let refreshToken: String
    let localId: String
}

private nonisolated struct RefreshResponse: Decodable {
    let idToken: String
    let refreshToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
    }
}

private nonisolated struct ErrorEnvelope: Decodable {
    struct Body: Decodable { let message: String? }
    let error: Body
}

// MARK: - Client

/// Minimal REST client for Google Cloud Identity Platform's anonymous auth
/// flow (the same endpoints the Firebase SDKs wrap).
nonisolated final class IdentityPlatformClient {
    private let config: IdentityPlatformConfig
    private let session: URLSession
    private let bundleIdentifier: String?

    init(config: IdentityPlatformConfig, session: URLSession = .shared, bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.config = config
        self.session = session
        self.bundleIdentifier = bundleIdentifier
    }

    /// Create a new anonymous Identity Platform account.
    func signUpAnonymously() async throws -> AuthSession {
        var req = try makeRequest(base: config.identityToolkitBase, path: "/accounts:signUp")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data(#"{"returnSecureToken":true}"#.utf8)
        let response: SignUpResponse = try await send(req)
        return AuthSession(idToken: response.idToken, refreshToken: response.refreshToken, userId: response.localId)
    }

    /// Exchange a refresh token for a fresh ID token for the same account.
    func refresh(refreshToken: String) async throws -> AuthSession {
        var req = try makeRequest(base: config.secureTokenBase, path: "/token")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        // URLComponents leaves "+" unescaped, which form decoding reads as a space.
        let encoded = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") ?? ""
        req.httpBody = Data(encoded.utf8)
        let response: RefreshResponse = try await send(req)
        return AuthSession(idToken: response.idToken, refreshToken: response.refreshToken, userId: response.userId)
    }

    // MARK: - Private helpers

    private func makeRequest(base: String, path: String) throws -> URLRequest {
        var components = URLComponents(string: base + path)
        components?.queryItems = [URLQueryItem(name: "key", value: config.apiKey)]
        guard let url = components?.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        // Required when the API key is restricted to iOS apps.
        if let bundleIdentifier {
            req.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        return req
    }

    private func send<Response: Decodable>(_ req: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            throw IdentityPlatformError.network(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            throw IdentityPlatformError.network(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
            throw IdentityPlatformError.rejected(status: http.statusCode, message: message)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw IdentityPlatformError.decoding(error)
        }
    }
}
