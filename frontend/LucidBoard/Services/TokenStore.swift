import Foundation
import Security

/// Persists the Identity Platform session: the short-lived ID token sent as
/// the bearer token, and the long-lived refresh token that mints new ones for
/// the same account.
protocol TokenStore: AnyObject {
    nonisolated var currentToken: String? { get }
    nonisolated var currentRefreshToken: String? { get }
    nonisolated var currentUserId: String? { get }
    nonisolated var isCurrentTokenExpired: Bool { get }
    nonisolated func save(token: String, refreshToken: String, userId: String)
    nonisolated func clear()
}

extension TokenStore {
    nonisolated var isCurrentTokenExpired: Bool {
        guard let token = currentToken else { return true }
        return Self.jwtIsExpired(token)
    }

    /// True if the JWT's `exp` is within `leeway` seconds of now, so a token
    /// is refreshed slightly early instead of expiring mid-request.
    static func jwtIsExpired(_ jwt: String, leeway: TimeInterval = 60) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return true }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        b64.append(String(repeating: "=", count: (4 - b64.count % 4) % 4))
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return true }
        return Date(timeIntervalSince1970: exp - leeway) <= Date()
    }
}

final class InMemoryTokenStore: TokenStore {
    nonisolated(unsafe) private(set) var currentToken: String?
    nonisolated(unsafe) private(set) var currentRefreshToken: String?
    nonisolated(unsafe) private(set) var currentUserId: String?

    nonisolated func save(token: String, refreshToken: String, userId: String) {
        currentToken = token
        currentRefreshToken = refreshToken
        currentUserId = userId
    }

    nonisolated func clear() {
        currentToken = nil
        currentRefreshToken = nil
        currentUserId = nil
    }
}

final class KeychainTokenStore: TokenStore {
    private let service = "com.lucidboard.identity-platform"
    private let tokenAccount = "id_token"
    private let refreshTokenAccount = "refresh_token"
    private let userIdAccount = "user_id"

    nonisolated var currentToken: String? { readString(account: tokenAccount) }
    nonisolated var currentRefreshToken: String? { readString(account: refreshTokenAccount) }
    nonisolated var currentUserId: String? { readString(account: userIdAccount) }

    nonisolated func save(token: String, refreshToken: String, userId: String) {
        write(account: tokenAccount, value: Data(token.utf8))
        write(account: refreshTokenAccount, value: Data(refreshToken.utf8))
        write(account: userIdAccount, value: Data(userId.utf8))
    }

    nonisolated func clear() {
        delete(account: tokenAccount)
        delete(account: refreshTokenAccount)
        delete(account: userIdAccount)
    }

    // --- Keychain helpers ---

    nonisolated private func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    nonisolated private func write(account: String, value: Data) {
        delete(account: account)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = value
        // Readable in the background after first unlock, but never synced or
        // restored onto another device — the refresh token is a credential.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    nonisolated private func readString(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
