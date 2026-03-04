import Foundation

public struct PromptRefactorService: Sendable {
    public init() {}

    public func buildPrompt(from rawText: String, options: RefactorBuildOptions = .init()) -> String {
        let normalizedText = normalizeDictation(rawText)
        guard !normalizedText.isEmpty else {
            return ""
        }

        if let template = options.customTemplate {
            return template.replacingOccurrences(of: "{{task}}", with: normalizedText)
        }

        var lines: [String] = [
            "Task:",
            normalizedText,
            "",
            "Output requirements:",
            "- Rewrite this into a clear, actionable prompt for an AI assistant.",
            "- Keep the original intent, constraints, and requested outcome.",
            "- Use concise \(options.language).",
            "- Avoid adding assumptions that change meaning."
        ]

        lines.append(contentsOf: styleInstructions(options.style))

        if options.includeClarifyingQuestions {
            lines.append("- If critical details are missing, end with up to 2 clarifying questions.")
        }

        return lines.joined(separator: "\n")
    }

    public func normalizeDictation(_ rawText: String) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return ""
        }

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = stripFillerPhrases(from: text)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "([,.;:!?]){2,}", with: "$1", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        text = capitalizeFirstLetter(in: text)

        if let last = text.last, !".!?".contains(last) {
            text.append(".")
        }

        return text
    }

    private func styleInstructions(_ style: PromptStyle) -> [String] {
        switch style {
        case .general:
            return [
                "- Keep the result easy to scan with short sentences or bullets when useful."
            ]
        case .coding:
            return [
                "- Prefer technical precision and explicit implementation constraints.",
                "- Include expected inputs, outputs, and edge cases if implied."
            ]
        case .writing:
            return [
                "- Improve tone and readability while preserving the user's intent.",
                "- Keep style natural and audience-appropriate."
            ]
        }
    }

    private func stripFillerPhrases(from text: String) -> String {
        let patterns = [
            "(?i)\\b(um+|uh+|erm+|hmm+)\\b",
            "(?i)\\byou know\\b",
            "(?i)\\bkind of\\b",
            "(?i)\\bsort of\\b"
        ]

        return patterns.reduce(text) { current, pattern in
            current.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    private func capitalizeFirstLetter(in text: String) -> String {
        guard let firstLetterRange = text.range(of: "[A-Za-z]", options: .regularExpression) else {
            return text
        }

        var result = text
        let firstLetter = String(result[firstLetterRange]).uppercased()
        result.replaceSubrange(firstLetterRange, with: firstLetter)
        return result
    }
}
