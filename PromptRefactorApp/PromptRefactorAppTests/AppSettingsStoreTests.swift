import AppKit
import Combine
import Foundation
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
    #expect(reloaded.settings.customShortcutBinding == HotkeyBinding(keyCode: 17, modifiers: [.command, .option]))
    #expect(reloaded.settings.activeShortcutBinding == HotkeyBinding(keyCode: 17, modifiers: [.command, .option]))
  }

  @Test func storePersistsCustomPromptTemplate() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)
    store.updateCustomPromptTemplate("My template: {{task}}")

    let reloaded = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(reloaded.settings.customPromptTemplate == "My template: {{task}}")
  }

  @Test func storeDefaultsCustomPromptTemplateToEmpty() {
    let fixture = testUserDefaults()
    defer { clear(fixture) }

    let store = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

    #expect(store.settings.customPromptTemplate == "")
  }
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
}

private struct TestDefaultsFixture {
  let userDefaults: UserDefaults
  let suiteName: String
}
