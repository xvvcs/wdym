import Testing

@testable import PromptRefactorApp

@MainActor
struct ProviderFactoryTests {
  @Test func providerFactoryReturnsNilWhenGroqDisabled() {
    let settings = AppSettings.default
    let factory = ProviderFactory()

    let provider = factory.makeProvider(
      settings: settings, keychainStore: InMemoryKeychainStore(apiKey: "key"))

    #expect(provider == nil)
  }

  @Test func providerFactoryReturnsNilWhenApiKeyMissing() {
    var settings = AppSettings.default
    settings.useGroqRefinement = true

    let provider = ProviderFactory().makeProvider(
      settings: settings,
      keychainStore: InMemoryKeychainStore(apiKey: nil)
    )

    #expect(provider == nil)
  }

  @Test func providerFactoryReturnsGroqProviderWhenEnabledAndConfigured() {
    var settings = AppSettings.default
    settings.useGroqRefinement = true

    let provider = ProviderFactory().makeProvider(
      settings: settings,
      keychainStore: InMemoryKeychainStore(apiKey: "gsk_test")
    )

    #expect(provider != nil)
  }
}

private struct InMemoryKeychainStore: KeychainStore {
  var apiKey: String?

  func loadGroqAPIKey() -> String? {
    apiKey
  }

  func saveGroqAPIKey(_ apiKey: String) throws {}

  func deleteGroqAPIKey() throws {}
}
