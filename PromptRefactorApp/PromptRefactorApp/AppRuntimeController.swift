import AppKit
import Combine
import PromptRefactorCore

@MainActor
final class AppRuntimeController: ObservableObject {
    @Published var status = "Idle"
    @Published var groqAPIKeyInput = ""
    @Published private(set) var hasStoredGroqAPIKey = false
    @Published var groqAPIKeyMessage = ""

    let settingsStore: UserDefaultsAppSettingsStore

    private let refactorService: PromptRefactorService
    private let hotkeyService: any HotkeyService
    private let keychainStore: any KeychainStore
    private let providerFactory: ProviderFactory
    private var cancellables: Set<AnyCancellable> = []
    private var activeRefactorTask: Task<Void, Never>?

    init() {
        self.settingsStore = UserDefaultsAppSettingsStore()
        self.refactorService = PromptRefactorService()
        self.hotkeyService = GlobalHotkeyService()
        self.keychainStore = DefaultKeychainStore()
        self.providerFactory = ProviderFactory()

        configureHotkey()
        observeShortcutChanges()
        refreshGroqAPIKeyState()
    }

    init(
        settingsStore: UserDefaultsAppSettingsStore,
        refactorService: PromptRefactorService,
        hotkeyService: any HotkeyService,
        keychainStore: any KeychainStore,
        providerFactory: ProviderFactory
    ) {
        self.settingsStore = settingsStore
        self.refactorService = refactorService
        self.hotkeyService = hotkeyService
        self.keychainStore = keychainStore
        self.providerFactory = providerFactory

        configureHotkey()
        observeShortcutChanges()
        refreshGroqAPIKeyState()
    }

    func refactorClipboard() {
        activeRefactorTask?.cancel()
        activeRefactorTask = Task { [weak self] in
            await self?.performRefactorClipboard()
        }
    }

    func saveGroqAPIKey() {
        let sanitized = groqAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            groqAPIKeyMessage = "Enter a non-empty API key"
            return
        }

        do {
            try keychainStore.saveGroqAPIKey(sanitized)
            groqAPIKeyInput = sanitized
            groqAPIKeyMessage = "Groq API key saved"
            refreshGroqAPIKeyState()
        } catch {
            groqAPIKeyMessage = "Failed to save API key"
        }
    }

    func clearGroqAPIKey() {
        do {
            try keychainStore.deleteGroqAPIKey()
            groqAPIKeyInput = ""
            groqAPIKeyMessage = "Groq API key cleared"
            refreshGroqAPIKeyState()
        } catch {
            groqAPIKeyMessage = "Failed to clear API key"
        }
    }

    private func performRefactorClipboard() async {
        let pasteboard = NSPasteboard.general
        guard let rawText = pasteboard.string(forType: .string), !rawText.isEmpty else {
            status = "Clipboard empty"
            return
        }

        if looksLikeSecret(rawText) {
            status = "Skipped: clipboard looks like a secret"
            return
        }

        status = "Refactoring..."

        let preferences = settingsStore.settings.refactorPreferences
        let options = preferences.buildOptions()
        let llmInput = refactorService.buildPrompt(from: rawText, options: options)

        let localFallback = refactorService.normalizeDictation(rawText)
        guard !localFallback.isEmpty else {
            status = "Nothing to refactor"
            return
        }

        var finalOutput = localFallback
        var completionStatus = "Copied refactored prompt"

        if settingsStore.settings.useGroqRefinement {
            let request = LLMRefactorRequest(
                prompt: llmInput,
                style: options.style,
                language: options.language
            )

            if let provider = providerFactory.makeProvider(settings: settingsStore.settings, keychainStore: keychainStore) {
                do {
                    finalOutput = try await provider.refactor(request)
                    completionStatus = "Copied refactored prompt via Groq"
                } catch GroqProviderError.badStatusCode(401) {
                    completionStatus = "Groq auth failed, used local fallback"
                } catch {
                    completionStatus = "Groq failed, used local fallback"
                }
            } else {
                completionStatus = "Groq key missing, used local fallback"
            }
        }

        pasteboard.clearContents()
        pasteboard.setString(finalOutput, forType: .string)

        if preferences.outputMode == .replaceOnly {
            status = "\(completionStatus) (replace-only pending field integration)"
        } else {
            status = completionStatus
        }
    }

    private func configureHotkey() {
        hotkeyService.startListening(binding: settingsStore.settings.shortcutPreset.binding) { [weak self] in
            Task { @MainActor in
                self?.refactorClipboard()
            }
        }
    }

    private func observeShortcutChanges() {
        settingsStore.$settings
            .map(\.shortcutPresetRawValue)
            .removeDuplicates()
            .sink { [weak self] rawValue in
                let preset = ShortcutPreset.from(rawValue: rawValue)
                self?.hotkeyService.updateBinding(preset.binding)
            }
            .store(in: &cancellables)
    }

    private func refreshGroqAPIKeyState() {
        let stored = keychainStore.loadGroqAPIKey() ?? ""
        let hasValue = !stored.isEmpty
        hasStoredGroqAPIKey = hasValue

        if hasValue {
            groqAPIKeyInput = stored
        }
    }

    private func looksLikeSecret(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let patterns = [
            "(?i)^gsk_[A-Za-z0-9_-]{16,}$",
            "(?i)^sk-[A-Za-z0-9_-]{16,}$",
            "(?i)^ghp_[A-Za-z0-9]{20,}$",
        ]

        return patterns.contains { pattern in
            trimmed.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
