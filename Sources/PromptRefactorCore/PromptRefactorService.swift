import Foundation

public struct PromptRefactorService: Sendable {
    public init() {}

    public func buildPrompt(from rawText: String, options: RefactorBuildOptions = .init()) -> String
    {
        let normalizedText = normalizeDictation(rawText)
        guard !normalizedText.isEmpty else {
            return ""
        }

        var lines: [String] = [
            "Task:",
            normalizedText,
            "",
            "Output requirements:",
            "- Rewrite this into a clear, actionable prompt for an AI assistant.",
            "- Keep the original intent, constraints, and requested outcome.",
            "- Use concise \(options.language).",
            "- Avoid adding assumptions that change meaning.",
        ]

        lines.append(contentsOf: styleInstructions(options.style))

        if options.includeClarifyingQuestions {
            lines.append(
                "- If critical details are missing, end with up to 2 clarifying questions.")
        }

        return lines.joined(separator: "\n")
    }

    /// Cleans refactored output by stripping leading/trailing double quotes and collapsing
    /// extra whitespace. Preserves parenthesized content to avoid removing meaningful
    /// constraints, qualifiers, or semantic annotations from the prompt.
    public func clarifyPrompt(_ outputText: String) -> String {
        var text = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return ""
        }

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        while text.hasPrefix("\"") {
            text = String(text.dropFirst())
        }
        while text.hasSuffix("\"") {
            text = String(text.dropLast())
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    public func normalizeDictation(_ rawText: String) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return ""
        }

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = stripFillerPhrases(from: text)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(
            of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(
            of: "([,.;:!?]){2,}", with: "$1", options: .regularExpression)
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
                "- Include expected inputs, outputs, and edge cases if implied.",
            ]
        case .writing:
            return [
                "- Improve tone and readability while preserving the user's intent.",
                "- Keep style natural and audience-appropriate.",
            ]
        case .search:
            return [
                "- Output a keyword-dense noun phrase; strip all conversational framing and filler words.",
                "- Retain subject nouns, qualifiers, and intent modifiers only; target 5–10 words.",
                "- Embed technical qualifiers (language, platform, version) inline; omit trailing punctuation.",
            ]
        case .research:
            return [
                "- Frame the core question with a clear subject, investigation focus, and desired outcome.",
                "- Specify scope and depth requirements before the topic statement.",
                "- Flag uncertain claims explicitly; distinguish established facts from emerging evidence.",
            ]
        case .bestPractices:
            return [
                "- Anchor recommendations in the specific domain, stack, and audience expertise level.",
                "- Pair each recommendation with a one-sentence rationale explaining why it matters.",
                "- Request ranked or tiered output (essential vs. optional) with an explicit scope constraint.",
            ]
        }
    }

    private func stripFillerPhrases(from text: String) -> String {
        let patterns = [
            "(?i)\\b(um+|uh+|erm+|hmm+)\\b",
            "(?i)\\byou know\\b",
            "(?i)\\bkind of\\b",
            "(?i)\\bsort of\\b",
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
