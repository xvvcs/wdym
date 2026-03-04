# Onboarding Wizard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a 4-step first-launch setup wizard that guides users through Accessibility permission, shortcut selection, optional Groq API key, and a "ready" screen — shown once on first launch, re-triggerable from the menu bar popover.

**Architecture:** A new `WindowGroup(id: "setup")` scene is added to `PromptRefactorAppApp`. A single `@AppStorage("setupCompleted")` boolean gates first-launch detection. `MenuBarContent` opens the setup window on first appearance when `setupCompleted == false`. `SetupFlowView` owns a `@State var step: SetupStep` enum and renders each step as a private subview, delegating all real work to the existing `AppRuntimeController`.

**Tech Stack:** SwiftUI (WindowGroup, AppStorage, task modifier), existing `AppRuntimeController`, existing `UserDefaultsAppSettingsStore`, `HotkeyModels.swift` (ShortcutPreset).

---

### Task 1: Expose `pollAccessibilityState()` on `AppRuntimeController`

**Files:**
- Modify: `PromptRefactorApp/PromptRefactorApp/AppRuntimeController.swift`

The setup wizard's Step 1 needs to re-check accessibility every second without triggering the system permission dialog again. `refreshAccessibilityState()` is currently `private`. Expose a lightweight public wrapper.

**Step 1: Add the method**

In `AppRuntimeController.swift`, add directly after `openAccessibilitySettings()`:

```swift
func pollAccessibilityState() {
    refreshAccessibilityState()
}
```

**Step 2: Build to verify no errors**

```bash
cd PromptRefactorApp && xcodebuild -project PromptRefactorApp.xcodeproj -scheme PromptRefactorApp -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PromptRefactorApp/PromptRefactorApp/AppRuntimeController.swift
git commit -m "Expose pollAccessibilityState on AppRuntimeController for setup wizard"
```

---

### Task 2: Create `SetupFlowView`

**Files:**
- Create: `PromptRefactorApp/PromptRefactorApp/Features/Setup/SetupFlowView.swift`

This is the entire wizard UI. It owns step state, delegates actions to `AppRuntimeController`, and calls `onComplete` when the user taps "Start Using wdym" on Step 4.

**Step 1: Create the file**

Create `PromptRefactorApp/PromptRefactorApp/Features/Setup/SetupFlowView.swift` with the following content:

```swift
import AppKit
import PromptRefactorCore
import SwiftUI

struct SetupFlowView: View {
    @ObservedObject var runtime: AppRuntimeController
    let onComplete: () -> Void

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
                        ReadyStepView(runtime: runtime, onComplete: onComplete)
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
            ForEach(Array(steps.enumerated()), id: \.offset) { index, s in
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
                subtitle: "wdym needs this to read and replace text in any app. Without it, the app won't work."
            )

            Button("Open System Settings") {
                runtime.requestAccessibilityAccess()
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
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                runtime.pollAccessibilityState()
            }
        }
    }
}

// MARK: - Step 2: Shortcut

private struct ShortcutStepView: View {
    @ObservedObject var settingsStore: UserDefaultsAppSettingsStore
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                title: "Choose Your Shortcut",
                subtitle: "Press this from any app to trigger wdym. You can customise further in Options."
            )

            Picker("Shortcut", selection: shortcutPresetBinding) {
                ForEach(ShortcutPreset.allCases) { preset in
                    Text(preset.title).tag(preset.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Active: \(settingsStore.settings.activeShortcutBinding.title)")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.55))

            Spacer()

            Button("Next →") { onNext() }
                .buttonStyle(FilledSetupButtonStyle())
        }
    }

    private var shortcutPresetBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.shortcutPresetRawValue },
            set: { settingsStore.updateShortcutPresetRawValue($0) }
        )
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
                subtitle: "Optional. Add a Groq API key for LLM-powered prompt polish. Free tier available at console.groq.com."
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
                    runtime.saveGroqAPIKey()
                    onNext()
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
                subtitle: "Place your cursor in any text field, press \(runtime.settingsStore.settings.activeShortcutBinding.title), and wdym will clean up and structure whatever you wrote."
            )

            VStack(alignment: .leading, spacing: 8) {
                summaryRow(label: "Shortcut", value: runtime.settingsStore.settings.activeShortcutBinding.title)
                summaryRow(label: "AI Refinement", value: runtime.hasStoredGroqAPIKey ? "Groq enabled" : "Local only")
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
```

**Step 2: Build to verify no errors**

```bash
cd PromptRefactorApp && xcodebuild -project PromptRefactorApp.xcodeproj -scheme PromptRefactorApp -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PromptRefactorApp/PromptRefactorApp/Features/Setup/SetupFlowView.swift
git commit -m "Add SetupFlowView with 4-step onboarding wizard"
```

