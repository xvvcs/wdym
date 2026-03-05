import AppKit
import Combine
import PromptRefactorCore

@MainActor
final class AppRuntimeController: ObservableObject {
    @Published var status = "Idle"
    @Published private(set) var isAccessibilityTrusted = false
    @Published var kittyRemoteControlStatusMessage = "Not checked"
    @Published var groqAPIKeyInput = ""
    @Published private(set) var hasStoredGroqAPIKey = false
    @Published var groqAPIKeyMessage = ""

    let settingsStore: UserDefaultsAppSettingsStore

    private let refactorService: PromptRefactorService
    private let hotkeyService: any HotkeyService
    private let clipboardService: any ClipboardService
    private let textCommandService: any TextCommandService
    private let kittyRemoteControlService: any KittyRemoteControlService
    private let focusedTextService: any AXFocusedTextService
    private let permissionService: any AXPermissionService
    private let keychainStore: any KeychainStore
    private let providerFactory: ProviderFactory
    private let frontmostBundleIdentifierProvider: () -> String?
    private var cancellables: Set<AnyCancellable> = []
    private var activeRefactorTask: Task<Void, Never>?

    init() {
        self.settingsStore = UserDefaultsAppSettingsStore()
        self.refactorService = PromptRefactorService()
        self.hotkeyService = GlobalHotkeyService()
        self.clipboardService = PasteboardClipboardService()
        self.textCommandService = DefaultTextCommandService()
        self.kittyRemoteControlService = DefaultKittyRemoteControlService()
        self.focusedTextService = DefaultAXFocusedTextService()
        self.permissionService = DefaultAXPermissionService()
        self.keychainStore = DefaultKeychainStore()
        self.providerFactory = ProviderFactory()
        self.frontmostBundleIdentifierProvider = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }

