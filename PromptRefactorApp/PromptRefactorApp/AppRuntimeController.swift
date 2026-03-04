import AppKit
import Combine
import PromptRefactorCore

@MainActor
final class AppRuntimeController: ObservableObject {
    @Published var status = "Idle"

    let settingsStore: UserDefaultsAppSettingsStore

    private let refactorService: PromptRefactorService
    private let hotkeyService: any HotkeyService
    private var cancellables: Set<AnyCancellable> = []

    init() {
        self.settingsStore = UserDefaultsAppSettingsStore()
        self.refactorService = PromptRefactorService()
        self.hotkeyService = GlobalHotkeyService()

        configureHotkey()
        observeShortcutChanges()
    }

    init(
        settingsStore: UserDefaultsAppSettingsStore,
        refactorService: PromptRefactorService,
        hotkeyService: any HotkeyService
    ) {
        self.settingsStore = settingsStore
        self.refactorService = refactorService
        self.hotkeyService = hotkeyService

        configureHotkey()
        observeShortcutChanges()
    }

    func refactorClipboard() {
        let pasteboard = NSPasteboard.general
        guard let rawText = pasteboard.string(forType: .string), !rawText.isEmpty else {
            status = "Clipboard empty"
            return
        }

        status = "Refactoring..."

        let preferences = settingsStore.settings.refactorPreferences
        let options = preferences.buildOptions()

        let refactored = refactorService.buildPrompt(from: rawText, options: options)
        guard !refactored.isEmpty else {
            status = "Nothing to refactor"
            return
        }

        pasteboard.clearContents()
        pasteboard.setString(refactored, forType: .string)

        if preferences.outputMode == .replaceOnly {
            status = "Replace-only mode pending field integration; copied"
        } else {
            status = "Copied refactored prompt"
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
}
