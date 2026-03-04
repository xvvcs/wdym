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
    var customPromptTemplate: String = ""

    var outputMode: OutputMode {
        OutputMode.from(rawValue: outputModeRawValue)
    }

    var promptStyle: PromptStyle {
        PromptStyle(rawValue: promptStyleRawValue) ?? .general
    }

    func buildOptions(language: String = "English") -> RefactorBuildOptions {
        let template = customPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        return RefactorBuildOptions(
            style: promptStyle,
            language: language,
            includeClarifyingQuestions: includeClarifyingQuestions,
            customTemplate: template.isEmpty ? nil : template
        )
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
        }
    }
}
