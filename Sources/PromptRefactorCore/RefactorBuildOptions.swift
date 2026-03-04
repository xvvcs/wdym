public struct RefactorBuildOptions: Sendable {
    public var style: PromptStyle
    public var language: String
    public var includeClarifyingQuestions: Bool

    public init(
        style: PromptStyle = .general,
        language: String = "English",
        includeClarifyingQuestions: Bool = true
    ) {
        self.style = style
        self.language = language
        self.includeClarifyingQuestions = includeClarifyingQuestions
    }
}
