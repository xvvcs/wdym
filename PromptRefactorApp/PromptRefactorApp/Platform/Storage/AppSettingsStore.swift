import AppKit
import Combine
import Foundation
import PromptRefactorCore

struct AppSettings: Equatable {
  var outputModeRawValue: String
  var promptStyleRawValue: String
  var customPromptStyles: [CustomPromptStyle]
  var includeClarifyingQuestions: Bool
  var terminalModeEnabled: Bool
  var autoSelectAllOnTrigger: Bool
  var kittyRemoteControlRequired: Bool
  var kittyListenAddress: String
  var useGroqRefinement: Bool
  var groqModelRawValue: String
  var shortcutPresetRawValue: String
  var useCustomShortcut: Bool
  var customShortcutKeyCode: UInt16
  var customShortcutModifiersRawValue: UInt
  var styleSwitchShortcutKeyCode: UInt16
  var styleSwitchShortcutModifiersRawValue: UInt
  var autoRefactorOnPaste: Bool
  var pasteMonitorAllowedBundleIDs: [String]
  var soundCuesEnabled: Bool
  var checkForUpdatesEnabled: Bool

  static let `default` = AppSettings(
    outputModeRawValue: OutputMode.replaceAndCopy.rawValue,
    promptStyleRawValue: PromptStyle.general.rawValue,
    customPromptStyles: [],
    includeClarifyingQuestions: true,
    terminalModeEnabled: true,
    autoSelectAllOnTrigger: true,
    kittyRemoteControlRequired: true,
    kittyListenAddress: "unix:/tmp/prompt-refactor-kitty",
    useGroqRefinement: false,
    groqModelRawValue: GroqModel.llama31_8bInstant.rawValue,
    shortcutPresetRawValue: ShortcutPreset.commandShiftR.rawValue,
    useCustomShortcut: false,
    customShortcutKeyCode: ShortcutPreset.commandShiftR.binding.keyCode,
    customShortcutModifiersRawValue: ShortcutPreset.commandShiftR.binding.modifiersRawValue,
    styleSwitchShortcutKeyCode: 30,
    styleSwitchShortcutModifiersRawValue: HotkeyBinding(
      keyCode: 30,
      modifiers: [.command, .control]
    ).modifiersRawValue,
    autoRefactorOnPaste: false,
    pasteMonitorAllowedBundleIDs: [],
    soundCuesEnabled: true,
    checkForUpdatesEnabled: true
  )

  var shortcutPreset: ShortcutPreset {
    ShortcutPreset.from(rawValue: shortcutPresetRawValue)
  }

  var customShortcutBinding: HotkeyBinding {
    HotkeyBinding(
      keyCode: customShortcutKeyCode, modifiersRawValue: customShortcutModifiersRawValue)
  }

  var activeShortcutBinding: HotkeyBinding {
    useCustomShortcut ? customShortcutBinding : shortcutPreset.binding
  }

  var styleSwitchShortcutBinding: HotkeyBinding {
    HotkeyBinding(
      keyCode: styleSwitchShortcutKeyCode,
      modifiersRawValue: styleSwitchShortcutModifiersRawValue
    )
  }

  var promptStyleSelection: PromptStyleSelection {
    refactorPreferences.promptStyleSelection
  }

  var refactorPreferences: AppRefactorPreferences {
    AppRefactorPreferences(
      outputModeRawValue: outputModeRawValue,
      promptStyleRawValue: promptStyleRawValue,
      includeClarifyingQuestions: includeClarifyingQuestions,
      customPromptStyles: customPromptStyles
    )
  }
}

enum AddCustomPromptStyleResult: Equatable {
  case added(CustomPromptStyle)
  case invalidName
  case invalidPrompt
  case duplicateName
}

