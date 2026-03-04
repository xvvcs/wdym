//
//  PromptRefactorAppApp.swift
//  PromptRefactorApp
//
//  Created by Maciej Matuszewski on 04/03/2026.
//

import AppKit
import PromptRefactorCore
import SwiftUI

@main
struct PromptRefactorAppApp: App {
    @StateObject private var runtime = AppRuntimeController()

    var body: some Scene {
        MenuBarExtra("Prompt Refactor", systemImage: "wand.and.stars") {
            MenuBarContent(status: $runtime.status, refactorClipboard: runtime.refactorClipboard)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Options", id: "options") {
            OptionsView(settingsStore: runtime.settingsStore)
                .frame(minWidth: 420, minHeight: 280)
        }
    }
}

private struct MenuBarContent: View {
    @Binding var status: String
    let refactorClipboard: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Refactor Clipboard") {
            refactorClipboard()
        }

        Button("Open Options") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "options")
        }

        Text("Status: \(status)")
            .font(.caption)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct OptionsView: View {
    @ObservedObject var settingsStore: UserDefaultsAppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prompt Refactor Options")
                .font(.title3)
                .fontWeight(.semibold)

            Picker("Output mode", selection: outputModeBinding) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }

            Picker("Prompt style", selection: promptStyleBinding) {
                ForEach(PromptStyle.allCases, id: \.rawValue) { style in
                    Text(style.displayTitle).tag(style.rawValue)
                }
            }

            Picker("Shortcut", selection: shortcutPresetBinding) {
                ForEach(ShortcutPreset.allCases) { preset in
                    Text(preset.title).tag(preset.rawValue)
                }
            }

            Toggle("Include clarifying questions", isOn: includeClarifyingQuestionsBinding)
            Toggle("Use Groq refinement (coming in M3)", isOn: useGroqRefinementBinding)

            Spacer()

            Text("Settings are saved automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var outputModeBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.outputModeRawValue },
            set: { settingsStore.updateOutputModeRawValue($0) }
        )
    }

    private var promptStyleBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.promptStyleRawValue },
            set: { settingsStore.updatePromptStyleRawValue($0) }
        )
    }

    private var shortcutPresetBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.shortcutPresetRawValue },
            set: { settingsStore.updateShortcutPresetRawValue($0) }
        )
    }

    private var includeClarifyingQuestionsBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.includeClarifyingQuestions },
            set: { settingsStore.updateIncludeClarifyingQuestions($0) }
        )
    }

    private var useGroqRefinementBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.useGroqRefinement },
            set: { settingsStore.updateUseGroqRefinement($0) }
        )
    }
}
