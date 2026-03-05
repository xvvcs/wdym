import AppKit
import PromptRefactorCore
import SwiftUI

struct SetupFlowView: View {
  @ObservedObject var runtime: AppRuntimeController
  let onComplete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var step: SetupStep = .accessibility

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black.opacity(0.95), Color.black.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        StepIndicator(step: step)
          .padding(.top, 28)
          .padding(.bottom, 24)

        Group {
          switch step {
          case .accessibility:
            AccessibilityStepView(runtime: runtime) {
              step = .shortcut
            }
          case .shortcut:
            ShortcutStepView(settingsStore: runtime.settingsStore) {
              step = .groq
            }
          case .groq:
            GroqStepView(runtime: runtime) {
              step = .ready
            }
          case .ready:
            ReadyStepView(runtime: runtime) {
              onComplete()
              dismiss()
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 36)
        .padding(.bottom, 28)
      }
    }
    .preferredColorScheme(.dark)
    .frame(width: 480, height: 400)
  }
}

// MARK: - Step enum

private enum SetupStep: CaseIterable {
  case accessibility, shortcut, groq, ready
}

// MARK: - Step indicator

private struct StepIndicator: View {
  let step: SetupStep

  private let steps: [SetupStep] = SetupStep.allCases

  var body: some View {
    HStack(spacing: 6) {
      ForEach(Array(steps.enumerated()), id: \.offset) { _, s in
        Capsule()
          .fill(s == step ? Color.white : Color.white.opacity(0.22))
          .frame(width: s == step ? 24 : 8, height: 8)
          .animation(.spring(response: 0.3), value: step)
      }
    }
  }
}

// MARK: - Step 1: Accessibility

private struct AccessibilityStepView: View {
  @ObservedObject var runtime: AppRuntimeController
  let onNext: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      stepHeader(
        title: "Grant Accessibility Access",
        subtitle:
          "wdym needs this to read and replace text in any app. Without it, the app won't work."
      )

      Button("Open System Settings") {
        runtime.openAccessibilitySettings()
      }
      .buttonStyle(FilledSetupButtonStyle())

      if runtime.isAccessibilityTrusted {
        Label("Access granted", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.subheadline)
      } else {
        Text("Waiting for permission…")
          .font(.caption)
          .foregroundStyle(Color.white.opacity(0.45))
      }

      Spacer()

      Button("Next →") { onNext() }
        .buttonStyle(FilledSetupButtonStyle())
        .disabled(!runtime.isAccessibilityTrusted)
    }
    .task {
      while !runtime.isAccessibilityTrusted {
        do {
          try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
          return
        }
        runtime.pollAccessibilityState()
      }
    }
  }
}

// MARK: - Step 2: Shortcut

private struct ShortcutStepView: View {
  @ObservedObject var settingsStore: UserDefaultsAppSettingsStore
  let onNext: () -> Void

  @StateObject private var shortcutRecorder = ShortcutRecorder()

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      stepHeader(
        title: "Choose Your Shortcut",
        subtitle: "Press this from any app to trigger wdym."
      )

