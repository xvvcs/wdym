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
            MenuBarContent(status: $runtime.status, refactorNow: runtime.refactorNow)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Options", id: "options") {
            OptionsView(runtime: runtime)
                .frame(minWidth: 420, minHeight: 280)
        }
    }
}

private struct MenuBarContent: View {
    @Binding var status: String
    let refactorNow: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Refactor Now") {
            refactorNow()
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
    @ObservedObject var runtime: AppRuntimeController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            Toggle("Terminal mode (default)", isOn: terminalModeBinding)
            Toggle("Auto-select all on shortcut", isOn: autoSelectAllBinding)
            Toggle("Require Kitty Remote Control", isOn: kittyRemoteControlRequiredBinding)

            TextField("Kitty listen address", text: kittyListenAddressBinding)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Run Kitty Check") {
                    runtime.runKittyRemoteControlCheck()
                }

                Text(runtime.kittyRemoteControlStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Use Groq refinement", isOn: useGroqRefinementBinding)

            Picker("Groq model", selection: groqModelBinding) {
                ForEach(GroqModel.allCases) { model in
                    Text(model.title).tag(model.rawValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Accessibility")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if runtime.isAccessibilityTrusted {
                        Text("Enabled")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Not granted")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack {
                    Button("Request Access") {
                        runtime.requestAccessibilityAccess()
                    }

                    Button("Open Settings") {
                        runtime.openAccessibilitySettings()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Groq API key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("gsk_...", text: $runtime.groqAPIKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save API Key") {
                        runtime.saveGroqAPIKey()
                    }

                    Button("Clear") {
                        runtime.clearGroqAPIKey()
                    }

                    if runtime.hasStoredGroqAPIKey {
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Not set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !runtime.groqAPIKeyMessage.isEmpty {
                    Text(runtime.groqAPIKeyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("Settings are saved automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var outputModeBinding: Binding<String> {
        Binding(
            get: { runtime.settingsStore.settings.outputModeRawValue },
            set: { runtime.settingsStore.updateOutputModeRawValue($0) }
        )
    }

    private var promptStyleBinding: Binding<String> {
        Binding(
            get: { runtime.settingsStore.settings.promptStyleRawValue },
            set: { runtime.settingsStore.updatePromptStyleRawValue($0) }
        )
    }

    private var shortcutPresetBinding: Binding<String> {
        Binding(
            get: { runtime.settingsStore.settings.shortcutPresetRawValue },
            set: { runtime.settingsStore.updateShortcutPresetRawValue($0) }
        )
    }

    private var groqModelBinding: Binding<String> {
        Binding(
            get: { runtime.settingsStore.settings.groqModelRawValue },
            set: { runtime.settingsStore.updateGroqModelRawValue($0) }
        )
    }

    private var includeClarifyingQuestionsBinding: Binding<Bool> {
        Binding(
            get: { runtime.settingsStore.settings.includeClarifyingQuestions },
            set: { runtime.settingsStore.updateIncludeClarifyingQuestions($0) }
        )
    }

    private var useGroqRefinementBinding: Binding<Bool> {
        Binding(
            get: { runtime.settingsStore.settings.useGroqRefinement },
            set: { runtime.settingsStore.updateUseGroqRefinement($0) }
        )
    }

    private var terminalModeBinding: Binding<Bool> {
        Binding(
            get: { runtime.settingsStore.settings.terminalModeEnabled },
            set: { runtime.settingsStore.updateTerminalModeEnabled($0) }
        )
    }

    private var autoSelectAllBinding: Binding<Bool> {
        Binding(
            get: { runtime.settingsStore.settings.autoSelectAllOnTrigger },
            set: { runtime.settingsStore.updateAutoSelectAllOnTrigger($0) }
        )
    }

    private var kittyRemoteControlRequiredBinding: Binding<Bool> {
        Binding(
            get: { runtime.settingsStore.settings.kittyRemoteControlRequired },
            set: { runtime.settingsStore.updateKittyRemoteControlRequired($0) }
        )
    }

    private var kittyListenAddressBinding: Binding<String> {
        Binding(
            get: { runtime.settingsStore.settings.kittyListenAddress },
            set: { runtime.settingsStore.updateKittyListenAddress($0) }
        )
    }
}
