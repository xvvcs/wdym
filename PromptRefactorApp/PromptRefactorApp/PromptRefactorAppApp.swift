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
      OptionsView(runtime: runtime, settingsStore: runtime.settingsStore)
        .frame(minWidth: 520, minHeight: 460)
    }
  }
}

private struct MenuBarContent: View {
  @Binding var status: String
  let refactorNow: () -> Void

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Prompt Refactor")
          .font(.headline)
          .foregroundStyle(.white)

        Text("Menu Bar Controls")
          .font(.caption)
          .foregroundStyle(Color.white.opacity(0.62))
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Status")
          .font(.caption)
          .fontWeight(.semibold)
          .textCase(.uppercase)
          .foregroundStyle(Color.white.opacity(0.62))

        Text(status)
          .font(.subheadline)
          .foregroundStyle(.white)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .fill(Color.white.opacity(0.08))
          )
      }

      Button("Refactor Now") {
        refactorNow()
      }
      .buttonStyle(FilledActionButtonStyle())

      Button("Open Options") {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "options")
      }
      .buttonStyle(OutlineActionButtonStyle())

      Divider()
        .overlay(Color.white.opacity(0.18))

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.white.opacity(0.7))
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(14)
    .frame(width: 340, alignment: .leading)
    .preferredColorScheme(.dark)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(
          LinearGradient(
            colors: [Color.black.opacity(0.95), Color.black.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    )
  }
}