        configureHotkey()
        observeShortcutChanges()
        refreshGroqAPIKeyState()
        refreshAccessibilityState()
    }

    init(
        settingsStore: UserDefaultsAppSettingsStore,
        refactorService: PromptRefactorService,
        hotkeyService: any HotkeyService,
        clipboardService: any ClipboardService,
        textCommandService: any TextCommandService,
        kittyRemoteControlService: any KittyRemoteControlService,
        focusedTextService: any AXFocusedTextService,
        permissionService: any AXPermissionService,
        keychainStore: any KeychainStore,
        providerFactory: ProviderFactory,
        frontmostBundleIdentifierProvider: @escaping () -> String?
    ) {
        self.settingsStore = settingsStore
        self.refactorService = refactorService
        self.hotkeyService = hotkeyService
        self.clipboardService = clipboardService
        self.textCommandService = textCommandService
        self.kittyRemoteControlService = kittyRemoteControlService
        self.focusedTextService = focusedTextService
        self.permissionService = permissionService
        self.keychainStore = keychainStore
        self.providerFactory = providerFactory
        self.frontmostBundleIdentifierProvider = frontmostBundleIdentifierProvider

        configureHotkey()
        observeShortcutChanges()
        refreshGroqAPIKeyState()
        refreshAccessibilityState()
    }

    func refactorNow() {
        activeRefactorTask?.cancel()
        activeRefactorTask = Task { [weak self] in
            await self?.performRefactorNow()
        }
    }

    func requestAccessibilityAccess() {
        if permissionService.isTrusted() {
            refreshAccessibilityState()
            status = "Accessibility already enabled"
            return
        }

        _ = permissionService.requestAccessIfNeeded()
        refreshAccessibilityState()

        if isAccessibilityTrusted {
            status = "Accessibility enabled"
            return
        }

        permissionService.openAccessibilitySettings()
        status = "Enable Accessibility for PromptRefactorApp in System Settings"
    }

    func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    func pollAccessibilityState() {
        refreshAccessibilityState()
    }

    func runKittyRemoteControlCheck() {
        Task { [weak self] in
            await self?.refreshKittyRemoteControlStatus()
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

    private func performRefactorNow() async {
        let settings = settingsStore.settings
        let preferences = settings.refactorPreferences
        let source = await resolveInputSource(settings: settings)

        if source.kind == .clipboard, preferences.outputMode.shouldReplaceText {
            switch source.fallbackReason {
            case .accessibilityNotTrusted:
                status = "Cannot replace: enable Accessibility and select text"
            case .focusedReadFailed:
                status = "Cannot read selected text in this app"
            case .kittyRemoteControlUnavailable:
                status = "Cannot replace: configure Kitty Remote Control"
            case .kittySelectionMissing:
                status = "Cannot replace: select text in Kitty/OpenCode"
            case .none:
                status = "Cannot replace from clipboard source"
            }

            return
        }

        guard let rawText = source.text, !rawText.isEmpty else {
            if preferences.outputMode.shouldReplaceText {
                status = "Cannot capture text in this app; select text and retry"
            } else {
                status = "No focused text or clipboard text"
            }

            return
        }

        if looksLikeSecret(rawText) {
            if source.kind == .selectionCopy, let previousClipboard = source.previousClipboardText {
                clipboardService.writeString(previousClipboard)
            }

            status = "Skipped: text looks like a secret"
            return
        }

        status = "Refactoring..."

        let options = preferences.buildOptions()
        let llmInput = refactorService.buildPrompt(from: rawText, options: options)

        let localFallback = refactorService.normalizeDictation(rawText)
        guard !localFallback.isEmpty else {
            status = "Nothing to refactor"
            return
        }

        var finalOutput = localFallback
        var completionStatus = "Copied refactored prompt"

        if settings.useGroqRefinement {
            let request = LLMRefactorRequest(
                prompt: llmInput,
                style: options.style,
                language: options.language
            )

            if let provider = providerFactory.makeProvider(
                settings: settings, keychainStore: keychainStore)
            {
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

        let clarified = refactorService.clarifyPrompt(finalOutput)
        if !clarified.isEmpty {
            finalOutput = clarified
        }

        let outputMode = preferences.outputMode
        var replaced = false
        var copied = false

        if outputMode.shouldReplaceText {
            switch source.kind {
            case .focusedField:
                do {
                    try focusedTextService.writeFocusedText(finalOutput)
                    replaced = true
                } catch {
                    replaced = false
                }

            case .selectionCopy:
                clipboardService.writeString(finalOutput)
                replaced = await textCommandService.pasteFromClipboard()

            case .clipboard:
                replaced = false
            }
        }

        if replaced && outputMode == .replaceOnly {
            if let previousClipboard = source.previousClipboardText {
                clipboardService.writeString(previousClipboard)
            }
        }

        if outputMode.shouldCopyText {
            clipboardService.writeString(finalOutput)
            copied = true
        } else if !replaced {
            clipboardService.writeString(finalOutput)
            copied = true
        }

        if replaced && copied {
            status = "Replaced field and copied output"
            return
        }

        if replaced {
            status = "Replaced focused field text"
            return
        }

        if copied {
            if outputMode.shouldReplaceText {
                switch source.fallbackReason {
                case .accessibilityNotTrusted:
                    status = "\(completionStatus) (accessibility not enabled; copied)"
                case .focusedReadFailed:
                    status = "\(completionStatus) (focused field unavailable; copied)"
                case .kittyRemoteControlUnavailable:
                    status = "\(completionStatus) (Kitty remote control unavailable; copied)"
                case .kittySelectionMissing:
                    status = "\(completionStatus) (Kitty selection missing; copied)"
                case .none:
                    status = "\(completionStatus) (copied)"
                }
            } else {
                status = completionStatus
            }

            return
        }

        status = "Refactor finished"
    }

    private func resolveInputSource(settings: AppSettings) async -> InputSource {
        refreshAccessibilityState()

        let previousClipboard = clipboardService.readString()
        let outputMode = settings.refactorPreferences.outputMode
        let useTerminalShortcutFallbacks = shouldUseTerminalShortcutFallbacks(settings: settings)

        if shouldRequireKittyRemoteControl(settings: settings) {
            let kittyCapture = await captureUsingKittyRemoteControl(settings: settings)
            switch kittyCapture {
            case .success(let selectedText):
                return InputSource(
                    kind: .selectionCopy,
                    text: selectedText,
                    fallbackReason: .none,
                    previousClipboardText: previousClipboard
                )
            case .failure(let fallbackReason):
                return InputSource(
                    kind: .clipboard,
                    text: nil,
                    fallbackReason: fallbackReason,
                    previousClipboardText: previousClipboard
                )
            }
        }

        if outputMode.shouldReplaceText || settings.terminalModeEnabled {
            if let selectedText = await captureUsingCommandPipeline(
                previousClipboardText: previousClipboard,
                autoSelectAll: settings.autoSelectAllOnTrigger,
                useTerminalShortcutFallbacks: useTerminalShortcutFallbacks
            ) {
                return InputSource(
                    kind: .selectionCopy,
                    text: selectedText,
                    fallbackReason: .none,
                    previousClipboardText: previousClipboard
                )
            }
        }

        if isAccessibilityTrusted {
            if let focusedText = try? focusedTextService.readFocusedText(), !focusedText.isEmpty {
                return InputSource(
                    kind: .focusedField,
                    text: focusedText,
                    fallbackReason: .none,
                    previousClipboardText: previousClipboard
                )
            }
        }

        if outputMode.shouldReplaceText {
            return InputSource(
                kind: .clipboard,
                text: nil,
                fallbackReason: isAccessibilityTrusted
                    ? .focusedReadFailed : .accessibilityNotTrusted,
                previousClipboardText: previousClipboard
            )
        }

        if let selectedText = await captureUsingCommandPipeline(
            previousClipboardText: previousClipboard,
            autoSelectAll: settings.autoSelectAllOnTrigger,
            useTerminalShortcutFallbacks: useTerminalShortcutFallbacks
        ) {
            return InputSource(
                kind: .selectionCopy,
                text: selectedText,
                fallbackReason: .none,
                previousClipboardText: previousClipboard
            )
        }

        return InputSource(
            kind: .clipboard,
            text: clipboardService.readString(),
            fallbackReason: .accessibilityNotTrusted,
            previousClipboardText: previousClipboard
        )
    }

    private func captureUsingCommandPipeline(
        previousClipboardText: String?,
        autoSelectAll: Bool,
        useTerminalShortcutFallbacks: Bool
    ) async -> String? {
        let marker = "__PROMPT_REFACTOR_CAPTURE__\(UUID().uuidString)__"
        clipboardService.writeString(marker)

        if autoSelectAll {
            _ = await textCommandService.selectAllInFocusedUI(
                useTerminalShortcutFallbacks: useTerminalShortcutFallbacks)
        }

        guard
            await textCommandService.copySelectionToClipboard(
                useTerminalShortcutFallbacks: useTerminalShortcutFallbacks)
        else {
            restoreClipboard(previousClipboardText)
            return nil
        }

        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 50_000_000)

            guard let current = clipboardService.readString() else {
                continue
            }

            if current != marker, !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return current
            }
        }

        restoreClipboard(previousClipboardText)
        return nil
    }

    private func restoreClipboard(_ previousClipboardText: String?) {
        guard let previousClipboardText else {
            clipboardService.writeString("")
            return
        }

        clipboardService.writeString(previousClipboardText)
    }

    private func shouldUseTerminalShortcutFallbacks(settings: AppSettings) -> Bool {
        guard settings.terminalModeEnabled else {
            return false
        }

        guard let bundleIdentifier = frontmostBundleIdentifierProvider() else {
            return false
        }

        return bundleIdentifier == "net.kovidgoyal.kitty"
    }

    private func shouldRequireKittyRemoteControl(settings: AppSettings) -> Bool {
        shouldUseTerminalShortcutFallbacks(settings: settings)
            && settings.kittyRemoteControlRequired
    }

    private func captureUsingKittyRemoteControl(settings: AppSettings) async -> Result<
        String, InputFallbackReason
    > {
        let listenAddress = settings.kittyListenAddress
        let connectionStatus = await kittyRemoteControlService.checkConnection(
            listenAddress: listenAddress)
        kittyRemoteControlStatusMessage = connectionStatus.message

        guard connectionStatus.isAvailable else {
            return .failure(.kittyRemoteControlUnavailable)
        }

        let selectionResult = await kittyRemoteControlService.readFocusedSelection(
            listenAddress: listenAddress)
        switch selectionResult {
        case .success(let text):
            return .success(text)
        case .failure(.emptySelection):
            let screenTextResult = await kittyRemoteControlService.readFocusedScreenText(
                listenAddress: listenAddress)
            switch screenTextResult {
            case .success(let text):
                return .success(text)
            case .failure(.emptySelection):
                return .failure(.kittySelectionMissing)
            case .failure(.unavailable(let reason)):
                kittyRemoteControlStatusMessage = reason
                return .failure(.kittyRemoteControlUnavailable)
            }
        case .failure(.unavailable(let reason)):
            kittyRemoteControlStatusMessage = reason
            return .failure(.kittyRemoteControlUnavailable)
        }
    }

    private func refreshKittyRemoteControlStatus() async {
        let listenAddress = settingsStore.settings.kittyListenAddress
        let connectionStatus = await kittyRemoteControlService.checkConnection(
            listenAddress: listenAddress)
        kittyRemoteControlStatusMessage = connectionStatus.message
    }

    private func refreshAccessibilityState() {
        isAccessibilityTrusted = permissionService.isTrusted()
    }

    private func configureHotkey() {
        hotkeyService.startListening(binding: settingsStore.settings.activeShortcutBinding) {
            [weak self] in
            Task { @MainActor in
                self?.refactorNow()
            }
        }
    }

    private func observeShortcutChanges() {
        settingsStore.$settings
            .map(\.activeShortcutBinding)
            .removeDuplicates()
            .sink { [weak self] binding in
                self?.hotkeyService.updateBinding(binding)
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

private struct InputSource {
    let kind: InputSourceKind
    let text: String?
    let fallbackReason: InputFallbackReason
    let previousClipboardText: String?
}

private enum InputSourceKind {
    case focusedField
    case selectionCopy
    case clipboard
}

private enum InputFallbackReason: Error {
    case none
    case accessibilityNotTrusted
    case focusedReadFailed
    case kittyRemoteControlUnavailable
    case kittySelectionMissing
}
