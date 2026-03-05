import Foundation
import PromptRefactorCore

enum GroqProviderError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case badStatusCode(Int)
    case emptyContent
}

struct GroqProvider: LLMProvider {
    private let apiKey: String
    private let model: GroqModel
    private let session: URLSession
    private let requestBuilder: GroqRequestBuilder

    init(
        apiKey: String,
        model: GroqModel,
        session: URLSession = .shared,
        requestBuilder: GroqRequestBuilder = GroqRequestBuilder()
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.requestBuilder = requestBuilder
    }

    func refactor(_ request: LLMRefactorRequest) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw GroqProviderError.invalidURL
        }

        let payload = requestBuilder.build(request: request, model: model)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 20
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GroqProviderError.badStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GroqChatCompletionResponse.self, from: data)
        guard
            let content = decoded.choices.first?.message.content?.trimmingCharacters(
                in: .whitespacesAndNewlines), !content.isEmpty
        else {
            throw GroqProviderError.emptyContent
        }

        return content
    }
}