private struct OptionsView: View {
  @ObservedObject var runtime: AppRuntimeController
  @ObservedObject var settingsStore: UserDefaultsAppSettingsStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Prompt Refactor Options")
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.white)

          Text("Settings are saved automatically.")
            .font(.subheadline)
            .foregroundStyle(Color.white.opacity(0.62))
        }

        settingsCard(
          title: "Refactor Behavior", subtitle: "How prompts are captured and transformed"
        ) {
          settingRow(label: "Output mode") {
            Picker("Output mode", selection: outputModeBinding) {
              ForEach(OutputMode.allCases) { mode in
                Text(mode.title).tag(mode.rawValue)
              }
            }
            .accessibilityIdentifier("options.picker.outputMode")
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 260)
          }

          settingRow(label: "Prompt style") {
            Picker("Prompt style", selection: promptStyleBinding) {
              ForEach(PromptStyle.allCases, id: \.rawValue) { style in
                Text(style.displayTitle).tag(style.rawValue)
              }
            }
            .accessibilityIdentifier("options.picker.promptStyle")
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 260)
          }

          settingRow(label: "Shortcut") {
            Picker("Shortcut", selection: shortcutPresetBinding) {
              ForEach(ShortcutPreset.allCases) { preset in
                Text(preset.title).tag(preset.rawValue)
              }
            }
            .accessibilityIdentifier("options.picker.shortcut")
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 260)
          }

          Divider()

          Toggle("Include clarifying questions", isOn: includeClarifyingQuestionsBinding)
            .accessibilityIdentifier("options.toggle.includeClarifyingQuestions")
            .toggleStyle(.switch)
          Toggle("Terminal mode (default)", isOn: terminalModeBinding)
            .accessibilityIdentifier("options.toggle.terminalMode")
            .toggleStyle(.switch)
          Toggle("Auto-select all on shortcut", isOn: autoSelectAllBinding)
            .accessibilityIdentifier("options.toggle.autoSelectAll")
            .toggleStyle(.switch)
        }

        settingsCard(
          title: "Kitty Integration",
          subtitle: "Deterministic capture for OpenCode, Codex, and Cloud Code"
        ) {
          Toggle("Require Kitty Remote Control", isOn: kittyRemoteControlRequiredBinding)
            .accessibilityIdentifier("options.toggle.kittyRequired")
            .toggleStyle(.switch)

          TextField("Kitty listen address", text: kittyListenAddressBinding)
            .modifier(DarkFieldStyle())

          HStack(alignment: .top, spacing: 10) {
            Button("Run Kitty Check") {
              runtime.runKittyRemoteControlCheck()
            }
            .buttonStyle(OutlineActionButtonStyle())
            .frame(width: 132)

            Text(runtime.kittyRemoteControlStatusMessage)
              .font(.caption)
              .foregroundStyle(Color.white.opacity(0.72))
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color.white.opacity(0.08))
              )
          }
        }

        settingsCard(title: "AI Provider", subtitle: "Optional post-refactor refinement") {
          Toggle("Use Groq refinement", isOn: useGroqRefinementBinding)
            .accessibilityIdentifier("options.toggle.useGroq")
            .toggleStyle(.switch)

          settingRow(label: "Groq model") {
            Picker("Groq model", selection: groqModelBinding) {
              ForEach(GroqModel.allCases) { model in
                Text(model.title).tag(model.rawValue)
              }
            }
            .accessibilityIdentifier("options.picker.groqModel")
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 260)
          }

          Divider()

          Text("Groq API key")
            .font(.subheadline)
            .fontWeight(.medium)

          SecureField("gsk_...", text: $runtime.groqAPIKeyInput)
            .modifier(DarkFieldStyle())

          HStack(spacing: 10) {
            Button("Save API Key") {
              runtime.saveGroqAPIKey()
            }
            .buttonStyle(OutlineActionButtonStyle())

            Button("Clear") {
              runtime.clearGroqAPIKey()
            }
            .buttonStyle(OutlineActionButtonStyle())

            Text(runtime.hasStoredGroqAPIKey ? "Saved" : "Not set")
              .font(.caption)
              .foregroundStyle(runtime.hasStoredGroqAPIKey ? .white : Color.white.opacity(0.62))
          }

          if !runtime.groqAPIKeyMessage.isEmpty {
            Text(runtime.groqAPIKeyMessage)
              .font(.caption)
              .foregroundStyle(Color.white.opacity(0.72))
          }
        }

        settingsCard(
          title: "Accessibility", subtitle: "Permission is required for in-place replacement"
        ) {
          Label(
            runtime.isAccessibilityTrusted ? "Enabled" : "Not granted",
            systemImage: runtime.isAccessibilityTrusted
              ? "checkmark.circle" : "exclamationmark.circle"
          )
          .font(.subheadline)

          HStack {
            Button("Request Access") {
              runtime.requestAccessibilityAccess()
            }
            .buttonStyle(OutlineActionButtonStyle())

            Button("Open Settings") {
              runtime.openAccessibilitySettings()
            }
            .buttonStyle(OutlineActionButtonStyle())
          }
        }
      }
      .padding(20)
      .frame(maxWidth: 760, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .preferredColorScheme(.dark)
    }
    .scrollIndicators(.visible)
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.95), Color.black.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
  }

  private func settingsCard<Content: View>(
    title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
          .foregroundStyle(.white)

        Text(subtitle)
          .font(.caption)
          .foregroundStyle(Color.white.opacity(0.62))
      }

      content()
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.white.opacity(0.06))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    )
  }

  private func settingRow<Control: View>(label: String, @ViewBuilder control: () -> Control)
    -> some View
  {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label)
        .frame(width: 120, alignment: .leading)
        .foregroundStyle(Color.white.opacity(0.9))

      Spacer(minLength: 0)

      control()
    }
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

  private var groqModelBinding: Binding<String> {
    Binding(
      get: { settingsStore.settings.groqModelRawValue },
      set: { settingsStore.updateGroqModelRawValue($0) }
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

  private var terminalModeBinding: Binding<Bool> {
    Binding(
      get: { settingsStore.settings.terminalModeEnabled },
      set: { settingsStore.updateTerminalModeEnabled($0) }
    )
  }

  private var autoSelectAllBinding: Binding<Bool> {
    Binding(
      get: { settingsStore.settings.autoSelectAllOnTrigger },
      set: { settingsStore.updateAutoSelectAllOnTrigger($0) }
    )
  }

  private var kittyRemoteControlRequiredBinding: Binding<Bool> {
    Binding(
      get: { settingsStore.settings.kittyRemoteControlRequired },
      set: { settingsStore.updateKittyRemoteControlRequired($0) }
    )
  }

  private var kittyListenAddressBinding: Binding<String> {
    Binding(
      get: { settingsStore.settings.kittyListenAddress },
      set: { settingsStore.updateKittyListenAddress($0) }
    )
  }
}

private struct FilledActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.black)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.white.opacity(configuration.isPressed ? 0.82 : 0.95))
      )
  }
}

private struct OutlineActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.07))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.white.opacity(0.2), lineWidth: 1)
          )
      )
  }
}

private struct DarkFieldStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .textFieldStyle(.plain)
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.white.opacity(0.08))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.white.opacity(0.16), lineWidth: 1)
          )
      )
  }
}
