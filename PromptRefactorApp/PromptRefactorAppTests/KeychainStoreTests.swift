import Foundation
import Security
import Testing

@testable import PromptRefactorApp

/// Tests use the system Keychain for the app's service/account.
/// `@Suite(.serialized)` prevents parallel runs; each test cleans up via
/// `defer { try? store.deleteGroqAPIKey() }`.
@Suite(.serialized)
struct KeychainStoreTests {
  private let store = DefaultKeychainStore()

  @Test func saveThenLoadReturnsSavedKey() throws {
    try store.deleteGroqAPIKey()
    defer { try? store.deleteGroqAPIKey() }

    try store.saveGroqAPIKey("gsk_test_save_load")
    let loaded = store.loadGroqAPIKey()

    #expect(loaded == "gsk_test_save_load")
  }

  @Test func updateExistingKeyOverwritesValue() throws {
    try store.deleteGroqAPIKey()
    defer { try? store.deleteGroqAPIKey() }

    try store.saveGroqAPIKey("gsk_key_a")
    try store.saveGroqAPIKey("gsk_key_b")
    let loaded = store.loadGroqAPIKey()

    #expect(loaded == "gsk_key_b")
  }

  @Test func deleteRemovesKey() throws {
    try store.deleteGroqAPIKey()
    try store.saveGroqAPIKey("gsk_key_to_delete")
    try store.deleteGroqAPIKey()
    let loaded = store.loadGroqAPIKey()

    #expect(loaded == nil)
  }
}
