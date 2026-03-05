import Foundation

nonisolated struct GroqChatCompletionRequest: Encodable, Sendable {
  let model: String
  let messages: [GroqChatMessage]
  let temperature: Double
}

nonisolated struct GroqChatMessage: Encodable, Sendable {
  let role: String
  let content: String
}

nonisolated struct GroqChatCompletionResponse: Decodable, Sendable {
  let choices: [GroqChoice]
}

nonisolated struct GroqChoice: Decodable, Sendable {
  let message: GroqResponseMessage
}

nonisolated struct GroqResponseMessage: Decodable, Sendable {
  let content: String?
}

nonisolated enum GroqModel: String, CaseIterable, Identifiable, Sendable {
  case llama31_8bInstant = "llama-3.1-8b-instant"
  case llama33_70bVersatile = "llama-3.3-70b-versatile"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .llama31_8bInstant:
      return "Llama 3.1 8B (Fast)"
    case .llama33_70bVersatile:
      return "Llama 3.3 70B (Balanced)"
    }
  }

  static func from(rawValue: String) -> GroqModel {
    GroqModel(rawValue: rawValue) ?? .llama31_8bInstant
  }
}
