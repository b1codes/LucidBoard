import Foundation
import Testing
@testable import LucidBoard

struct TokenStoreTests {

    @Test func storesAndRetrievesSession() {
        let store = InMemoryTokenStore()
        store.save(token: "abc.def.ghi", refreshToken: "refresh-1", userId: "uid-dead")
        #expect(store.currentToken == "abc.def.ghi")
        #expect(store.currentRefreshToken == "refresh-1")
        #expect(store.currentUserId == "uid-dead")
    }

    @Test func clearEmptiesStorage() {
        let store = InMemoryTokenStore()
        store.save(token: "x", refreshToken: "r", userId: "u")
        store.clear()
        #expect(store.currentToken == nil)
        #expect(store.currentRefreshToken == nil)
        #expect(store.currentUserId == nil)
    }

    @Test func isExpiredTrueForExpiredJWT() {
        let store = InMemoryTokenStore()
        // exp = 1 (Jan 1 1970)
        let expiredJWT = "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjF9.sig"
        store.save(token: expiredJWT, refreshToken: "r", userId: "u")
        #expect(store.isCurrentTokenExpired)
    }

    @Test func isExpiredFalseForFutureJWT() {
        let store = InMemoryTokenStore()
        // exp = 9999999999 (year 2286)
        let futureJWT = "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig"
        store.save(token: futureJWT, refreshToken: "r", userId: "u")
        #expect(!store.isCurrentTokenExpired)
    }

    @Test func tokenExpiringWithinLeewayCountsAsExpired() {
        let exp = Int(Date().timeIntervalSince1970) + 30
        let jwt = TestJWT.make(exp: exp)
        #expect(InMemoryTokenStore.jwtIsExpired(jwt, leeway: 60))
        #expect(!InMemoryTokenStore.jwtIsExpired(jwt, leeway: 0))
    }
}

enum TestJWT {
    /// An unsigned JWT with the given `exp`, the shape the Auth emulator issues.
    static func make(exp: Int) -> String {
        func b64url(_ s: String) -> String {
            Data(s.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(b64url(#"{"alg":"none"}"#)).\(b64url("{\"exp\":\(exp)}")).sig"
    }
}
