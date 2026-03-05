import Foundation
import PromptRefactorCore
import Testing

@testable import PromptRefactorApp

@Suite(.serialized)
@MainActor
struct GroqProviderTests {
  @Test func groqRequestBuilderProducesSpeedFirstPayload() {
    let request = LLMRefactorRequest(
      prompt: "please rewrite this into a better ai prompt",
      style: .general,
      language: "English"
    )

    let payload = GroqRequestBuilder().build(request: request, model: .llama31_8bInstant)

    #expect(payload.model == GroqModel.llama31_8bInstant.rawValue)
    #expect(payload.temperature == 0.2)
    #expect(payload.messages.count == 2)
    #expect(payload.messages[0].role == "system")
    #expect(payload.messages[1].content.contains("Original input:"))
  }

  @Test func groqProviderReturnsResponseMessageContent() async throws {
    let session = makeSession(
      statusCode: 200,
      json: """
        {
          "choices": [
            {
              "message": {
                "content": "Refactored prompt output"
              }
            }
          ]
        }
        """
    )

    let provider = GroqProvider(
      apiKey: "test-key",
      model: .llama31_8bInstant,
      session: session
    )

    let response = try await provider.refactor(
      LLMRefactorRequest(prompt: "raw text", style: .general, language: "English")
    )

    #expect(response == "Refactored prompt output")
  }

  @Test func groqProviderThrowsForBadStatusCode() async {
    let session = makeSession(
      statusCode: 401,
      json: """
        {
          "error": {
            "message": "Unauthorized"
          }
        }
        """
    )

    let provider = GroqProvider(
      apiKey: "bad-key",
      model: .llama31_8bInstant,
      session: session
    )

    await #expect(throws: GroqProviderError.badStatusCode(401)) {
      try await provider.refactor(
        LLMRefactorRequest(prompt: "raw text", style: .general, language: "English")
      )
    }
  }

  private func makeSession(statusCode: Int, json: String) -> URLSession {
    URLProtocolStub.statusCode = statusCode
    URLProtocolStub.data = Data(json.utf8)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
  }
}

private final class URLProtocolStub: URLProtocol {
  static var data = Data()
  static var statusCode = 200

  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == "api.groq.com"
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: Self.statusCode,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
