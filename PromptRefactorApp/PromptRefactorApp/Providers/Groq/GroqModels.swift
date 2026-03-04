import Foundation

struct GroqChatCompletionRequest: Encodable {
    let model: String
    let messages: [GroqChatMessage]
    let temperature: Double
}

struct GroqChatMessage: Encodable {
    let role: String
    let content: String
}

struct GroqChatCompletionResponse: Decodable {
    let choices: [GroqChoice]
}

struct GroqChoice: Decodable {
    let message: GroqResponseMessage
}

struct GroqResponseMessage: Decodable {
    let content: String?
}

enum GroqModel: String, CaseIterable, Identifiable {
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
