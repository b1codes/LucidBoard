import Foundation

// MARK: - Error types

enum LocalAPIError: Error {
    case unauthorized
    case notFound
    case validation(String)
    case network(URLError)
    case server(status: Int, code: String?)
    case decoding(Error)
}

// MARK: - Private response shapes

private struct APIError: Decodable {
    let detail: String?
    let code: String?
}

private struct NotePosition: Decodable {
    let id: UUID
    let newX: Float
    let newY: Float

    enum CodingKeys: String, CodingKey {
        case id
        case newX = "new_x"
        case newY = "new_y"
    }
}

private struct BoardUpdatePayload: Encodable {
    let title: String
    let backgroundColor: String
    let backgroundLayout: BackgroundLayout

    enum CodingKeys: String, CodingKey {
        case title
        case backgroundColor = "background_color"
        case backgroundLayout = "background_layout"
    }
}

private struct ProfilePayload: Encodable {
    let settings: AppSettings
}

private struct MatchNotesPayload: Encodable {
    let boardUUID: UUID

    enum CodingKeys: String, CodingKey {
        case boardUUID = "board_uuid"
    }
}

// MARK: - NotePayload (handles contentDrawing → base64)

private struct NotePayload: Encodable {
    let id: UUID
    let boardId: UUID
    let userId: String
    let contentText: String?
    let contentDrawing: String?  // base64-encoded
    let color: String
    let posX: Float
    let posY: Float
    let zIndex: Int
    let template: NoteTemplate
    let checklistItems: [ChecklistItem]?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case boardId = "board_id"
        case userId = "user_id"
        case contentText = "content_text"
        case contentDrawing = "content_drawing"
        case color
        case posX = "pos_x"
        case posY = "pos_y"
        case zIndex = "z_index"
        case template
        case checklistItems = "checklist_items"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from note: Note) {
        self.id = note.id
        self.boardId = note.boardId
        self.userId = note.userId
        self.contentText = note.contentText
        self.contentDrawing = note.contentDrawing.map { $0.base64EncodedString() }
        self.color = note.color
        self.posX = note.posX
        self.posY = note.posY
        self.zIndex = note.zIndex
        self.template = note.template
        self.checklistItems = note.checklistItems
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
    }
}

// MARK: - LocalAPIRepository

/// Serializes session acquisition so concurrent callers that all find no
/// usable token share one refresh/sign-up. Without this, parallel anonymous
/// sign-ups at launch would each mint a different Identity Platform user.
private actor SessionCoordinator {
    private var inFlight: Task<Void, Error>?

    func run(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await operation() }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }
}

final class LocalAPIRepository: AppRepository {
    private let baseURL: String
    private let identityPlatform: IdentityPlatformClient
    private let tokenStore: TokenStore
    private let session: URLSession
    private let sessionCoordinator = SessionCoordinator()

    // Shared encoder/decoder with ISO 8601 dates.
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(
        baseURL: String,
        identityPlatform: IdentityPlatformClient,
        tokenStore: TokenStore,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.identityPlatform = identityPlatform
        self.tokenStore = tokenStore
        self.session = session
    }

    /// Signed in means we hold a refresh token: an expired ID token is
    /// renewed transparently on the next request.
    nonisolated var isSignedIn: Bool {
        tokenStore.currentRefreshToken != nil
    }

    // MARK: - Auth

    /// Ensure an Identity Platform session exists. Like FirebaseAuth's
    /// `signInAnonymously()`, this reuses the stored anonymous account rather
    /// than minting a new one, so relaunching the app keeps the user's boards.
    nonisolated func signInAnonymously() async throws {
        try await ensureSession(forceRefresh: false)
    }

    /// Make the token store hold a usable ID token, preferring (in order) the
    /// current token, a refresh of the stored account, and only then a brand
    /// new anonymous account.
    ///
    /// - Parameter forceRefresh: the API rejected the current token, so don't
    ///   trust its `exp` claim.
    private nonisolated func ensureSession(forceRefresh: Bool) async throws {
        try await sessionCoordinator.run { [self] in
            if !forceRefresh, tokenStore.currentRefreshToken != nil, !tokenStore.isCurrentTokenExpired {
                return
            }
            if let refreshToken = tokenStore.currentRefreshToken {
                do {
                    store(try await identityPlatform.refresh(refreshToken: refreshToken))
                    return
                } catch let error as IdentityPlatformError where error.isRefreshTokenDead {
                    // That identity is gone for good. Every other failure
                    // (offline, 5xx, misconfigured API key) propagates instead:
                    // signing up anew would orphan the user's boards.
                    tokenStore.clear()
                }
            }
            store(try await identityPlatform.signUpAnonymously())
        }
    }

