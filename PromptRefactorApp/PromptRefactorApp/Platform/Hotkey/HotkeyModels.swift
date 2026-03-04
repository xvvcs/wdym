import AppKit

struct HotkeyBinding: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return false
        }

        let normalized = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && normalized == modifiers
    }
}

enum ShortcutPreset: String, CaseIterable, Identifiable {
    case commandShiftR
    case commandOptionR
    case commandShiftSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandShiftR:
            return "Cmd+Shift+R"
        case .commandOptionR:
            return "Cmd+Option+R"
        case .commandShiftSpace:
            return "Cmd+Shift+Space"
        }
    }

    var binding: HotkeyBinding {
        switch self {
        case .commandShiftR:
            return HotkeyBinding(keyCode: 15, modifiers: [.command, .shift])
        case .commandOptionR:
            return HotkeyBinding(keyCode: 15, modifiers: [.command, .option])
        case .commandShiftSpace:
            return HotkeyBinding(keyCode: 49, modifiers: [.command, .shift])
        }
    }

    static func from(rawValue: String) -> ShortcutPreset {
        ShortcutPreset(rawValue: rawValue) ?? .commandShiftR
    }
}
