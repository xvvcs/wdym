import Testing
@testable import PromptRefactorCore

@Test func normalizeDictationRemovesFillerWordsAndCleansSpacing() {
    let service = PromptRefactorService()
    let raw = " um   write an sql query to list active users from last 30 days uh and sort by signup date "

    let normalized = service.normalizeDictation(raw)

    #expect(
        normalized == "Write an sql query to list active users from last 30 days and sort by signup date."
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
    #expect(result.contains("If critical details are missing, end with up to 2 clarifying questions."))
}
