import Foundation
import PromptRefactorCore

enum OutputMode: String, CaseIterable, Identifiable {
  case replaceAndCopy
  case replaceOnly
  case copyOnly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .replaceAndCopy:
      return "Replace + Copy"
    case .replaceOnly:
      return "Replace only"
    case .copyOnly:
      return "Copy only"
    }
  }

  var shouldReplaceText: Bool {
    self != .copyOnly
  }

  var shouldCopyText: Bool {
    self != .replaceOnly
  }

  static func from(rawValue: String) -> OutputMode {
    OutputMode(rawValue: rawValue) ?? .replaceAndCopy
  }
}

struct AppRefactorPreferences {
  var outputModeRawValue: String = OutputMode.replaceAndCopy.rawValue
  var promptStyleRawValue: String = PromptStyle.general.rawValue
  var includeClarifyingQuestions = true
  var customPromptStyles: [CustomPromptStyle] = []

  var outputMode: OutputMode {
    OutputMode.from(rawValue: outputModeRawValue)
  }

  var promptStyleSelection: PromptStyleSelection {
    PromptStyleSelection.from(rawValue: promptStyleRawValue) ?? .builtIn(.general)
  }

  var promptStyle: PromptStyle {
    switch promptStyleSelection {
    case .builtIn(let style):
      return style
    case .custom:
      return .general
    }
  }

  var customStylePrompt: String? {
    guard case .custom(let name) = promptStyleSelection else {
      return nil
    }

    return customPromptStyles.firstStyle(named: name)?.prompt
  }

  func buildOptions(language: String = "English") -> RefactorBuildOptions {
    RefactorBuildOptions(
      style: promptStyle,
      language: language,
      includeClarifyingQuestions: includeClarifyingQuestions,
      customStylePrompt: customStylePrompt
    )
  }
}

struct CustomPromptStyle: Codable, Equatable, Identifiable {
  let name: String
  let prompt: String

  var id: String {
    name
  }

  func matches(name: String) -> Bool {
    self.name.caseInsensitiveCompare(name) == .orderedSame
  }
}

struct PromptStyleChoice: Identifiable, Equatable {
  let selection: PromptStyleSelection
  let title: String
  let subtitle: String

  var id: PromptStyleSelection {
    selection
  }
}

enum PromptStyleSelection: Hashable {
  static let customPrefix = "custom:"

  case builtIn(PromptStyle)
  case custom(name: String)

  var rawValue: String {
    switch self {
    case .builtIn(let style):
      return style.rawValue
    case .custom(let name):
      return Self.customPrefix + name
    }
  }

  static func from(rawValue: String) -> PromptStyleSelection? {
    if let style = PromptStyle(rawValue: rawValue) {
      return .builtIn(style)
    }

    guard rawValue.hasPrefix(customPrefix) else {
      return nil
    }

    let name = String(rawValue.dropFirst(customPrefix.count))
    guard !name.isEmpty else {
      return nil
    }

    return .custom(name: name)
  }
}

extension Array where Element == CustomPromptStyle {
  func firstStyle(named name: String) -> CustomPromptStyle? {
    first { $0.matches(name: name) }
  }

  func firstIndexOfStyle(named name: String) -> Int? {
    firstIndex { $0.matches(name: name) }
  }

  func containsStyle(named name: String, excluding excludedIndex: Int? = nil) -> Bool {
    enumerated().contains { index, style in
      guard index != excludedIndex else {
        return false
      }

      return style.matches(name: name)
    }
  }
}

extension PromptStyle {
  var displayTitle: String {
    switch self {
    case .general:
      return "General"
    case .coding:
      return "Coding"
    case .writing:
      return "Writing"
    case .search:
      return "Search"
    case .research:
      return "Research"
    case .bestPractices:
      return "Best Practices"
    }
  }

  var shortDescription: String {
    switch self {
    case .general:
      return "Balanced cleanup for everyday prompts"
    case .coding:
      return "Technical precision with implementation details"
    case .writing:
      return "Tone and readability improvements"
    case .search:
      return "Keyword-dense search phrasing"
    case .research:
      return "Scoped investigation with depth and evidence"
    case .bestPractices:
      return "Ranked recommendations with rationale"
    }
  }
}

extension PromptStyleSelection {
  func displayTitle(customPromptStyles: [CustomPromptStyle]) -> String {
    switch self {
    case .builtIn(let style):
      return style.displayTitle
    case .custom(let name):
      return customPromptStyles.firstStyle(named: name)?.name ?? name
    }
  }

  func subtitle(customPromptStyles: [CustomPromptStyle]) -> String {
    switch self {
    case .builtIn(let style):
      return style.shortDescription
    case .custom(let name):
      guard let style = customPromptStyles.firstStyle(named: name) else {
        return "Custom prompt instructions"
      }

      let summary = style.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
      return summary.isEmpty ? "Custom prompt instructions" : summary
    }
  }
}

func buildPromptStyleChoices(customPromptStyles: [CustomPromptStyle]) -> [PromptStyleChoice] {
  let builtIn = PromptStyle.allCases.map {
    PromptStyleChoice(
      selection: .builtIn($0),
      title: $0.displayTitle,
      subtitle: $0.shortDescription
    )
  }

  let custom = customPromptStyles.map {
    PromptStyleChoice(
      selection: .custom(name: $0.name),
      title: "\($0.name) (Custom)",
      subtitle: $0.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  return builtIn + custom
}
