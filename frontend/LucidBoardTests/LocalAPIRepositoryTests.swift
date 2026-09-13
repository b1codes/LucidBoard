import Foundation
import Testing
@testable import LucidBoard

// One serialized suite: every test shares MockURLProtocol's static responder.
@MainActor
@Suite(.serialized)
struct LocalAPIRepositoryTests {
    private static let authHost = "auth.test.invalid"
    private static let signUpPath = "/identitytoolkit.googleapis.com/v1/accounts:signUp"
    private static let refreshPath = "/securetoken.googleapis.com/v1/token"

    private static let validToken = TestJWT.make(exp: 9_999_999_999)
    private static let expiredToken = TestJWT.make(exp: 1)
    private var validToken: String { Self.validToken }
    private var expiredToken: String { Self.expiredToken }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.reset()
        return URLSession(configuration: config)
    }

    private func makeRepo(tokenStore: InMemoryTokenStore) -> LocalAPIRepository {
        let session = makeSession()
        let identityPlatform = IdentityPlatformClient(
            config: IdentityPlatformConfig(apiKey: "test-key", emulatorHost: Self.authHost),
            session: session,
            bundleIdentifier: "blc.LucidBoard"
        )
        return LocalAPIRepository(
            baseURL: "http://test.invalid",
            identityPlatform: identityPlatform,
            tokenStore: tokenStore,
            session: session
        )
    }

    // Responders run on URL-loading threads, so their helpers stay off the main actor.
    private nonisolated static func respond(_ req: URLRequest, _ status: Int, _ body: String) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
    }

    private nonisolated static func signUpBody(uid: String) -> String {
        #"{"idToken":"\#(validToken)","refreshToken":"refresh-\#(uid)","localId":"\#(uid)","expiresIn":"3600"}"#
    }

    private nonisolated static func refreshBody(uid: String) -> String {
        #"{"id_token":"\#(validToken)","refresh_token":"refresh-\#(uid)","user_id":"\#(uid)","expires_in":"3600"}"#
    }

    // MARK: - Sign-in

    @Test func signInAnonymously_signsUpAgainstEmulatorAndStoresSession() async throws {
        let tokenStore = InMemoryTokenStore()
        let repo = makeRepo(tokenStore: tokenStore)
        MockURLProtocol.responder = { req in
            #expect(req.url?.host == Self.authHost)
            #expect(req.url?.path == Self.signUpPath)
            #expect(req.url?.query == "key=test-key")
            #expect(req.httpMethod == "POST")
            return Self.respond(req, 200, Self.signUpBody(uid: "uid-new"))
        }
        try await repo.signInAnonymously()
        #expect(tokenStore.currentToken == validToken)
        #expect(tokenStore.currentRefreshToken == "refresh-uid-new")
        #expect(tokenStore.currentUserId == "uid-new")
        #expect(repo.isSignedIn)
    }

    @Test func signInAnonymously_reusesValidStoredSessionWithoutNetwork() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: validToken, refreshToken: "refresh-uid-1", userId: "uid-1")
        let repo = makeRepo(tokenStore: tokenStore)
        MockURLProtocol.responder = { req in
            Issue.record("unexpected request to \(req.url!)")
            return Self.respond(req, 500, "")
        }
        try await repo.signInAnonymously()
        #expect(tokenStore.currentUserId == "uid-1")
    }

    @Test func signInAnonymously_refreshesExpiredTokenForSameAccount() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: expiredToken, refreshToken: "refresh-uid-1", userId: "uid-1")
        let repo = makeRepo(tokenStore: tokenStore)
        MockURLProtocol.responder = { req in
            #expect(req.url?.path == Self.refreshPath)
            let form = String(decoding: MockURLProtocol.body(of: req), as: UTF8.self)
            #expect(form.contains("grant_type=refresh_token"))
            #expect(form.contains("refresh_token=refresh-uid-1"))
            return Self.respond(req, 200, Self.refreshBody(uid: "uid-1"))
        }
        try await repo.signInAnonymously()
        #expect(tokenStore.currentToken == validToken)
        #expect(tokenStore.currentUserId == "uid-1")
    }

    @Test func concurrentSignIns_shareOneSignUp() async throws {
        let tokenStore = InMemoryTokenStore()
        let repo = makeRepo(tokenStore: tokenStore)
        let signUps = Counter()
        MockURLProtocol.responder = { req in
            signUps.bumpSync()
            Thread.sleep(forTimeInterval: 0.05)  // keep the first sign-up in flight
            return Self.respond(req, 200, Self.signUpBody(uid: "uid-\(signUps.valueSync)"))
        }
        async let a: Void = repo.signInAnonymously()
        async let b: Void = repo.signInAnonymously()
        async let c: Void = repo.signInAnonymously()
        _ = try await (a, b, c)
        #expect(signUps.valueSync == 1)
        #expect(tokenStore.currentUserId == "uid-1")
    }

    // MARK: - Authenticated requests

    @Test func fetchBoards_attachesBearerHeaderAndDecodesStringUserId() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: validToken, refreshToken: "r", userId: "uid-1")
        let repo = makeRepo(tokenStore: tokenStore)
        let token = validToken
        MockURLProtocol.responder = { req in
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
            return Self.respond(req, 200, """
            [{"id":"11111111-1111-1111-1111-111111111111","user_id":"uid-1","title":"b",\
            "background_color":"#FFFFFF","background_layout":"grid",\
            "created_at":"2026-09-13T00:00:00Z","updated_at":"2026-09-13T00:00:00Z"}]
            """)
        }
        let boards = try await repo.fetchBoards()
        #expect(boards.map(\.userId) == ["uid-1"])
    }

    @Test func unauthorized_refreshesSessionAndRetriesOnce() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: validToken, refreshToken: "refresh-uid-1", userId: "uid-1")
        let repo = makeRepo(tokenStore: tokenStore)
        let apiCalls = Counter()
        MockURLProtocol.responder = { req in
            switch req.url?.path {
            case Self.refreshPath:
                return Self.respond(req, 200, Self.refreshBody(uid: "uid-1"))
            case Self.signUpPath:
                Issue.record("a 401 must not create a new account while the refresh token works")
                return Self.respond(req, 500, "")
            default:
                apiCalls.bumpSync()
                return apiCalls.valueSync == 1 ? Self.respond(req, 401, "") : Self.respond(req, 200, "[]")
            }
        }
        _ = try await repo.fetchBoards()
        #expect(apiCalls.valueSync == 2)
        #expect(tokenStore.currentUserId == "uid-1")
    }

    @Test func rejectedRefreshToken_fallsBackToNewAnonymousAccount() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: expiredToken, refreshToken: "revoked", userId: "uid-gone")
        let repo = makeRepo(tokenStore: tokenStore)
        MockURLProtocol.responder = { req in
            switch req.url?.path {
            case Self.refreshPath:
                return Self.respond(req, 400, #"{"error":{"code":400,"message":"TOKEN_EXPIRED"}}"#)
            case Self.signUpPath:
                return Self.respond(req, 200, Self.signUpBody(uid: "uid-new"))
            default:
                return Self.respond(req, 200, "[]")
            }
        }
        _ = try await repo.fetchBoards()
        #expect(tokenStore.currentUserId == "uid-new")
    }

    @Test func refreshRejectedForConfigReason_keepsExistingAccount() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: expiredToken, refreshToken: "refresh-uid-1", userId: "uid-1")
        let repo = makeRepo(tokenStore: tokenStore)
        MockURLProtocol.responder = { req in
            if req.url?.path == Self.signUpPath {
                Issue.record("a misconfigured API key must not trigger a new account")
            }
            return Self.respond(req, 403, #"{"error":{"code":403,"message":"Requests from this iOS client application <empty> are blocked."}}"#)
        }
        await #expect(throws: IdentityPlatformError.self) {
            _ = try await repo.fetchBoards()
        }
        #expect(tokenStore.currentRefreshToken == "refresh-uid-1")
        #expect(tokenStore.currentUserId == "uid-1")
    }

    @Test func refreshNetworkFailure_keepsExistingAccount() async throws {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(token: expiredToken, refreshToken: "refresh-uid-1", userId: "uid-1")
        let repo = makeRepo(tokenStore: tokenStore)
        MockURLProtocol.error = URLError(.notConnectedToInternet)
        await #expect(throws: IdentityPlatformError.self) {
            _ = try await repo.fetchBoards()
        }
        #expect(tokenStore.currentRefreshToken == "refresh-uid-1")
        #expect(tokenStore.currentUserId == "uid-1")
    }

    @Test func localAPI_subscribeToNotes_returnsInert() {
        let repo = makeRepo(tokenStore: InMemoryTokenStore())
        var called = false
        let sub = repo.subscribeToNotes(boardId: UUID()) { _ in called = true }
        sub.cancel()
        #expect(called == false)
    }

    // MARK: - IdentityPlatformClient (production endpoints)

    @Test func identityPlatform_productionSignUpUsesHTTPSAndBundleHeader() async throws {
        let client = IdentityPlatformClient(
            config: IdentityPlatformConfig(apiKey: "prod-key", emulatorHost: nil),
            session: makeSession(),
            bundleIdentifier: "blc.LucidBoard"
        )
        MockURLProtocol.responder = { req in
            #expect(req.url?.absoluteString == "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=prod-key")
            #expect(req.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == "blc.LucidBoard")
            let json = try? JSONSerialization.jsonObject(with: MockURLProtocol.body(of: req)) as? [String: Bool]
            #expect(json?["returnSecureToken"] == true)
            return Self.respond(req, 200, Self.signUpBody(uid: "uid-prod"))
        }
        let session = try await client.signUpAnonymously()
        #expect(session.userId == "uid-prod")
    }

    @Test func identityPlatform_productionRefreshUsesSecureTokenAPI() async throws {
        let client = IdentityPlatformClient(
            config: IdentityPlatformConfig(apiKey: "prod-key", emulatorHost: nil),
            session: makeSession(),
            bundleIdentifier: nil
        )
        MockURLProtocol.responder = { req in
            #expect(req.url?.absoluteString == "https://securetoken.googleapis.com/v1/token?key=prod-key")
            #expect(req.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == nil)
            // "+" must be escaped or form decoding turns it into a space.
            let form = String(decoding: MockURLProtocol.body(of: req), as: UTF8.self)
            #expect(form.contains("refresh_token=a%2Bb"))
            return Self.respond(req, 200, Self.refreshBody(uid: "uid-prod"))
        }
        let session = try await client.refresh(refreshToken: "a+b")
        #expect(session.refreshToken == "refresh-uid-prod")
    }

    @Test func identityPlatform_errorResponseSurfacesMessage() async throws {
        let client = IdentityPlatformClient(
            config: IdentityPlatformConfig(apiKey: "bad", emulatorHost: nil),
            session: makeSession(),
            bundleIdentifier: nil
        )
        MockURLProtocol.responder = { req in
            Self.respond(req, 400, #"{"error":{"code":400,"message":"API_KEY_INVALID"}}"#)
        }
        do {
            _ = try await client.signUpAnonymously()
            Issue.record("expected an error")
        } catch IdentityPlatformError.rejected(let status, let message) {
            #expect(status == 400)
            #expect(message == "API_KEY_INVALID")
        }
    }
}

// MARK: - Helpers

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var valueSync: Int { lock.lock(); defer { lock.unlock() }; return _value }
    func bumpSync() { lock.lock(); defer { lock.unlock() }; _value += 1 }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: ((URLRequest) -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var error: Error?

    static func reset() {
        responder = nil
        error = nil
    }

    /// URLProtocol sees uploads as `httpBodyStream`, not `httpBody`.
    static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "no responder", code: 0))
            return
        }
        let (response, data) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
