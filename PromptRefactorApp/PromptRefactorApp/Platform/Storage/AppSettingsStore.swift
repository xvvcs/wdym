import Combine
import Foundation
import PromptRefactorCore

struct AppSettings: Equatable {
    var outputModeRawValue: String
    var promptStyleRawValue: String
    var includeClarifyingQuestions: Bool
    var useGroqRefinement: Bool
    var groqModelRawValue: String
    var shortcutPresetRawValue: String

    static let `default` = AppSettings(
        outputModeRawValue: OutputMode.replaceAndCopy.rawValue,
        promptStyleRawValue: PromptStyle.general.rawValue,
        includeClarifyingQuestions: true,
        useGroqRefinement: false,
        groqModelRawValue: GroqModel.llama31_8bInstant.rawValue,
        shortcutPresetRawValue: ShortcutPreset.commandShiftR.rawValue
    )

    var shortcutPreset: ShortcutPreset {
        ShortcutPreset.from(rawValue: shortcutPresetRawValue)
    }

    var refactorPreferences: AppRefactorPreferences {
        AppRefactorPreferences(
            outputModeRawValue: outputModeRawValue,
            promptStyleRawValue: promptStyleRawValue,
            includeClarifyingQuestions: includeClarifyingQuestions
        )
    }
}

final class UserDefaultsAppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.load(from: userDefaults)
    }

    func updateOutputModeRawValue(_ value: String) {
        settings.outputModeRawValue = value
        persist()
    }

    func updatePromptStyleRawValue(_ value: String) {
        settings.promptStyleRawValue = value
        persist()
    }

    func updateIncludeClarifyingQuestions(_ value: Bool) {
        settings.includeClarifyingQuestions = value
        persist()
    }

    func updateUseGroqRefinement(_ value: Bool) {
        settings.useGroqRefinement = value
        persist()
    }

    func updateShortcutPresetRawValue(_ value: String) {
        settings.shortcutPresetRawValue = value
        persist()
    }

    func updateGroqModelRawValue(_ value: String) {
        settings.groqModelRawValue = value
        persist()
    }

    private func persist() {
        userDefaults.set(settings.outputModeRawValue, forKey: Keys.outputMode)
        userDefaults.set(settings.promptStyleRawValue, forKey: Keys.promptStyle)
        userDefaults.set(settings.includeClarifyingQuestions, forKey: Keys.includeClarifyingQuestions)
        userDefaults.set(settings.useGroqRefinement, forKey: Keys.useGroqRefinement)
        userDefaults.set(settings.groqModelRawValue, forKey: Keys.groqModel)
        userDefaults.set(settings.shortcutPresetRawValue, forKey: Keys.shortcutPreset)
    }

    private static func load(from userDefaults: UserDefaults) -> AppSettings {
        let outputMode = userDefaults.string(forKey: Keys.outputMode) ?? AppSettings.default.outputModeRawValue
        let promptStyle = userDefaults.string(forKey: Keys.promptStyle) ?? AppSettings.default.promptStyleRawValue

        let includeClarifyingQuestions = userDefaults.object(forKey: Keys.includeClarifyingQuestions) == nil
            ? AppSettings.default.includeClarifyingQuestions
            : userDefaults.bool(forKey: Keys.includeClarifyingQuestions)

        let useGroqRefinement = userDefaults.object(forKey: Keys.useGroqRefinement) == nil
            ? AppSettings.default.useGroqRefinement
            : userDefaults.bool(forKey: Keys.useGroqRefinement)

        let groqModel = userDefaults.string(forKey: Keys.groqModel) ?? AppSettings.default.groqModelRawValue

        let shortcutPreset = userDefaults.string(forKey: Keys.shortcutPreset) ?? AppSettings.default.shortcutPresetRawValue

        return AppSettings(
            outputModeRawValue: outputMode,
            promptStyleRawValue: promptStyle,
            includeClarifyingQuestions: includeClarifyingQuestions,
            useGroqRefinement: useGroqRefinement,
            groqModelRawValue: groqModel,
            shortcutPresetRawValue: shortcutPreset
        )
    }
}

private enum Keys {
    static let outputMode = "outputMode"
    static let promptStyle = "promptStyle"
    static let includeClarifyingQuestions = "includeClarifyingQuestions"
    static let useGroqRefinement = "useGroqRefinement"
    static let groqModel = "groqModel"
    static let shortcutPreset = "shortcutPreset"
}
