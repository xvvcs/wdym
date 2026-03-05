import PromptRefactorCore

struct GroqRequestBuilder {
    func build(request: LLMRefactorRequest, model: GroqModel) -> GroqChatCompletionRequest {
        let systemMessage = GroqChatMessage(
            role: "system",
            content:
                "You rewrite dictated user text into a concise, high-quality prompt for AI assistants. Return only the rewritten prompt text."
        )

        let userMessage = GroqChatMessage(
            role: "user",
            content: """
                Language: \(request.language)
                Style: \(request.style.rawValue)

                Original input:
                \(request.prompt)
                """
        )

        return GroqChatCompletionRequest(
            model: model.rawValue,
            messages: [systemMessage, userMessage],
            temperature: 0.2
        )
    }
}
