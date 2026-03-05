import Foundation
import PromptRefactorCore

struct ProviderFactory {
    func makeProvider(settings: AppSettings, keychainStore: KeychainStore) -> (any LLMProvider)? {
        guard settings.useGroqRefinement else {
            return nil
        }

        guard
            let apiKey = keychainStore.loadGroqAPIKey()?.trimmingCharacters(
                in: .whitespacesAndNewlines), !apiKey.isEmpty
        else {
            return nil
        }

        let model = GroqModel.from(rawValue: settings.groqModelRawValue)
        return GroqProvider(apiKey: apiKey, model: model)
    }
}
