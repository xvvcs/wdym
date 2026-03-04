import Foundation
import PromptRefactorCore
import Testing
@testable import PromptRefactorApp

@MainActor
struct AppRuntimeControllerTests {
    @Test func runtimeLoadsStoredGroqApiKeyIntoSecureFieldState() {
        let runtime = makeRuntime(initialAPIKey: "gsk_existing_key")

        #expect(runtime.hasStoredGroqAPIKey)
        #expect(runtime.groqAPIKeyInput == "gsk_existing_key")
    }

    @Test func saveGroqApiKeyKeepsValueAndClearRemovesIt() {
        let keychain = InMemoryKeychainStore(apiKey: nil)
        let runtime = makeRuntime(initialAPIKey: nil, keychain: keychain)

        runtime.groqAPIKeyInput = "  gsk_new_key  "
        runtime.saveGroqAPIKey()

        #expect(runtime.groqAPIKeyInput == "gsk_new_key")
        #expect(runtime.hasStoredGroqAPIKey)
        #expect(keychain.apiKey == "gsk_new_key")

        runtime.clearGroqAPIKey()

        #expect(runtime.groqAPIKeyInput.isEmpty)
        #expect(!runtime.hasStoredGroqAPIKey)
        #expect(keychain.apiKey == nil)
    }

