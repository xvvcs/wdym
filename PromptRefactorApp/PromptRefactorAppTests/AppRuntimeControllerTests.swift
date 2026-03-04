import Foundation
import PromptRefactorCore
import Testing
@testable import PromptRefactorApp

@MainActor
struct AppRuntimeControllerTests {
    @Test func runtimeLoadsStoredGroqApiKeyIntoSecureFieldState() {
        let runtime = makeRuntime(initialAPIKey: "gsk_existing_key")

        #expect(runtime.hasStoredGroqAPIKey)
        #expect(runtime.groqAPIKeyInput == "gsk_existing_key")
    }

    @Test func saveGroqApiKeyKeepsValueAndClearRemovesIt() {
        let keychain = InMemoryKeychainStore(apiKey: nil)
        let runtime = makeRuntime(initialAPIKey: nil, keychain: keychain)

        runtime.groqAPIKeyInput = "  gsk_new_key  "
        runtime.saveGroqAPIKey()

        #expect(runtime.groqAPIKeyInput == "gsk_new_key")
        #expect(runtime.hasStoredGroqAPIKey)
        #expect(keychain.apiKey == "gsk_new_key")

        runtime.clearGroqAPIKey()

        #expect(runtime.groqAPIKeyInput.isEmpty)
        #expect(!runtime.hasStoredGroqAPIKey)
        #expect(keychain.apiKey == nil)
    }

    private func makeRuntime(initialAPIKey: String?, keychain: InMemoryKeychainStore? = nil) -> AppRuntimeController {
        let suite = "AppRuntimeControllerTests.\(UUID().uuidString)"
        let settingsStore = UserDefaultsAppSettingsStore(userDefaults: UserDefaults(suiteName: suite)!)

        let keychainStore = keychain ?? InMemoryKeychainStore(apiKey: initialAPIKey)
        if keychain == nil {
            keychainStore.apiKey = initialAPIKey
        }

        return AppRuntimeController(
            settingsStore: settingsStore,
            refactorService: PromptRefactorService(),
            hotkeyService: StubHotkeyService(),
            keychainStore: keychainStore,
            providerFactory: ProviderFactory()
        )
    }
}

private final class StubHotkeyService: HotkeyService {
    func startListening(binding: HotkeyBinding, handler: @escaping () -> Void) {}
    func updateBinding(_ binding: HotkeyBinding) {}
    func stopListening() {}
}

private final class InMemoryKeychainStore: KeychainStore {
    var apiKey: String?

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func loadGroqAPIKey() -> String? {
        apiKey
    }

    func saveGroqAPIKey(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    func deleteGroqAPIKey() throws {
        apiKey = nil
    }
}
