import AppKit
import ApplicationServices
import Foundation

protocol AXPermissionService {
    func isTrusted() -> Bool
    func requestAccessIfNeeded() -> Bool
    func openAccessibilitySettings()
}

struct DefaultAXPermissionService: AXPermissionService {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessIfNeeded() -> Bool {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
