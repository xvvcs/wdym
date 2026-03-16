import Foundation

public struct PromptRefactorService: Sendable {
  public init() {}

  public func buildPrompt(from rawText: String, options: RefactorBuildOptions = .init()) -> String {
    let normalizedText = normalizeDictation(rawText)
    guard !normalizedText.isEmpty else {
      return ""
    }

    let baseRequirements: [String]
    if options.style == .writing && options.customStylePrompt == nil {
      baseRequirements = [
        "- Rewrite this into polished, human-sounding text ready to publish or send.",
        "- Keep the original intent and meaning; do not add ideas the user did not express.",
        "- Use concise \(options.language).",
      ]
    } else {
      baseRequirements = [
        "- Rewrite this into a clear, actionable prompt for an AI assistant.",
        "- Keep the original intent, constraints, and requested outcome.",
        "- Use concise \(options.language).",
        "- Avoid adding assumptions that change meaning.",
      ]
    }

    var lines: [String] = [
      "Task:",
      normalizedText,
      "",
      "Output requirements:",
    ] + baseRequirements

    if let customInstructions = customStyleInstructions(from: options.customStylePrompt) {
      lines.append(customInstructions)
    } else {
      lines.append(contentsOf: styleInstructions(options.style))
    }

    if options.includeClarifyingQuestions {
      lines.append("- If critical details are missing, end with up to 2 clarifying questions.")
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
        // Structure: sharpen what the user actually said
        "- Restructure the prompt with a clear goal sentence first, followed by any constraints the user stated.",
        "- Preserve only the language, framework, version, and platform the user explicitly mentioned.",
        "- Separate context (what exists) from task (what to change) if the user provided both.",
        // Technical precision: clarify, don't invent
        "- Tighten technical language; replace vague words with precise programming terms.",
        "- Retain any inputs, outputs, types, or error conditions the user specified; do not invent new ones.",
        "- Carry forward any constraints or forbidden patterns the user stated; do not add assumptions.",
        // Tone and framing
        "- Frame the prompt as a direct technical instruction, not a conversation or question.",
        "- Use imperative voice: 'Implement', 'Refactor', 'Fix', 'Add', not 'Could you' or 'I want'.",
        "- Keep the prompt dense and scannable; remove filler without losing the user's meaning.",
      ]
    case .writing:
      return [
        // Voice and tone
        "- Rewrite in a clear, conversational tone as if explaining to one person, not an audience.",
        "- Use active voice; keep sentences short and direct; aim for 7th-grade readability or lower.",
        "- Preserve the user's intent, voice, and meaning exactly; do not add ideas they did not express.",
        // Natural rhythm and structure
        "- Vary sentence length dramatically: mix punchy two-word fragments with longer flowing clauses.",
        "- Alternate sentence starters; never begin consecutive sentences with the same word.",
        "- Vary paragraph length; allow single-sentence paragraphs for emphasis.",
        "- Start with a bold statement or mid-action; never open with a generic setup.",
        // Banned patterns
        "- Avoid these AI-sounding words and phrases: delve, leverage, craft, tapestry, game-changer, unlock, discover, utilize, groundbreaking, cutting-edge, remarkable, pivotal, intricate, illuminate, unveil, revolutionize, skyrocket, embark, realm, harness, shed light, in today's world, it's important to note, in the ever-evolving landscape, a testament to.",
        "- Strip filler transitions (moreover, furthermore, consequently, additionally); use natural bridges, abrupt shifts, or direct statements instead.",
        "- No em dashes, no semicolons, no clichés, no metaphors, no unnecessary adjectives or adverbs.",
        "- Avoid constructions like 'not just X, but also Y' and 'in conclusion' or 'in closing'.",
        // Authenticity
        "- Favor clarity over polish; allow slight imperfection; human writing is messy and leaves room for ambiguity.",
        "- Use rhetorical fragments and questions to improve readability (e.g. 'The good news?' or 'Here's the thing.').",
        "- Use specific, concrete details over broad claims; replace vague adjectives like 'effective' or 'significant' with precise terms.",
        "- Use 'you' and 'your' to address the reader directly; write as if speaking, not lecturing.",
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

  private func customStyleInstructions(from prompt: String?) -> String? {
    guard let prompt else {
      return nil
    }

    let sanitized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !sanitized.isEmpty else {
      return nil
    }

    return "- \(sanitized)"
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
