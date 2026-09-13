import Foundation

enum NoteChange {
    case upsert(Note)
    case delete(id: UUID)
}

protocol NoteSubscription {
    func cancel()
}

protocol AppRepository {
    // Auth
    nonisolated func signInAnonymously() async throws
    nonisolated var isSignedIn: Bool { get }

    // Boards
    nonisolated func fetchBoards() async throws -> [Board]
    nonisolated func updateBoard(_ board: Board) async throws

    // Notes
    nonisolated func fetchNotes(boardId: UUID) async throws -> [Note]
    nonisolated func upsertNote(_ note: Note) async throws
    nonisolated func deleteNote(id: UUID) async throws

    // Profile
    nonisolated func fetchProfile() async throws -> AppSettings?
    nonisolated func updateProfile(settings: AppSettings) async throws

    // AI
    nonisolated func autoOrganize(boardId: UUID) async throws -> [UUID: (Float, Float)]

    // Realtime
    nonisolated func subscribeToNotes(
        boardId: UUID,
        onChange: @escaping (NoteChange) -> Void
    ) -> NoteSubscription
}

final class InertNoteSubscription: NoteSubscription {
    func cancel() {}
}

enum AppRepositoryFactory {
    static func make(
        backendKind: String,
        localAPIBaseURL: String,
        identityPlatform: IdentityPlatformConfig,
        tokenStore: TokenStore
    ) -> AppRepository {
        switch backendKind {
        case "local":
            return LocalAPIRepository(
                baseURL: localAPIBaseURL,
                identityPlatform: IdentityPlatformClient(config: identityPlatform),
                tokenStore: tokenStore
            )
        default:
            return SupabaseRepository()
        }
    }

    /// Pick a repository based on build configuration and overrides.
    ///
    /// Each setting resolves in this priority order:
    ///   1. `LUCIDBOARD_*` environment variable (useful for tests and scheme overrides)
    ///   2. The matching key in `Info.plist`, if present
    ///   3. Compile-time default (Debug targets the local backend + Firebase Emulator Suite)
    ///
    /// | Setting | Env var | Info.plist key | Debug default |
    /// |---|---|---|---|
    /// | backend | `LUCIDBOARD_BACKEND_KIND` | `BACKEND_KIND` | `local` |
    /// | API URL | `LUCIDBOARD_LOCAL_API_URL` | `LOCAL_API_URL` | `http://127.0.0.1:8000` |
    /// | API key | `LUCIDBOARD_IDENTITY_PLATFORM_API_KEY` | `IDENTITY_PLATFORM_API_KEY` | `fake-api-key` |
    /// | Auth emulator | `LUCIDBOARD_AUTH_EMULATOR_HOST` | `AUTH_EMULATOR_HOST` | `127.0.0.1:9099` |
    ///
    /// An empty auth emulator host means "use real Identity Platform".
    static func makeFromBundle() -> AppRepository {
        let backendKind = setting(env: "LUCIDBOARD_BACKEND_KIND", plist: "BACKEND_KIND") ?? defaultBackendKind
        let baseURL = setting(env: "LUCIDBOARD_LOCAL_API_URL", plist: "LOCAL_API_URL") ?? "http://127.0.0.1:8000"
        let apiKey = setting(env: "LUCIDBOARD_IDENTITY_PLATFORM_API_KEY", plist: "IDENTITY_PLATFORM_API_KEY")
            ?? defaultIdentityPlatformAPIKey
        let emulatorHost = setting(env: "LUCIDBOARD_AUTH_EMULATOR_HOST", plist: "AUTH_EMULATOR_HOST")
            ?? defaultAuthEmulatorHost
        return make(
            backendKind: backendKind,
            localAPIBaseURL: baseURL,
            identityPlatform: IdentityPlatformConfig(
                apiKey: apiKey,
                emulatorHost: emulatorHost.isEmpty ? nil : emulatorHost
            ),
            tokenStore: KeychainTokenStore()
        )
    }

    private static func setting(env: String, plist: String) -> String? {
        ProcessInfo.processInfo.environment[env]
            ?? Bundle.main.object(forInfoDictionaryKey: plist) as? String
    }

    private static var defaultBackendKind: String {
        #if DEBUG
        return "local"
        #else
        return "supabase"
        #endif
    }

    private static var defaultIdentityPlatformAPIKey: String {
        #if DEBUG
        return "fake-api-key"  // the Auth emulator accepts any key
        #else
        return ""
        #endif
    }

    private static var defaultAuthEmulatorHost: String {
        #if DEBUG
        return "127.0.0.1:9099"
        #else
        return ""
        #endif
    }
}
