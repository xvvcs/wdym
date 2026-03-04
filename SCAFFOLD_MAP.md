# macOS App Scaffold Map (Xcode + Swift)

Detailed, implementation-first scaffold for building a runnable preview quickly, then growing into your full system-wide dictation refactor app.

## 1) Target Architecture

Use a hybrid setup:
- **Xcode app target** for menu bar UX, shortcuts, Accessibility, and previewing.
- **Swift package (`PromptRefactorCore`)** for business logic and tests (already started).

This keeps UI/platform code separate from testable core logic.

## 2) Repository Layout

Planned structure (including existing files):

```text
.
|- Package.swift
|- IMPLEMENTATION_PLAN.md
|- TEST_SCENARIOS.md
|- SCAFFOLD_MAP.md
|- README.md
|- LICENSE
|- Sources/
|  \- PromptRefactorCore/
|     |- PromptRefactorService.swift
|     |- PromptStyle.swift
|     |- RefactorBuildOptions.swift
|     \- LLMProvider.swift
|- Tests/
|  \- PromptRefactorCoreTests/
|     \- PromptRefactorServiceTests.swift
\- App/
   \- PromptRefactorApp/
      |- PromptRefactorApp.xcodeproj
      \- PromptRefactorApp/
         |- PromptRefactorApp.swift
         |- AppDelegate.swift
         |- MenuBar/
         |  |- MenuBarRoot.swift
         |  \- MenuCommands.swift
         |- Features/
         |  |- RefactorNow/
         |  |  |- RefactorNowAction.swift
         |  |  \- RefactorPipeline.swift
         |  |- Settings/
         |  |  |- SettingsView.swift
         |  |  \- SettingsViewModel.swift
         |  \- Onboarding/
         |     \- AccessibilityOnboardingView.swift
         |- Platform/
         |  |- Hotkey/
         |  |  |- HotkeyService.swift
         |  |  \- HotkeyBindingStore.swift
         |  |- Clipboard/
         |  |  \- ClipboardService.swift
         |  |- Accessibility/
         |  |  |- AXPermissionService.swift
         |  |  |- AXFocusedElementReader.swift
         |  |  \- AXFocusedElementWriter.swift
         |  |- Notifications/
         |  |  \- UserNotifier.swift
         |  \- Storage/
         |     |- KeychainStore.swift
         |     \- AppSettingsStore.swift
         |- Providers/
         |  |- Groq/
         |  |  |- GroqProvider.swift
         |  |  |- GroqModels.swift
         |  |  \- GroqRequestBuilder.swift
         |  \- ProviderFactory.swift
         |- Shared/
         |  |- AppState.swift
         |  |- Logger.swift
         |  \- Constants.swift
         \- PromptRefactorAppTests/
            |- RefactorPipelineTests.swift
            |- HotkeyServiceTests.swift
            |- AppSettingsStoreTests.swift
            \- AXPermissionServiceTests.swift
```

## 3) File-by-File Purpose

### App entry and shell
- `App/PromptRefactorApp/PromptRefactorApp/PromptRefactorApp.swift`
  - App entry point; boots menu bar UI and dependency container.
- `App/PromptRefactorApp/PromptRefactorApp/AppDelegate.swift`
  - Lifecycle hooks for startup checks and permission prompts.

### Menu bar UI
- `App/PromptRefactorApp/PromptRefactorApp/MenuBar/MenuBarRoot.swift`
  - Menu bar content (`Refactor Now`, status, settings, quit).
- `App/PromptRefactorApp/PromptRefactorApp/MenuBar/MenuCommands.swift`
  - Command routing and keyboard/menu command definitions.

### Core feature orchestration
- `App/PromptRefactorApp/PromptRefactorApp/Features/RefactorNow/RefactorNowAction.swift`
  - Single action invoked by menu/hotkey.
- `App/PromptRefactorApp/PromptRefactorApp/Features/RefactorNow/RefactorPipeline.swift`
  - End-to-end flow:
    1) capture text (clipboard or focused field),
    2) local refactor,
    3) optional Groq refinement,
    4) replace/copy output,
    5) emit status and telemetry event.

### Settings and onboarding
- `App/PromptRefactorApp/PromptRefactorApp/Features/Settings/SettingsView.swift`
  - UI controls for output mode, provider settings, model, shortcut.
- `App/PromptRefactorApp/PromptRefactorApp/Features/Settings/SettingsViewModel.swift`
  - Bindings and validation for settings state.
- `App/PromptRefactorApp/PromptRefactorApp/Features/Onboarding/AccessibilityOnboardingView.swift`
  - Explain why Accessibility permission is needed and deep-link to System Settings.

### Platform services
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Hotkey/HotkeyService.swift`
  - Registers global shortcut and callback.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Hotkey/HotkeyBindingStore.swift`
  - Saves/loads shortcut binding.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Clipboard/ClipboardService.swift`
  - Clipboard read/write wrapper.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Accessibility/AXPermissionService.swift`
  - Permission state and prompt logic.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Accessibility/AXFocusedElementReader.swift`
  - Reads text from focused editable field.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Accessibility/AXFocusedElementWriter.swift`
  - Replaces full text in focused editable field.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Notifications/UserNotifier.swift`
  - Lightweight success/error notifications.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Storage/KeychainStore.swift`
  - Secure API key storage.
