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
    case llama318bInstant = "llama-3.1-8b-instant"
    case llama3370bVersatile = "llama-3.3-70b-versatile"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .llama318bInstant:
            return "Llama 3.1 8B (Fast)"
        case .llama3370bVersatile:
            return "Llama 3.3 70B (Balanced)"
        }
    }

    static func from(rawValue: String) -> GroqModel {
        GroqModel(rawValue: rawValue) ?? .llama318bInstant
    }
}
