import Combine
import Foundation
import PromptRefactorCore

struct AppSettings: Equatable {
  var outputModeRawValue: String
  var promptStyleRawValue: String
  var includeClarifyingQuestions: Bool
  var terminalModeEnabled: Bool
  var autoSelectAllOnTrigger: Bool
  var kittyRemoteControlRequired: Bool
  var kittyListenAddress: String
  var useGroqRefinement: Bool
  var groqModelRawValue: String
  var shortcutPresetRawValue: String

  static let `default` = AppSettings(
    outputModeRawValue: OutputMode.replaceAndCopy.rawValue,
    promptStyleRawValue: PromptStyle.general.rawValue,
    includeClarifyingQuestions: true,
    terminalModeEnabled: true,
    autoSelectAllOnTrigger: true,
    kittyRemoteControlRequired: true,
    kittyListenAddress: "unix:/tmp/prompt-refactor-kitty",
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
    updateSettings {
      $0.outputModeRawValue = value
    }
  }

  func updatePromptStyleRawValue(_ value: String) {
    updateSettings {
      $0.promptStyleRawValue = value
    }
  }

  func updateIncludeClarifyingQuestions(_ value: Bool) {
    updateSettings {
      $0.includeClarifyingQuestions = value
    }
  }

  func updateTerminalModeEnabled(_ value: Bool) {
    updateSettings {
      $0.terminalModeEnabled = value
    }
  }

  func updateAutoSelectAllOnTrigger(_ value: Bool) {
    updateSettings {
      $0.autoSelectAllOnTrigger = value
    }
  }

  func updateKittyRemoteControlRequired(_ value: Bool) {
    updateSettings {
      $0.kittyRemoteControlRequired = value
    }
  }

  func updateKittyListenAddress(_ value: String) {
    let sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = sanitized.isEmpty ? AppSettings.default.kittyListenAddress : sanitized
    updateSettings {
      $0.kittyListenAddress = normalized
    }
  }

  func updateUseGroqRefinement(_ value: Bool) {
    updateSettings {
      $0.useGroqRefinement = value
    }
  }

  func updateShortcutPresetRawValue(_ value: String) {
    updateSettings {
      $0.shortcutPresetRawValue = value
    }
  }

  func updateGroqModelRawValue(_ value: String) {
    updateSettings {
      $0.groqModelRawValue = value
    }
  }

  private func updateSettings(_ mutation: (inout AppSettings) -> Void) {
    var updated = settings
    mutation(&updated)
    guard updated != settings else {
      return
    }

    settings = updated
    persist(updated)
  }

  private func persist(_ settings: AppSettings) {
    userDefaults.set(settings.outputModeRawValue, forKey: Keys.outputMode)
    userDefaults.set(settings.promptStyleRawValue, forKey: Keys.promptStyle)
    userDefaults.set(settings.includeClarifyingQuestions, forKey: Keys.includeClarifyingQuestions)
    userDefaults.set(settings.terminalModeEnabled, forKey: Keys.terminalModeEnabled)
    userDefaults.set(settings.autoSelectAllOnTrigger, forKey: Keys.autoSelectAllOnTrigger)
    userDefaults.set(settings.kittyRemoteControlRequired, forKey: Keys.kittyRemoteControlRequired)
    userDefaults.set(settings.kittyListenAddress, forKey: Keys.kittyListenAddress)
    userDefaults.set(settings.useGroqRefinement, forKey: Keys.useGroqRefinement)
    userDefaults.set(settings.groqModelRawValue, forKey: Keys.groqModel)
    userDefaults.set(settings.shortcutPresetRawValue, forKey: Keys.shortcutPreset)
  }

  private static func load(from userDefaults: UserDefaults) -> AppSettings {
    let outputMode =
      userDefaults.string(forKey: Keys.outputMode) ?? AppSettings.default.outputModeRawValue
    let promptStyle =
      userDefaults.string(forKey: Keys.promptStyle) ?? AppSettings.default.promptStyleRawValue

    let includeClarifyingQuestions =
      userDefaults.object(forKey: Keys.includeClarifyingQuestions) == nil
      ? AppSettings.default.includeClarifyingQuestions
      : userDefaults.bool(forKey: Keys.includeClarifyingQuestions)

    let terminalModeEnabled =
      userDefaults.object(forKey: Keys.terminalModeEnabled) == nil
      ? AppSettings.default.terminalModeEnabled
      : userDefaults.bool(forKey: Keys.terminalModeEnabled)

    let autoSelectAllOnTrigger =
      userDefaults.object(forKey: Keys.autoSelectAllOnTrigger) == nil
      ? AppSettings.default.autoSelectAllOnTrigger
      : userDefaults.bool(forKey: Keys.autoSelectAllOnTrigger)

    let kittyRemoteControlRequired =
      userDefaults.object(forKey: Keys.kittyRemoteControlRequired) == nil
      ? AppSettings.default.kittyRemoteControlRequired
      : userDefaults.bool(forKey: Keys.kittyRemoteControlRequired)

    let kittyListenAddress = {
      let persisted = userDefaults.string(forKey: Keys.kittyListenAddress) ?? ""
      let sanitized = persisted.trimmingCharacters(in: .whitespacesAndNewlines)
      return sanitized.isEmpty ? AppSettings.default.kittyListenAddress : sanitized
    }()

    let useGroqRefinement =
      userDefaults.object(forKey: Keys.useGroqRefinement) == nil
      ? AppSettings.default.useGroqRefinement
      : userDefaults.bool(forKey: Keys.useGroqRefinement)

    let groqModel =
      userDefaults.string(forKey: Keys.groqModel) ?? AppSettings.default.groqModelRawValue

    let shortcutPreset =
      userDefaults.string(forKey: Keys.shortcutPreset) ?? AppSettings.default.shortcutPresetRawValue

    return AppSettings(
      outputModeRawValue: outputMode,
      promptStyleRawValue: promptStyle,
      includeClarifyingQuestions: includeClarifyingQuestions,
      terminalModeEnabled: terminalModeEnabled,
      autoSelectAllOnTrigger: autoSelectAllOnTrigger,
      kittyRemoteControlRequired: kittyRemoteControlRequired,
      kittyListenAddress: kittyListenAddress,
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
  static let terminalModeEnabled = "terminalModeEnabled"
  static let autoSelectAllOnTrigger = "autoSelectAllOnTrigger"
  static let kittyRemoteControlRequired = "kittyRemoteControlRequired"
  static let kittyListenAddress = "kittyListenAddress"
  static let useGroqRefinement = "useGroqRefinement"
  static let groqModel = "groqModel"
  static let shortcutPreset = "shortcutPreset"
}
