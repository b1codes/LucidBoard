import Foundation
import Testing
@testable import LucidBoard

struct AppRepositoryFactoryTests {
    private let identityPlatform = IdentityPlatformConfig(apiKey: "fake-api-key", emulatorHost: "127.0.0.1:9099")

    @Test func makeLocalAPIWhenBackendKindIsLocal() {
        let repo = AppRepositoryFactory.make(
            backendKind: "local",
            localAPIBaseURL: "http://127.0.0.1:8000",
            identityPlatform: identityPlatform,
            tokenStore: InMemoryTokenStore()
        )
        #expect(repo is LocalAPIRepository)
    }

    @Test func makeSupabaseByDefault() {
        let repo = AppRepositoryFactory.make(
            backendKind: "supabase",
            localAPIBaseURL: "http://127.0.0.1:8000",
            identityPlatform: identityPlatform,
            tokenStore: InMemoryTokenStore()
        )
        #expect(repo is SupabaseRepository)
    }
}
