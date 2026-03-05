import AppKit
import Combine
import Foundation
import PromptRefactorCore
import Testing

@testable import PromptRefactorApp

@MainActor
struct AppSettingsStoreTests {
  @Test func storeLoadsExpectedDefaultValues() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(store.settings == .default)
  }

  @Test func storePersistsUpdatedValuesAcrossInstances() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    store.updateOutputModeRawValue(OutputMode.copyOnly.rawValue)
    store.updatePromptStyleRawValue("coding")
    store.updateIncludeClarifyingQuestions(false)
    store.updateTerminalModeEnabled(false)
    store.updateAutoSelectAllOnTrigger(false)
    store.updateKittyRemoteControlRequired(false)
    store.updateKittyListenAddress("unix:/tmp/custom-kitty")
    store.updateUseGroqRefinement(true)
    store.updateGroqModelRawValue(GroqModel.llama33_70bVersatile.rawValue)
    store.updateShortcutPresetRawValue(ShortcutPreset.commandOptionR.rawValue)
    store.updateUseCustomShortcut(true)
    store.updateCustomShortcut(HotkeyBinding(keyCode: 17, modifiers: [.command, .option]))
    store.updateStyleSwitchShortcut(HotkeyBinding(keyCode: 2, modifiers: [.command, .control]))

    let reloaded = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(reloaded.settings.outputModeRawValue == OutputMode.copyOnly.rawValue)
    #expect(reloaded.settings.promptStyleRawValue == "coding")
    #expect(!reloaded.settings.includeClarifyingQuestions)
    #expect(!reloaded.settings.terminalModeEnabled)
    #expect(!reloaded.settings.autoSelectAllOnTrigger)
    #expect(!reloaded.settings.kittyRemoteControlRequired)
    #expect(reloaded.settings.kittyListenAddress == "unix:/tmp/custom-kitty")
    #expect(reloaded.settings.useGroqRefinement)
    #expect(reloaded.settings.groqModelRawValue == GroqModel.llama33_70bVersatile.rawValue)
    #expect(reloaded.settings.shortcutPresetRawValue == ShortcutPreset.commandOptionR.rawValue)
    #expect(reloaded.settings.useCustomShortcut)
    #expect(
      reloaded.settings.customShortcutBinding
        == HotkeyBinding(keyCode: 17, modifiers: [.command, .option]))
    #expect(
      reloaded.settings.styleSwitchShortcutBinding
        == HotkeyBinding(keyCode: 2, modifiers: [.command, .control]))
    #expect(
      reloaded.settings.activeShortcutBinding
        == HotkeyBinding(keyCode: 17, modifiers: [.command, .option]))
  }

  @Test func addCustomPromptStyleIgnoresEmptyNameOrPrompt() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    let emptyNameResult = store.addCustomPromptStyle(name: "   ", prompt: "Valid prompt")
    let emptyPromptResult = store.addCustomPromptStyle(name: "Valid", prompt: "\n\t")

    #expect(emptyNameResult == .invalidName)
    #expect(emptyPromptResult == .invalidPrompt)
    #expect(store.settings.customPromptStyles.isEmpty)
  }

  @Test func addDuplicateCustomPromptStyleNameIsIgnoredCaseInsensitive() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    let firstResult = store.addCustomPromptStyle(name: "My Style", prompt: "First")
    let duplicateResult = store.addCustomPromptStyle(name: "my style", prompt: "Second")

    #expect(firstResult == .added(makeCustomPromptStyle(name: "My Style", prompt: "First")))
    #expect(duplicateResult == .duplicateName)
    #expect(store.settings.customPromptStyles.count == 1)
    #expect(store.settings.customPromptStyles.first?.prompt == "First")
  }

  @Test func addCustomPromptStyleCreatesAndReloadsFromPersistence() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    let result = store.addCustomPromptStyle(
      name: "  Incident Responder  ",
      prompt: "  Prioritize timeline, impact, and mitigation steps.  "
    )

    #expect(
      result
        == .added(
          makeCustomPromptStyle(
            name: "Incident Responder",
            prompt: "Prioritize timeline, impact, and mitigation steps."
          )
        )
    )
    #expect(store.settings.customPromptStyles.count == 1)
    #expect(store.settings.customPromptStyles.first?.name == "Incident Responder")
    #expect(
      store.settings.customPromptStyles.first?.prompt
        == "Prioritize timeline, impact, and mitigation steps.")

    let reloaded = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(reloaded.settings.customPromptStyles.count == 1)
    #expect(reloaded.settings.customPromptStyles.first?.name == "Incident Responder")
    #expect(
      reloaded.settings.customPromptStyles.first?.prompt
        == "Prioritize timeline, impact, and mitigation steps.")
  }

  @Test func updateCustomPromptStyleRenamesAndUpdatesPrompt() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    _ = store.addCustomPromptStyle(name: "Research", prompt: "Original prompt")
    store.updatePromptStyleRawValue(PromptStyleSelection.custom(name: "Research").rawValue)

    let result = store.updateCustomPromptStyle(
      originalName: "Research",
      name: "Research Deep Dive",
      prompt: "Updated prompt"
    )

    #expect(
      result
        == .updated(makeCustomPromptStyle(name: "Research Deep Dive", prompt: "Updated prompt"))
    )
    #expect(store.settings.customPromptStyles.count == 1)
    #expect(store.settings.customPromptStyles.first?.name == "Research Deep Dive")
    #expect(store.settings.customPromptStyles.first?.prompt == "Updated prompt")
    #expect(
      store.settings.promptStyleRawValue
        == PromptStyleSelection.custom(name: "Research Deep Dive").rawValue)
  }

  @Test func updateCustomPromptStyleRejectsDuplicateName() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    _ = store.addCustomPromptStyle(name: "Alpha", prompt: "A")
    _ = store.addCustomPromptStyle(name: "Beta", prompt: "B")

    let result = store.updateCustomPromptStyle(
      originalName: "Beta",
      name: "alpha",
      prompt: "Updated"
    )

    #expect(result == .duplicateName)
    #expect(store.settings.customPromptStyles.count == 2)
    #expect(store.settings.customPromptStyles.first(where: { $0.name == "Beta" })?.prompt == "B")
  }

  @Test func removeCustomPromptStyleRemovesEntryAndFallsBackSelection() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    _ = store.addCustomPromptStyle(name: "Delete Me", prompt: "Soon removed")
    store.updatePromptStyleRawValue(PromptStyleSelection.custom(name: "Delete Me").rawValue)

    let removed = store.removeCustomPromptStyle(named: "delete me")

    #expect(removed)
    #expect(store.settings.customPromptStyles.isEmpty)
    #expect(store.settings.promptStyleRawValue == PromptStyle.general.rawValue)
  }

  @Test func storeFallsBackToGeneralWhenPersistedCustomPromptStyleIsMissing() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    fixture.userDefaults.set("custom:missing-style", forKey: "promptStyle")

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(store.settings.promptStyleRawValue == PromptStyle.general.rawValue)
  }

  @Test func storeCanonicalizesPersistedCustomPromptStyleSelectionCasing() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let styles = [CustomPromptStyle(name: "Incident Responder", prompt: "Prompt")]
    fixture.userDefaults.set(try? JSONEncoder().encode(styles), forKey: "customPromptStyles")
    fixture.userDefaults.set("custom:incident responder", forKey: "promptStyle")

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(
      store.settings.promptStyleRawValue
        == PromptStyleSelection.custom(name: "Incident Responder").rawValue)
  }

  @Test func settingsShortcutPresetFallsBackWhenPersistedValueIsInvalid() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    fixture.userDefaults.set("invalid", forKey: "shortcutPreset")
    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(store.settings.shortcutPreset == ShortcutPreset.commandShiftR)
  }

  @Test func storeDefaultsEnableTerminalModeAndAutoSelectAll() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(store.settings.terminalModeEnabled)
    #expect(store.settings.autoSelectAllOnTrigger)
    #expect(store.settings.kittyRemoteControlRequired)
    #expect(store.settings.kittyListenAddress == "unix:/tmp/prompt-refactor-kitty")
    #expect(!store.settings.useCustomShortcut)
    #expect(store.settings.activeShortcutBinding == ShortcutPreset.commandShiftR.binding)
    #expect(
      store.settings.styleSwitchShortcutBinding
        == HotkeyBinding(keyCode: 30, modifiers: [.command, .control]))
  }

  @Test func storePublishesUpdatedSettingsImmediately() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    var updates: [AppSettings] = []
    let cancellable = store.$settings
      .dropFirst()
      .sink { updates.append($0) }

    store.updateOutputModeRawValue(OutputMode.copyOnly.rawValue)

    #expect(updates.count == 1)
    #expect(updates.first?.outputModeRawValue == OutputMode.copyOnly.rawValue)
    withExtendedLifetime(cancellable) {}
  }

  @Test func storePublishesForEveryDistinctSettingChange() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    var updates: [AppSettings] = []
    let cancellable = store.$settings
      .dropFirst()
      .sink { updates.append($0) }

    store.updateTerminalModeEnabled(false)
    store.updateAutoSelectAllOnTrigger(false)
    store.updateUseGroqRefinement(true)

    #expect(updates.count == 3)
    #expect(updates.last?.terminalModeEnabled == false)
    #expect(updates.last?.autoSelectAllOnTrigger == false)
    #expect(updates.last?.useGroqRefinement == true)
    withExtendedLifetime(cancellable) {}
  }

  @Test func storeDoesNotPublishWhenValueDoesNotChange() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    var updates: [AppSettings] = []
    let cancellable = store.$settings
      .dropFirst()
      .sink { updates.append($0) }

    store.updateTerminalModeEnabled(AppSettings.default.terminalModeEnabled)
    store.updateOutputModeRawValue(AppSettings.default.outputModeRawValue)

    #expect(updates.isEmpty)
    withExtendedLifetime(cancellable) {}
  }

  private func testUserDefaults() -> TestDefaultsFixture {
    let suiteName = "PromptRefactorAppTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    return TestDefaultsFixture(userDefaults: userDefaults, suiteName: suiteName)
  }

  private func clear(_ fixture: TestDefaultsFixture) {
    fixture.userDefaults.removePersistentDomain(forName: fixture.suiteName)
  }

  private func makeCustomPromptStyle(name: String, prompt: String) -> CustomPromptStyle {
    CustomPromptStyle(name: name, prompt: prompt)
  }
}

private struct TestDefaultsFixture {
  let userDefaults: UserDefaults
  let suiteName: String
}