    private nonisolated func store(_ session: AuthSession) {
        tokenStore.save(token: session.idToken, refreshToken: session.refreshToken, userId: session.userId)
    }

    // MARK: - Boards

    nonisolated func fetchBoards() async throws -> [Board] {
        let data = try await perform(path: "/api/boards", method: "GET")
        do {
            return try decoder.decode([Board].self, from: data)
        } catch {
            throw LocalAPIError.decoding(error)
        }
    }

    nonisolated func updateBoard(_ board: Board) async throws {
        let payload = BoardUpdatePayload(
            title: board.title,
            backgroundColor: board.backgroundColor,
            backgroundLayout: board.backgroundLayout
        )
        let body = try encoder.encode(payload)
        _ = try await perform(path: "/api/boards/\(board.id)", method: "PATCH", body: body)
    }

    // MARK: - Notes

    nonisolated func fetchNotes(boardId: UUID) async throws -> [Note] {
        let data = try await perform(path: "/api/boards/\(boardId)/notes", method: "GET")
        do {
            return try decoder.decode([Note].self, from: data)
        } catch {
            throw LocalAPIError.decoding(error)
        }
    }

    nonisolated func upsertNote(_ note: Note) async throws {
        let payload = NotePayload(from: note)
        let body = try encoder.encode(payload)
        _ = try await perform(path: "/api/notes/\(note.id)", method: "PUT", body: body)
    }

    nonisolated func deleteNote(id: UUID) async throws {
        _ = try await perform(path: "/api/notes/\(id)", method: "DELETE")
    }

    // MARK: - Profile

    nonisolated func fetchProfile() async throws -> AppSettings? {
        do {
            let data = try await perform(path: "/api/profile", method: "GET")
            let wrapper = try decoder.decode([String: AppSettings].self, from: data)
            return wrapper["settings"]
        } catch LocalAPIError.notFound {
            return nil
        } catch {
            throw error
        }
    }

    nonisolated func updateProfile(settings: AppSettings) async throws {
        let payload = ProfilePayload(settings: settings)
        let body = try encoder.encode(payload)
        _ = try await perform(path: "/api/profile", method: "PUT", body: body)
    }

    // MARK: - AI

    nonisolated func autoOrganize(boardId: UUID) async throws -> [UUID: (Float, Float)] {
        let payload = MatchNotesPayload(boardUUID: boardId)
        let body = try encoder.encode(payload)
        let data = try await perform(path: "/api/rpc/match_notes", method: "POST", body: body)

        let positions: [NotePosition]
        do {
            positions = try decoder.decode([NotePosition].self, from: data)
        } catch {
            throw LocalAPIError.decoding(error)
        }
        return Dictionary(uniqueKeysWithValues: positions.map { ($0.id, ($0.newX, $0.newY)) })
    }

    // MARK: - Realtime

    nonisolated func subscribeToNotes(boardId: UUID, onChange: @escaping (NoteChange) -> Void) -> NoteSubscription {
        InertNoteSubscription()
    }

    // MARK: - Private helpers

    /// Build an authenticated URLRequest for the given API path and method.
    private nonisolated func makeRequest(path: String, method: String, body: Data?) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = tokenStore.currentToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    /// Low-level send: wraps URLError into LocalAPIError.network.
    private nonisolated func performRaw(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (data, httpResponse)
        } catch let urlError as URLError {
            throw LocalAPIError.network(urlError)
        }
    }

    /// High-level send: refreshes an expiring token up front, maps status
    /// codes, and on a 401 force-refreshes the session and retries once.
    private nonisolated func perform(path: String, method: String, body: Data? = nil) async throws -> Data {
        try await ensureSession(forceRefresh: false)
        let (data, response) = try await performRaw(makeRequest(path: path, method: method, body: body))

        if response.statusCode == 401 {
            try await ensureSession(forceRefresh: true)
            let (retryData, retryResponse) = try await performRaw(makeRequest(path: path, method: method, body: body))
            try checkStatus(retryResponse, data: retryData)
            return retryData
        }

        try checkStatus(response, data: data)
        return data
    }

    /// Map HTTP status to LocalAPIError (throws); otherwise returns normally.
    private nonisolated func checkStatus(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw LocalAPIError.unauthorized
        case 404:
            throw LocalAPIError.notFound
        case 422:
            let message = (try? JSONDecoder().decode(APIError.self, from: data))?.detail ?? "Validation error"
            throw LocalAPIError.validation(message)
        default:
            let code = (try? JSONDecoder().decode(APIError.self, from: data))?.code
            throw LocalAPIError.server(status: response.statusCode, code: code)
        }
    }
}
