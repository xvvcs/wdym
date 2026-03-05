import Testing

@testable import PromptRefactorCore

@Test func normalizeDictationRemovesFillerWordsAndCleansSpacing() {
  let service = PromptRefactorService()
  let raw =
    " um   write an sql query to list active users from last 30 days uh and sort by signup date "

  let normalized = service.normalizeDictation(raw)

  #expect(
    normalized
      == "Write an sql query to list active users from last 30 days and sort by signup date."
  )
}

@Test func normalizeDictationAddsTerminalPunctuationIfMissing() {
  let service = PromptRefactorService()
  let raw = "please summarize this meeting and list next steps"

  let normalized = service.normalizeDictation(raw)

  #expect(normalized == "Please summarize this meeting and list next steps.")
}

@Test func buildPromptReturnsEmptyStringForEmptyInput() {
  let service = PromptRefactorService()
  let result = service.buildPrompt(from: "   ")

  #expect(result == "")
}

@Test func buildPromptIncludesCodingSpecificInstructions() {
  let service = PromptRefactorService()
  let result = service.buildPrompt(
    from: "uh create a function to parse csv files",
    options: RefactorBuildOptions(style: .coding)
  )

  #expect(result.contains("Task:"))
  #expect(result.contains("Create a function to parse csv files."))
  #expect(result.contains("Prefer technical precision and explicit implementation constraints."))
  #expect(
    result.contains("If critical details are missing, end with up to 2 clarifying questions."))
}

@Test func clarifyPromptPreservesParenthesesAndStripsLeadingTrailingQuotes() {
  let service = PromptRefactorService()
  let output = "\"Create a function (with error handling) that parses data.\""

  let clarified = service.clarifyPrompt(output)

  #expect(clarified == "Create a function (with error handling) that parses data.")
}

@Test func clarifyPromptPreservesSemanticParentheticalContent() {
  let service = PromptRefactorService()
  let output =
    "Write a script using Python (3.12) to connect via HTTPS (TLS 1.3) and fetch user records."

  let clarified = service.clarifyPrompt(output)

  #expect(
    clarified
      == "Write a script using Python (3.12) to connect via HTTPS (TLS 1.3) and fetch user records."
  )
}

@Test func clarifyPromptStripsLeadingAndTrailingDoubleQuotes() {
  let service = PromptRefactorService()
  let output = "\"Write a clear, actionable prompt.\""

  let clarified = service.clarifyPrompt(output)

  #expect(clarified == "Write a clear, actionable prompt.")
}

@Test func clarifyPromptPreservesCommasDotsExclamationMarksAndQuestionMarks() {
  let service = PromptRefactorService()
  let output = "Do this, then that! Really? Yes."

  let clarified = service.clarifyPrompt(output)

  #expect(clarified == "Do this, then that! Really? Yes.")
}

@Test func clarifyPromptReturnsEmptyForEmptyInput() {
  let service = PromptRefactorService()

  #expect(service.clarifyPrompt("") == "")
  #expect(service.clarifyPrompt("   ") == "")
}

@Test func buildPromptUsesCustomStylePromptInsteadOfBuiltInInstructions() {
  let service = PromptRefactorService()
  let result = service.buildPrompt(
    from: "draft an api client for my service",
    options: RefactorBuildOptions(
      style: .coding,
      customStylePrompt: "Output a short checklist with risks first, then implementation details."
    )
  )

  #expect(
    result.contains("Output a short checklist with risks first, then implementation details."))
  #expect(!result.contains("Prefer technical precision and explicit implementation constraints."))
}

@Test func buildPromptFallsBackToBuiltInStyleWhenCustomPromptIsEmpty() {
  let service = PromptRefactorService()
  let result = service.buildPrompt(
    from: "draft an api client for my service",
    options: RefactorBuildOptions(style: .coding, customStylePrompt: "   ")
  )

  #expect(result.contains("Prefer technical precision and explicit implementation constraints."))
}

@Test func buildPromptFallsBackToBuiltInStyleWhenCustomPromptIsNil() {
  let service = PromptRefactorService()
  let result = service.buildPrompt(
    from: "draft an api client for my service",
    options: RefactorBuildOptions(style: .coding, customStylePrompt: nil)
  )

  #expect(result.contains("Prefer technical precision and explicit implementation constraints."))
}