enum UpdateCustomPromptStyleResult: Equatable {
  case updated(CustomPromptStyle)
  case notFound
  case invalidName
  case invalidPrompt
  case duplicateName
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
    updateSettings { settings in
      settings.promptStyleRawValue = value
      Self.normalizePromptStyleSelection(&settings)
    }
  }

  @discardableResult
  func addCustomPromptStyle(name: String, prompt: String) -> AddCustomPromptStyleResult {
    let customPromptStyle: CustomPromptStyle
    switch Self.validatedCustomPromptStyle(name: name, prompt: prompt) {
    case .valid(let style):
      customPromptStyle = style
    case .invalidName:
      return .invalidName
    case .invalidPrompt:
      return .invalidPrompt
    }

    guard !settings.customPromptStyles.containsStyle(named: customPromptStyle.name) else {
      return .duplicateName
    }

    updateSettings { settings in
      settings.customPromptStyles.append(customPromptStyle)
      Self.normalizePromptStyleSelection(&settings)
    }

    return .added(customPromptStyle)
  }

  @discardableResult
  func updateCustomPromptStyle(
    originalName: String,
    name: String,
    prompt: String
  ) -> UpdateCustomPromptStyleResult {
    guard let sanitizedOriginalName = Self.sanitizedCustomPromptStyleName(originalName) else {
      return .notFound
    }

    let customPromptStyle: CustomPromptStyle
    switch Self.validatedCustomPromptStyle(name: name, prompt: prompt) {
    case .valid(let style):
      customPromptStyle = style
    case .invalidName:
      return .invalidName
    case .invalidPrompt:
      return .invalidPrompt
    }

    guard let index = settings.customPromptStyles.firstIndexOfStyle(named: sanitizedOriginalName)
    else {
      return .notFound
    }

    guard
      !settings.customPromptStyles.containsStyle(
        named: customPromptStyle.name,
        excluding: index
      )
    else {
      return .duplicateName
    }

    updateSettings { settings in
      let previousName = settings.customPromptStyles[index].name
      settings.customPromptStyles[index] = customPromptStyle

      if case .custom(let selectedName) = settings.promptStyleSelection,
        previousName.caseInsensitiveCompare(selectedName) == .orderedSame
      {
        settings.promptStyleRawValue =
          PromptStyleSelection.custom(name: customPromptStyle.name).rawValue
      }

      Self.normalizePromptStyleSelection(&settings)
    }

    return .updated(customPromptStyle)
  }

  @discardableResult
  func removeCustomPromptStyle(named name: String) -> Bool {
    guard let sanitizedName = Self.sanitizedCustomPromptStyleName(name) else {
      return false
    }

    guard settings.customPromptStyles.containsStyle(named: sanitizedName) else {
      return false
    }

    updateSettings { settings in
      settings.customPromptStyles.removeAll { $0.matches(name: sanitizedName) }
      Self.normalizePromptStyleSelection(&settings)
    }

    return true
  }

  func updatePromptStyleSelection(_ selection: PromptStyleSelection) {
    updatePromptStyleRawValue(selection.rawValue)
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

  func updateUseCustomShortcut(_ value: Bool) {
    updateSettings {
      $0.useCustomShortcut = value
    }
  }

  func updateCustomShortcut(_ binding: HotkeyBinding) {
    updateSettings {
      $0.customShortcutKeyCode = binding.keyCode
      $0.customShortcutModifiersRawValue = binding.modifiersRawValue
    }
  }

  func updateStyleSwitchShortcut(_ binding: HotkeyBinding) {
    updateSettings {
      $0.styleSwitchShortcutKeyCode = binding.keyCode
      $0.styleSwitchShortcutModifiersRawValue = binding.modifiersRawValue
    }
  }

  func updateGroqModelRawValue(_ value: String) {
    updateSettings {
      $0.groqModelRawValue = value
    }
  }

  func updateAutoRefactorOnPaste(_ value: Bool) {
    updateSettings { $0.autoRefactorOnPaste = value }
  }

  func updatePasteMonitorAllowedBundleIDs(_ ids: [String]) {
    updateSettings { $0.pasteMonitorAllowedBundleIDs = ids }
  }

  func addPasteMonitorAllowedBundleID(_ id: String) {
    guard !settings.pasteMonitorAllowedBundleIDs.contains(id) else { return }
    updateSettings { $0.pasteMonitorAllowedBundleIDs.append(id) }
  }

  func removePasteMonitorAllowedBundleID(_ id: String) {
    updateSettings { $0.pasteMonitorAllowedBundleIDs.removeAll { $0 == id } }
  }

  func updateSoundCuesEnabled(_ value: Bool) {
    updateSettings { $0.soundCuesEnabled = value }
  }

  func updateCheckForUpdatesEnabled(_ value: Bool) {
    updateSettings { $0.checkForUpdatesEnabled = value }
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
    userDefaults.set(
      encodeCustomPromptStyles(settings.customPromptStyles), forKey: Keys.customPromptStyles)
    userDefaults.set(settings.includeClarifyingQuestions, forKey: Keys.includeClarifyingQuestions)
    userDefaults.set(settings.terminalModeEnabled, forKey: Keys.terminalModeEnabled)
    userDefaults.set(settings.autoSelectAllOnTrigger, forKey: Keys.autoSelectAllOnTrigger)
    userDefaults.set(settings.kittyRemoteControlRequired, forKey: Keys.kittyRemoteControlRequired)
    userDefaults.set(settings.kittyListenAddress, forKey: Keys.kittyListenAddress)
    userDefaults.set(settings.useGroqRefinement, forKey: Keys.useGroqRefinement)
    userDefaults.set(settings.groqModelRawValue, forKey: Keys.groqModel)
    userDefaults.set(settings.shortcutPresetRawValue, forKey: Keys.shortcutPreset)
    userDefaults.set(settings.useCustomShortcut, forKey: Keys.useCustomShortcut)
    userDefaults.set(Int(settings.customShortcutKeyCode), forKey: Keys.customShortcutKeyCode)
    userDefaults.set(settings.customShortcutModifiersRawValue, forKey: Keys.customShortcutModifiers)
    userDefaults.set(
      Int(settings.styleSwitchShortcutKeyCode), forKey: Keys.styleSwitchShortcutKeyCode)
    userDefaults.set(
      settings.styleSwitchShortcutModifiersRawValue,
      forKey: Keys.styleSwitchShortcutModifiers
    )
    userDefaults.set(settings.autoRefactorOnPaste, forKey: Keys.autoRefactorOnPaste)
    userDefaults.set(
      settings.pasteMonitorAllowedBundleIDs, forKey: Keys.pasteMonitorAllowedBundleIDs)
    userDefaults.set(settings.soundCuesEnabled, forKey: Keys.soundCuesEnabled)
    userDefaults.set(settings.checkForUpdatesEnabled, forKey: Keys.checkForUpdatesEnabled)
  }

  private static func load(from userDefaults: UserDefaults) -> AppSettings {
    let outputMode =
      userDefaults.string(forKey: Keys.outputMode) ?? AppSettings.default.outputModeRawValue
    let promptStyle =
      userDefaults.string(forKey: Keys.promptStyle) ?? AppSettings.default.promptStyleRawValue

    let customPromptStyles = decodeCustomPromptStyles(
      userDefaults.data(forKey: Keys.customPromptStyles)
    )
    let normalizedPromptStyle = normalizedPromptStyleRawValue(
      promptStyle,
      customPromptStyles: customPromptStyles
    )

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

    let useCustomShortcut =
      userDefaults.object(forKey: Keys.useCustomShortcut) == nil
      ? AppSettings.default.useCustomShortcut
      : userDefaults.bool(forKey: Keys.useCustomShortcut)

    let customShortcutKeyCode =
      userDefaults.object(forKey: Keys.customShortcutKeyCode) == nil
      ? AppSettings.default.customShortcutKeyCode
      : UInt16(clamping: userDefaults.integer(forKey: Keys.customShortcutKeyCode))

    let customShortcutModifiersRawValue =
      userDefaults.object(forKey: Keys.customShortcutModifiers) == nil
      ? AppSettings.default.customShortcutModifiersRawValue
      : UInt(userDefaults.integer(forKey: Keys.customShortcutModifiers))

    let styleSwitchShortcutKeyCode =
      userDefaults.object(forKey: Keys.styleSwitchShortcutKeyCode) == nil
      ? AppSettings.default.styleSwitchShortcutKeyCode
      : UInt16(clamping: userDefaults.integer(forKey: Keys.styleSwitchShortcutKeyCode))

    let styleSwitchShortcutModifiersRawValue =
      userDefaults.object(forKey: Keys.styleSwitchShortcutModifiers) == nil
      ? AppSettings.default.styleSwitchShortcutModifiersRawValue
      : UInt(userDefaults.integer(forKey: Keys.styleSwitchShortcutModifiers))

    let autoRefactorOnPaste =
      userDefaults.object(forKey: Keys.autoRefactorOnPaste) == nil
      ? AppSettings.default.autoRefactorOnPaste
      : userDefaults.bool(forKey: Keys.autoRefactorOnPaste)

    let pasteMonitorAllowedBundleIDs =
      userDefaults.stringArray(forKey: Keys.pasteMonitorAllowedBundleIDs)
      ?? AppSettings.default.pasteMonitorAllowedBundleIDs

    let soundCuesEnabled =
      userDefaults.object(forKey: Keys.soundCuesEnabled) == nil
      ? AppSettings.default.soundCuesEnabled
      : userDefaults.bool(forKey: Keys.soundCuesEnabled)

    let checkForUpdatesEnabled =
      userDefaults.object(forKey: Keys.checkForUpdatesEnabled) == nil
      ? AppSettings.default.checkForUpdatesEnabled
      : userDefaults.bool(forKey: Keys.checkForUpdatesEnabled)

    return AppSettings(
      outputModeRawValue: outputMode,
      promptStyleRawValue: normalizedPromptStyle,
      customPromptStyles: customPromptStyles,
      includeClarifyingQuestions: includeClarifyingQuestions,
      terminalModeEnabled: terminalModeEnabled,
      autoSelectAllOnTrigger: autoSelectAllOnTrigger,
      kittyRemoteControlRequired: kittyRemoteControlRequired,
      kittyListenAddress: kittyListenAddress,
      useGroqRefinement: useGroqRefinement,
      groqModelRawValue: groqModel,
      shortcutPresetRawValue: shortcutPreset,
      useCustomShortcut: useCustomShortcut,
      customShortcutKeyCode: customShortcutKeyCode,
      customShortcutModifiersRawValue: customShortcutModifiersRawValue,
      styleSwitchShortcutKeyCode: styleSwitchShortcutKeyCode,
      styleSwitchShortcutModifiersRawValue: styleSwitchShortcutModifiersRawValue,
      autoRefactorOnPaste: autoRefactorOnPaste,
      pasteMonitorAllowedBundleIDs: pasteMonitorAllowedBundleIDs,
      soundCuesEnabled: soundCuesEnabled,
      checkForUpdatesEnabled: checkForUpdatesEnabled
    )
  }

  private func encodeCustomPromptStyles(_ styles: [CustomPromptStyle]) -> Data? {
    try? JSONEncoder().encode(styles)
  }

  private static func sanitize(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func sanitizedCustomPromptStyleName(_ name: String) -> String? {
    let sanitizedName = sanitize(name)
    return sanitizedName.isEmpty ? nil : sanitizedName
  }

  private static func validatedCustomPromptStyle(
    name: String,
    prompt: String
  ) -> ValidatedCustomPromptStyleResult {
    guard let sanitizedName = sanitizedCustomPromptStyleName(name) else {
      return .invalidName
    }

    let sanitizedPrompt = sanitize(prompt)
    guard !sanitizedPrompt.isEmpty else {
      return .invalidPrompt
    }

    return .valid(CustomPromptStyle(name: sanitizedName, prompt: sanitizedPrompt))
  }

  private static func decodeCustomPromptStyles(_ data: Data?) -> [CustomPromptStyle] {
    guard let data else {
      return AppSettings.default.customPromptStyles
    }

    return (try? JSONDecoder().decode([CustomPromptStyle].self, from: data))
      ?? AppSettings.default.customPromptStyles
  }

  private static func normalizedPromptStyleRawValue(
    _ rawValue: String,
    customPromptStyles: [CustomPromptStyle]
  ) -> String {
    if let builtIn = PromptStyle(rawValue: rawValue) {
      return builtIn.rawValue
    }

    guard case .custom(let selectedName)? = PromptStyleSelection.from(rawValue: rawValue) else {
      return AppSettings.default.promptStyleRawValue
    }

    if let match = customPromptStyles.firstStyle(named: selectedName) {
      return PromptStyleSelection.custom(name: match.name).rawValue
    }

    return AppSettings.default.promptStyleRawValue
  }

  private static func normalizePromptStyleSelection(_ settings: inout AppSettings) {
    settings.promptStyleRawValue = normalizedPromptStyleRawValue(
      settings.promptStyleRawValue,
      customPromptStyles: settings.customPromptStyles
    )
  }
}

private enum ValidatedCustomPromptStyleResult {
  case valid(CustomPromptStyle)
  case invalidName
  case invalidPrompt
}

private enum Keys {
  static let outputMode = "outputMode"
  static let promptStyle = "promptStyle"
  static let customPromptStyles = "customPromptStyles"
  static let includeClarifyingQuestions = "includeClarifyingQuestions"
  static let terminalModeEnabled = "terminalModeEnabled"
  static let autoSelectAllOnTrigger = "autoSelectAllOnTrigger"
  static let kittyRemoteControlRequired = "kittyRemoteControlRequired"
  static let kittyListenAddress = "kittyListenAddress"
  static let useGroqRefinement = "useGroqRefinement"
  static let groqModel = "groqModel"
  static let shortcutPreset = "shortcutPreset"
  static let useCustomShortcut = "useCustomShortcut"
  static let customShortcutKeyCode = "customShortcutKeyCode"
  static let customShortcutModifiers = "customShortcutModifiers"
  static let styleSwitchShortcutKeyCode = "styleSwitchShortcutKeyCode"
  static let styleSwitchShortcutModifiers = "styleSwitchShortcutModifiers"
  static let autoRefactorOnPaste = "autoRefactorOnPaste"
  static let pasteMonitorAllowedBundleIDs = "pasteMonitorAllowedBundleIDs"
  static let soundCuesEnabled = "soundCuesEnabled"
  static let checkForUpdatesEnabled = "checkForUpdatesEnabled"
}
