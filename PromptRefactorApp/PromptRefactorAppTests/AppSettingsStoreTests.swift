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
        store.updateUseGroqRefinement(true)
        store.updateGroqModelRawValue(GroqModel.llama33_70bVersatile.rawValue)
        store.updateShortcutPresetRawValue(ShortcutPreset.commandOptionR.rawValue)

        let reloaded = UserDefaultsAppSettingsStore(userDefaults: fixture.userDefaults)

        #expect(reloaded.settings.outputModeRawValue == OutputMode.copyOnly.rawValue)
        #expect(reloaded.settings.promptStyleRawValue == "coding")
        #expect(!reloaded.settings.includeClarifyingQuestions)
        #expect(!reloaded.settings.terminalModeEnabled)
        #expect(!reloaded.settings.autoSelectAllOnTrigger)
        #expect(reloaded.settings.useGroqRefinement)
        #expect(reloaded.settings.groqModelRawValue == GroqModel.llama33_70bVersatile.rawValue)
        #expect(reloaded.settings.shortcutPresetRawValue == ShortcutPreset.commandOptionR.rawValue)
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
