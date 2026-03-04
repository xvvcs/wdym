public struct RefactorBuildOptions: Sendable {
    public var style: PromptStyle
    public var language: String
    public var includeClarifyingQuestions: Bool
    /// An optional custom prompt template. When provided, this template is used
    /// instead of the default one. Use `{{task}}` as a placeholder for the
    /// normalized user input.
    public var customTemplate: String?

    public init(
        style: PromptStyle = .general,
        language: String = "English",
        includeClarifyingQuestions: Bool = true,
        customTemplate: String? = nil
    ) {
        self.style = style
        self.language = language
        self.includeClarifyingQuestions = includeClarifyingQuestions
        self.customTemplate = customTemplate
    }
}
