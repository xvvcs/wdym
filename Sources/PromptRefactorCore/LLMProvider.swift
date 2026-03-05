public struct LLMRefactorRequest: Sendable {
  public let prompt: String
  public let style: PromptStyle
  public let language: String

  public init(prompt: String, style: PromptStyle, language: String) {
    self.prompt = prompt
    self.style = style
    self.language = language
  }
}

public protocol LLMProvider: Sendable {
  func refactor(_ request: LLMRefactorRequest) async throws -> String
}
