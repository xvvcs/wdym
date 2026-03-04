import AppKit

struct HotkeyBinding: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.supportedModifiers)
    }

    init(keyCode: UInt16, modifiersRawValue: UInt) {
        self.init(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiersRawValue))
    }

    var modifiersRawValue: UInt {
        modifiers.rawValue
    }

    var title: String {
        var components: [String] = []

        if modifiers.contains(.command) {
            components.append("Cmd")
        }
        if modifiers.contains(.shift) {
            components.append("Shift")
        }
        if modifiers.contains(.option) {
            components.append("Option")
        }
        if modifiers.contains(.control) {
            components.append("Control")
        }

        components.append(Self.keyName(for: keyCode))
        return components.joined(separator: "+")
    }

    func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return false
        }

        let normalized = event.modifierFlags.intersection(Self.supportedModifiers)
        return event.keyCode == keyCode && normalized == modifiers
    }

    static func capture(from event: NSEvent) -> HotkeyBinding? {
        guard event.type == .keyDown else {
            return nil
        }

        let normalized = event.modifierFlags.intersection(supportedModifiers)
        guard !normalized.isEmpty else {
            return nil
        }

        guard !modifierOnlyKeyCodes.contains(event.keyCode) else {
            return nil
        }

        return HotkeyBinding(keyCode: event.keyCode, modifiers: normalized)
    }

    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    private static let modifierOnlyKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        49: "Space", 50: "`", 53: "Escape",
    ]

    private static func keyName(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
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
