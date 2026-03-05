import AppKit
import Testing

@testable import PromptRefactorApp

@MainActor
struct HotkeyServiceTests {
    @Test func shortcutPresetFallsBackToDefaultWhenRawValueInvalid() {
        let preset = ShortcutPreset.from(rawValue: "unknown")

        #expect(preset == .commandShiftR)
    }

    @Test func shortcutPresetProvidesExpectedKeyBindings() {
        #expect(
            ShortcutPreset.commandShiftR.binding
                == HotkeyBinding(keyCode: 15, modifiers: [.command, .shift]))
        #expect(
            ShortcutPreset.commandOptionR.binding
                == HotkeyBinding(keyCode: 15, modifiers: [.command, .option]))
        #expect(
            ShortcutPreset.commandShiftSpace.binding
                == HotkeyBinding(keyCode: 49, modifiers: [.command, .shift]))
    }

    @Test func hotkeyBindingMatchesEquivalentKeyboardEvent() {
        let binding = HotkeyBinding(keyCode: 15, modifiers: [.command, .shift])
        let event = makeKeyDownEvent(keyCode: 15, modifiers: [.command, .shift])

        #expect(binding.matches(event))
    }

    @Test func hotkeyBindingRejectsDifferentModifiers() {
        let binding = HotkeyBinding(keyCode: 15, modifiers: [.command, .shift])
        let event = makeKeyDownEvent(keyCode: 15, modifiers: [.command, .option])

        #expect(!binding.matches(event))
    }

    @Test func hotkeyBindingCaptureRejectsEventsWithoutModifiers() {
        let event = makeKeyDownEvent(keyCode: 15, modifiers: [])

        #expect(HotkeyBinding.capture(from: event) == nil)
    }

    @Test func hotkeyBindingTitleFormatsCapturedShortcut() {
        let binding = HotkeyBinding(keyCode: 15, modifiers: [.command, .shift])

        #expect(binding.title == "Cmd+Shift+R")
    }

    private func makeKeyDownEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}