- `App/PromptRefactorApp/PromptRefactorApp/Platform/Storage/AppSettingsStore.swift`
  - UserDefaults-backed settings.

### Provider integration
- `App/PromptRefactorApp/PromptRefactorApp/Providers/Groq/GroqProvider.swift`
  - `LLMProvider` implementation for Groq API.
- `App/PromptRefactorApp/PromptRefactorApp/Providers/Groq/GroqModels.swift`
  - Request/response Codable models.
- `App/PromptRefactorApp/PromptRefactorApp/Providers/Groq/GroqRequestBuilder.swift`
  - Speed-first prompt and model config builder.
- `App/PromptRefactorApp/PromptRefactorApp/Providers/ProviderFactory.swift`
  - Selects provider implementation from settings.

### Shared app state/utilities
- `App/PromptRefactorApp/PromptRefactorApp/Shared/AppState.swift`
  - Central status (`idle`, `running`, `success`, `error`) and mode flags.
- `App/PromptRefactorApp/PromptRefactorApp/Shared/Logger.swift`
  - Unified app logging hooks.
- `App/PromptRefactorApp/PromptRefactorApp/Shared/Constants.swift`
  - Common keys and defaults.

## 4) Milestones (with Exit Criteria)

### Milestone Status

- M0: Complete
- M1: Complete
- M2: Complete
- M3: Complete
- M4: Complete
- M5: Next

### M0 - Foundation (Project setup)

Scope:
- Create Xcode macOS app target in `App/PromptRefactorApp`.
- Link local package `PromptRefactorCore`.
- Add menu bar shell and app state.

Exit criteria:
- App launches and shows menu bar icon.
- `Refactor Now` menu item exists (stub action).

### M1 - Previewable Core Flow (Clipboard)

Scope:
- Implement `ClipboardService`.
- Wire `RefactorPipeline` to read clipboard -> `PromptRefactorService` -> write clipboard.
- Add status feedback and basic error handling.

Exit criteria:
- Manual trigger refactors clipboard text reliably.
- Usable preview in Xcode without AX permission.

### M2 - Global Shortcut + Settings

Scope:
- Add hotkey registration service.
- Implement settings UI for output mode and shortcut.
- Persist settings in `AppSettingsStore`.

Exit criteria:
- Shortcut triggers `Refactor Now` while app is backgrounded.
- Settings survive relaunch.

### M3 - Groq Speed-First Integration

Scope:
- Implement `GroqProvider` and provider selection.
- Add key management with `KeychainStore`.
- Configure speed-first defaults.

Exit criteria:
- App can call Groq and return refined output.
- On API failure, local refactor fallback still works.

### M4 - Focused Field Read/Replace (Primary Workflow)

Scope:
- Implement AX permission onboarding and checks.
- Implement `AXFocusedElementReader` and `AXFocusedElementWriter`.
- Switch default capture mode to focused field; retain clipboard fallback.

Exit criteria:
- In common editable fields, shortcut captures full field text and replaces full field text.
- Permission-denied path is user-friendly and recoverable.

### M5 - Hardening + Packaging

Scope:
- Add more integration tests and performance checks.
- Prepare build scripts/workflow for release artifacts.
- README and docs polish for OSS onboarding.

Exit criteria:
- Stable test baseline.
- Release-ready app bundle path defined (later signed/notarized DMG).

## 5) TDD Map by Milestone

### M0-M1 tests
- `PromptRefactorCoreTests` (already active).
- Add `RefactorPipelineTests` for success/failure and fallback.

### M2 tests
- `HotkeyServiceTests`: registration, rebinding, duplicate prevention.
- `AppSettingsStoreTests`: default values, persistence, migration safety.

### M3 tests
- Provider contract tests with mocked URLSession responses.
- Retry, timeout, malformed payload scenarios.

### M4 tests
- `AXPermissionServiceTests`: all permission states.
- Reader/writer adapter tests via protocol mocks.

### M5 tests
- `XCTest.measure` latency checks for local and full pipeline.

## 6) Recommended Build Order (Practical Sequence)

1. M0 shell (menu bar + dependency wiring).
2. M1 clipboard pipeline (first visible payoff).
3. M2 shortcut + settings persistence.
4. M3 Groq provider + keychain.
5. M4 Accessibility capture/replace.
6. M5 hardening, docs, release pipeline.

## 7) Preview Checklist in Xcode

- Open `App/PromptRefactorApp/PromptRefactorApp.xcodeproj`.
- Select app target and run on local Mac.
- Confirm menu bar icon appears.
- Test `Refactor Now` with clipboard text first.
- Add and test global shortcut.
- Enable Accessibility permission before focused-field integration tests.

## 8) Defaults to Keep Consistent

- License: MIT.
- Default output behavior: Replace + Copy.
- Provider policy: Groq speed-first.
- v1 replacement behavior: replace full field text.
