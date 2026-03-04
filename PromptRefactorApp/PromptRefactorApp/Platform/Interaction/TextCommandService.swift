import AppKit

protocol TextCommandService {
    func selectAllInFocusedUI(useTerminalShortcutFallbacks: Bool) async -> Bool
    func copySelectionToClipboard(useTerminalShortcutFallbacks: Bool) async -> Bool
    func pasteFromClipboard() async -> Bool
}

struct DefaultTextCommandService: TextCommandService {
    func selectAllInFocusedUI(useTerminalShortcutFallbacks: Bool) async -> Bool {
        let didPrimaryPost = postShortcut(keyCode: 0, modifiers: [.maskCommand])
        if didPrimaryPost {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        guard useTerminalShortcutFallbacks else {
            return didPrimaryPost
        }

        let didSecondaryPost = postShortcut(keyCode: 0, modifiers: [.maskCommand, .maskShift])
        if didSecondaryPost {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        return didPrimaryPost || didSecondaryPost
    }

    func copySelectionToClipboard(useTerminalShortcutFallbacks: Bool) async -> Bool {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        guard postShortcut(keyCode: 8, modifiers: [.maskCommand]) else {
            return false
        }

        try? await Task.sleep(nanoseconds: 80_000_000)
        if pasteboard.changeCount != initialChangeCount {
            return true
        }

        guard useTerminalShortcutFallbacks else {
            return false
        }

        guard postShortcut(keyCode: 8, modifiers: [.maskCommand, .maskShift]) else {
            return false
        }

        try? await Task.sleep(nanoseconds: 80_000_000)
        return pasteboard.changeCount != initialChangeCount
    }

    func pasteFromClipboard() async -> Bool {
        let didPost = postShortcut(keyCode: 9, modifiers: [.maskCommand])
        if didPost {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        return didPost
    }

    private func postShortcut(keyCode: CGKeyCode, modifiers: CGEventFlags) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