---

### Task 3: Wire setup window into `PromptRefactorAppApp`

**Files:**
- Modify: `PromptRefactorApp/PromptRefactorApp/PromptRefactorAppApp.swift`

Three changes to this file:
1. Add `WindowGroup(id: "setup")` scene rendering `SetupFlowView`
2. Make `MenuBarContent` open the setup window on first appearance
3. Add "Rerun Setup" link at the bottom of the menu bar popover

**Step 1: Apply changes**

In `PromptRefactorAppApp.swift`:

a) In `PromptRefactorAppApp.body`, add the setup scene after the existing `WindowGroup("Options", ...)`:

```swift
WindowGroup("Setup", id: "setup") {
    SetupFlowView(runtime: runtime) {
        setupCompleted = true
    }
    .fixedSize()
}
.windowResizability(.contentSize)
.defaultPosition(.center)
```

b) Add `@AppStorage("setupCompleted") private var setupCompleted = false` to `PromptRefactorAppApp`.

c) Update `MenuBarExtra` content to pass `setupCompleted` binding:

```swift
MenuBarExtra("wdym", systemImage: "wand.and.stars") {
    MenuBarContent(
        status: $runtime.status,
        refactorNow: runtime.refactorNow,
        setupCompleted: $setupCompleted
    )
}
```

d) Update `MenuBarContent` to:
- Accept `setupCompleted: Binding<Bool>`
- Add `@Environment(\.openWindow) private var openWindow`
- Add `.task { if !setupCompleted { openWindow(id: "setup") } }` on its body
- Add a "Rerun Setup" button above the "Quit" button:

```swift
Button("Rerun Setup") {
    openWindow(id: "setup")
}
.buttonStyle(.plain)
.font(.subheadline)
.foregroundStyle(Color.white.opacity(0.5))
.frame(maxWidth: .infinity, alignment: .trailing)
```

**Step 2: Build to verify no errors**

```bash
cd PromptRefactorApp && xcodebuild -project PromptRefactorApp.xcodeproj -scheme PromptRefactorApp -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PromptRefactorApp/PromptRefactorApp/PromptRefactorAppApp.swift
git commit -m "Wire setup window into app — first-launch auto-open and Rerun Setup link"
```

---

### Task 4: Add the new file to the Xcode project

**Files:**
- Modify: `PromptRefactorApp/PromptRefactorApp.xcodeproj/project.pbxproj`

New Swift files must be added to the Xcode project's compile sources. The safest way is via Xcode itself or via `xcodebuild` — if the file was added directly to disk (not dragged into Xcode), it won't compile.

**Step 1: Verify the file is picked up**

```bash
cd PromptRefactorApp && xcodebuild -project PromptRefactorApp.xcodeproj -scheme PromptRefactorApp -destination "platform=macOS" build 2>&1 | grep -i "SetupFlowView"
```

If it shows a compile error about `SetupFlowView` not found, the file needs to be added to the project manually in Xcode: File → Add Files to "PromptRefactorApp" → select `Features/Setup/SetupFlowView.swift`, ensure "Add to target: PromptRefactorApp" is checked.

**Step 2: Full clean build**

```bash
cd PromptRefactorApp && xcodebuild -project PromptRefactorApp.xcodeproj -scheme PromptRefactorApp -destination "platform=macOS" clean build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit project file if it changed**

```bash
git add PromptRefactorApp/PromptRefactorApp.xcodeproj/project.pbxproj
git commit -m "Add SetupFlowView.swift to Xcode project compile sources"
```

---

### Task 5: Lint

**Step 1: Run swift-format lint**

```bash
swift format lint --strict --recursive PromptRefactorApp/PromptRefactorApp/Features PromptRefactorApp/PromptRefactorApp/PromptRefactorAppApp.swift PromptRefactorApp/PromptRefactorApp/AppRuntimeController.swift
```

Fix any reported issues with:

```bash
swift format format --in-place --recursive PromptRefactorApp/PromptRefactorApp/Features PromptRefactorApp/PromptRefactorApp/PromptRefactorAppApp.swift PromptRefactorApp/PromptRefactorApp/AppRuntimeController.swift
```

**Step 2: Commit if any fixes were applied**

```bash
git add -A && git commit -m "Apply swift-format fixes to onboarding wizard"
```

---

### Task 6: Final verification

**Step 1: Run app tests**

```bash
cd PromptRefactorApp && xcodebuild \
  -project PromptRefactorApp.xcodeproj \
  -scheme PromptRefactorApp \
  -destination "platform=macOS" \
  -only-testing:PromptRefactorAppTests \
  test 2>&1 | tail -30
```

Expected: all tests pass.

**Step 2: Run core package tests**

```bash
cd /path/to/repo && swift test
```

Expected: all tests pass.