    @Test func refactorNowUsesFocusedFieldAndReplacesPlusCopiesOutput() async {
        let focused = StubFocusedTextService(readText: "hello from dictation")
        let clipboard = StubClipboardService(initialRead: nil)
        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: StubTextCommandService(),
            focused: focused,
            permission: SpyAXPermissionService(initialTrusted: true)
        )

        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(focused.writtenText == "Hello from dictation.")
        #expect(clipboard.lastWritten == "Hello from dictation.")
        #expect(runtime.status == "Replaced field and copied output")
    }

    @Test func refactorNowUsesSelectionCopyWhenFocusedFieldUnavailable() async {
        let focused = StubFocusedTextService(readError: AXFocusedTextError.noFocusedElement)
        let clipboard = StubClipboardService(initialRead: "stale clipboard")
        let commands = StubTextCommandService(copyAction: {
            clipboard.currentValue = "send a follow up email tomorrow"
            return true
        })

        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: commands,
            focused: focused,
            permission: SpyAXPermissionService(initialTrusted: true)
        )

        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(commands.selectAllCalls == 1)
        #expect(commands.copyCalls == 1)
        #expect(commands.pasteCalls == 1)
        #expect(clipboard.lastWritten == "Send a follow up email tomorrow.")
        #expect(runtime.status == "Replaced field and copied output")
    }

    @Test func refactorNowUsesKittyShortcutFallbackProfile() async {
        let focused = StubFocusedTextService(readError: AXFocusedTextError.noFocusedElement)
        let clipboard = StubClipboardService(initialRead: "stale")
        let commands = StubTextCommandService(copyAction: {
            clipboard.currentValue = "kitty selected text"
            return true
        })

        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: commands,
            focused: focused,
            permission: SpyAXPermissionService(initialTrusted: true),
            frontmostBundleIdentifier: { "net.kovidgoyal.kitty" }
        )

        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(commands.lastSelectAllFallbackFlag == true)
        #expect(commands.lastCopyFallbackFlag == true)
        #expect(runtime.status == "Replaced field and copied output")
    }

    @Test func refactorNowReportsAccessibilityMissingWhenNotTrusted() async {
        let clipboard = StubClipboardService(initialRead: "rewrite this quickly")
        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: StubTextCommandService(copyAction: { false }),
            focused: StubFocusedTextService(readText: "ignored"),
            permission: SpyAXPermissionService(initialTrusted: false)
        )

        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(runtime.status == "Cannot replace: enable Accessibility and select text")
    }

    @Test func refactorNowDoesNotReuseStaleClipboardWhenSelectionCopyFails() async {
        let clipboard = StubClipboardService(initialRead: "old previous output")
        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: StubTextCommandService(copyAction: { false }),
            focused: StubFocusedTextService(readError: AXFocusedTextError.noFocusedElement),
            permission: SpyAXPermissionService(initialTrusted: true)
        )

        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(runtime.status == "Cannot read selected text in this app")
        #expect(clipboard.currentValue == "old previous output")
    }

    @Test func refactorNowSkipsSelectAllWhenAutoSelectSettingDisabled() async {
        let focused = StubFocusedTextService(readError: AXFocusedTextError.noFocusedElement)
        let clipboard = StubClipboardService(initialRead: "stale")
        let commands = StubTextCommandService(copyAction: {
            clipboard.currentValue = "selected terminal text"
            return true
        })

        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: commands,
            focused: focused,
            permission: SpyAXPermissionService(initialTrusted: true)
        )

        runtime.settingsStore.updateAutoSelectAllOnTrigger(false)
        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(commands.selectAllCalls == 0)
        #expect(commands.copyCalls == 1)
        #expect(runtime.status == "Replaced field and copied output")
    }

    @Test func refactorNowSkipsSecretLikeInput() async {
        let secret = "gsk_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
        let clipboard = StubClipboardService(initialRead: secret)
        let runtime = makeRuntime(
            initialAPIKey: nil,
            clipboard: clipboard,
            textCommands: StubTextCommandService(copyAction: { false }),
            focused: StubFocusedTextService(readError: AXFocusedTextError.noFocusedElement),
            permission: SpyAXPermissionService(initialTrusted: false)
        )

        runtime.settingsStore.updateOutputModeRawValue(OutputMode.copyOnly.rawValue)

        runtime.refactorNow()
        await waitForCompletion(of: runtime)

        #expect(runtime.status == "Skipped: text looks like a secret")
        #expect(clipboard.currentValue == secret)
    }

    @Test func requestAccessibilityAccessOpensSettingsWhenNotTrusted() {
        let permission = SpyAXPermissionService(initialTrusted: false)
        let runtime = makeRuntime(initialAPIKey: nil, permission: permission)

        runtime.requestAccessibilityAccess()

        #expect(permission.requestCallCount == 1)
        #expect(permission.openSettingsCallCount == 1)
        #expect(runtime.status == "Enable Accessibility for PromptRefactorApp in System Settings")
    }

    @Test func requestAccessibilityAccessDoesNothingWhenAlreadyTrusted() {
        let permission = SpyAXPermissionService(initialTrusted: true)
        let runtime = makeRuntime(initialAPIKey: nil, permission: permission)

        runtime.requestAccessibilityAccess()

        #expect(permission.requestCallCount == 0)
        #expect(permission.openSettingsCallCount == 0)
        #expect(runtime.status == "Accessibility already enabled")
    }

    private func makeRuntime(
        initialAPIKey: String?,
        keychain: InMemoryKeychainStore? = nil,
        clipboard: StubClipboardService = StubClipboardService(initialRead: nil),
        textCommands: StubTextCommandService = StubTextCommandService(),
        focused: StubFocusedTextService = StubFocusedTextService(readError: AXFocusedTextError.noFocusedElement),
        permission: SpyAXPermissionService = SpyAXPermissionService(initialTrusted: false),
        frontmostBundleIdentifier: @escaping () -> String? = { nil }
    ) -> AppRuntimeController {
        let suite = "AppRuntimeControllerTests.\(UUID().uuidString)"
        let settingsStore = UserDefaultsAppSettingsStore(userDefaults: UserDefaults(suiteName: suite)!)

        let keychainStore = keychain ?? InMemoryKeychainStore(apiKey: initialAPIKey)
        if keychain == nil {
            keychainStore.apiKey = initialAPIKey
        }

        return AppRuntimeController(
            settingsStore: settingsStore,
            refactorService: PromptRefactorService(),
            hotkeyService: StubHotkeyService(),
            clipboardService: clipboard,
            textCommandService: textCommands,
            focusedTextService: focused,
            permissionService: permission,
            keychainStore: keychainStore,
            providerFactory: ProviderFactory(),
            frontmostBundleIdentifierProvider: frontmostBundleIdentifier
        )
    }

    private func waitForCompletion(of runtime: AppRuntimeController) async {
        for _ in 0..<200 {
            if runtime.status != "Idle", runtime.status != "Refactoring..." {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class StubHotkeyService: HotkeyService {
    func startListening(binding: HotkeyBinding, handler: @escaping () -> Void) {}
    func updateBinding(_ binding: HotkeyBinding) {}
    func stopListening() {}
}

private final class StubClipboardService: ClipboardService {
    var currentValue: String?
    private(set) var lastWritten: String?

    init(initialRead: String?) {
        self.currentValue = initialRead
    }

    func readString() -> String? {
        currentValue
    }

    func writeString(_ value: String) {
        currentValue = value
        lastWritten = value
    }
}

private final class StubTextCommandService: TextCommandService {
    private let selectAllAction: () -> Bool
    private let copyAction: () -> Bool
    private let pasteAction: () -> Bool
    private(set) var selectAllCalls = 0
    private(set) var copyCalls = 0
    private(set) var pasteCalls = 0
    private(set) var lastSelectAllFallbackFlag: Bool?
    private(set) var lastCopyFallbackFlag: Bool?

    init(
        selectAllAction: @escaping () -> Bool = { true },
        copyAction: @escaping () -> Bool = { false },
        pasteAction: @escaping () -> Bool = { true }
    ) {
        self.selectAllAction = selectAllAction
        self.copyAction = copyAction
        self.pasteAction = pasteAction
    }

    func selectAllInFocusedUI(useTerminalShortcutFallbacks: Bool) async -> Bool {
        selectAllCalls += 1
        lastSelectAllFallbackFlag = useTerminalShortcutFallbacks
        return selectAllAction()
    }

    func copySelectionToClipboard(useTerminalShortcutFallbacks: Bool) async -> Bool {
        copyCalls += 1
        lastCopyFallbackFlag = useTerminalShortcutFallbacks
        return copyAction()
    }

    func pasteFromClipboard() async -> Bool {
        pasteCalls += 1
        return pasteAction()
    }
}

private final class StubFocusedTextService: AXFocusedTextService {
    let readText: String?
    let readError: Error?
    private(set) var writtenText: String?

    init(readText: String? = nil, readError: Error? = nil) {
        self.readText = readText
        self.readError = readError
    }

    func readFocusedText() throws -> String {
        if let readError {
            throw readError
        }

        return readText ?? ""
    }

    func writeFocusedText(_ value: String) throws {
        writtenText = value
    }
}

private final class SpyAXPermissionService: AXPermissionService {
    private(set) var trusted: Bool
    private(set) var requestCallCount = 0
    private(set) var openSettingsCallCount = 0

    init(initialTrusted: Bool) {
        self.trusted = initialTrusted
    }

    func isTrusted() -> Bool {
        trusted
    }

    func requestAccessIfNeeded() -> Bool {
        requestCallCount += 1
        return trusted
    }

    func openAccessibilitySettings() {
        openSettingsCallCount += 1
    }
}

private final class InMemoryKeychainStore: KeychainStore {
    var apiKey: String?

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func loadGroqAPIKey() -> String? {
        apiKey
    }

    func saveGroqAPIKey(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    func deleteGroqAPIKey() throws {
        apiKey = nil
    }
}