      VStack(alignment: .leading, spacing: 10) {
        Toggle("Use custom shortcut", isOn: useCustomShortcutBinding)
          .toggleStyle(.switch)
          .foregroundStyle(.white)

        if settingsStore.settings.useCustomShortcut {
          HStack(spacing: 10) {
            Button(shortcutRecorder.isRecording ? "Stop Recording" : "Record Shortcut") {
              toggleRecording()
            }
            .buttonStyle(FilledSetupButtonStyle())
            .frame(maxWidth: 160)

            Text(shortcutRecorder.statusMessage)
              .font(.caption)
              .foregroundStyle(Color.white.opacity(0.62))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        } else {
          Picker("Shortcut", selection: shortcutPresetBinding) {
            ForEach(ShortcutPreset.allCases) { preset in
              Text(preset.title).tag(preset.rawValue)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("Active: \(settingsStore.settings.activeShortcutBinding.title)")
          .font(.caption)
          .foregroundStyle(Color.white.opacity(0.55))
      }

      Spacer()

      Button("Next →") { onNext() }
        .buttonStyle(FilledSetupButtonStyle())
    }
    .onDisappear {
      shortcutRecorder.stopRecording()
    }
  }

  private var shortcutPresetBinding: Binding<String> {
    Binding(
      get: { settingsStore.settings.shortcutPresetRawValue },
      set: { settingsStore.updateShortcutPresetRawValue($0) }
    )
  }

  private var useCustomShortcutBinding: Binding<Bool> {
    Binding(
      get: { settingsStore.settings.useCustomShortcut },
      set: { settingsStore.updateUseCustomShortcut($0) }
    )
  }

  private func toggleRecording() {
    if shortcutRecorder.isRecording {
      shortcutRecorder.stopRecording()
      return
    }

    shortcutRecorder.startRecording { binding in
      settingsStore.updateCustomShortcut(binding)
      settingsStore.updateUseCustomShortcut(true)
    }
  }
}

// MARK: - Step 3: Groq

private struct GroqStepView: View {
  @ObservedObject var runtime: AppRuntimeController
  let onNext: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      stepHeader(
        title: "AI Refinement",
        subtitle:
          "Optional. Add a Groq API key for LLM-powered prompt polish. Free tier available at console.groq.com."
      )

      SecureField("gsk_…", text: $runtime.groqAPIKeyInput)
        .modifier(DarkSetupFieldStyle())

      if !runtime.groqAPIKeyMessage.isEmpty {
        Text(runtime.groqAPIKeyMessage)
          .font(.caption)
          .foregroundStyle(Color.white.opacity(0.65))
      }

      Spacer()

      VStack(spacing: 10) {
        Button("Save & Continue") {
          if runtime.saveGroqAPIKey() {
            onNext()
          }
        }
        .buttonStyle(FilledSetupButtonStyle())
        .disabled(runtime.groqAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button("Skip") { onNext() }
          .buttonStyle(.plain)
          .font(.subheadline)
          .foregroundStyle(Color.white.opacity(0.5))
      }
    }
  }
}

// MARK: - Step 4: Ready

private struct ReadyStepView: View {
  @ObservedObject var runtime: AppRuntimeController
  let onComplete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      stepHeader(
        title: "You're set up.",
        subtitle:
          "Place your cursor in any text field, press \(runtime.settingsStore.settings.activeShortcutBinding.title), and wdym will clean up and structure whatever you wrote."
      )

      VStack(alignment: .leading, spacing: 8) {
        summaryRow(
          label: "Shortcut",
          value: runtime.settingsStore.settings.activeShortcutBinding.title
        )
        summaryRow(
          label: "AI Refinement",
          value: runtime.hasStoredGroqAPIKey ? "Groq enabled" : "Local only"
        )
      }
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.white.opacity(0.06))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.white.opacity(0.12), lineWidth: 1)
          )
      )

      Spacer()

      Button("Start Using wdym") { onComplete() }
        .buttonStyle(FilledSetupButtonStyle())
    }
  }

  private func summaryRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(Color.white.opacity(0.6))
      Spacer()
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white)
    }
  }
}

// MARK: - Shared helpers

private func stepHeader(title: String, subtitle: String) -> some View {
  VStack(alignment: .leading, spacing: 6) {
    Text(title)
      .font(.title2)
      .fontWeight(.semibold)
      .foregroundStyle(.white)

    Text(subtitle)
      .font(.subheadline)
      .foregroundStyle(Color.white.opacity(0.62))
      .fixedSize(horizontal: false, vertical: true)
  }
}

private struct FilledSetupButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(.black)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.white.opacity(configuration.isPressed ? 0.80 : 0.95))
      )
      .opacity(configuration.isPressed ? 0.9 : 1)
  }
}

private struct DarkSetupFieldStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .textFieldStyle(.plain)
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 9)
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
