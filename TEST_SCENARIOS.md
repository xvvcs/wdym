# Test Scenarios Tracker

Compact tracker for implemented and planned tests.

## Current Automated Tests

### Core Package (`PromptRefactorCore`)

| ID | Test | Scenario | Coverage | Status |
|---|---|---|---|---|
| PRS-001 | `normalizeDictationRemovesFillerWordsAndCleansSpacing` | Input contains filler words and irregular spacing | Filler removal, whitespace cleanup, punctuation append | Done |
| PRS-002 | `normalizeDictationAddsTerminalPunctuationIfMissing` | Input has no ending punctuation | Sentence finalization (`.`) and capitalization | Done |
| PRS-003 | `buildPromptReturnsEmptyStringForEmptyInput` | Input is empty/whitespace | Empty-input guard path in prompt builder | Done |
| PRS-004 | `buildPromptIncludesCodingSpecificInstructions` | Style preset is `.coding` | Style-specific instructions + normalized task inclusion | Done |

Source file: `Tests/PromptRefactorCoreTests/PromptRefactorServiceTests.swift`

### App Target (`PromptRefactorAppTests`)

| ID | Test | Scenario | Coverage | Status |
|---|---|---|---|---|
| APP-001 | `outputModeTitlesMatchExpectedLabels` | Output mode labels are shown in options UI | Stable labels for all output modes | Done |
| APP-002 | `outputModeBehaviorFlagsAreCorrect` | Output mode is mapped to action behavior flags | `shouldReplaceText` and `shouldCopyText` logic | Done |
| APP-003 | `outputModeFallsBackToReplaceAndCopyForInvalidRawValue` | Stored output mode value is invalid | Safe default fallback behavior | Done |
| APP-004 | `appRefactorPreferencesBuildsRefactorOptionsFromStoredValues` | Stored style and clarifying settings are loaded | Refactor option mapping from persisted settings | Done |
| APP-005 | `appRefactorPreferencesFallsBackToGeneralPromptStyleWhenInvalid` | Stored style value is invalid | Safe style fallback to `.general` | Done |
| APP-006 | `promptStyleDisplayTitlesMatchOptionsLabels` | Prompt styles are displayed in options picker | Stable style labels in options UI | Done |
| APP-007 | `shortcutPresetFallsBackToDefaultWhenRawValueInvalid` | Stored shortcut preset value is invalid | Safe shortcut fallback to default (`Cmd+Shift+R`) | Done |
| APP-008 | `shortcutPresetProvidesExpectedKeyBindings` | Shortcut preset is selected | Correct key code and modifier mapping for each preset | Done |
| APP-009 | `hotkeyBindingMatchesEquivalentKeyboardEvent` | Keyboard event matches configured shortcut | Hotkey trigger matching logic | Done |
| APP-010 | `hotkeyBindingRejectsDifferentModifiers` | Keyboard event has same key but different modifiers | Prevent false-positive hotkey triggers | Done |
| APP-011 | `storeLoadsExpectedDefaultValues` | Fresh install / no saved settings | App settings default values | Done |
| APP-012 | `storePersistsUpdatedValuesAcrossInstances` | User changes settings and app reloads | UserDefaults-backed persistence behavior | Done |
| APP-013 | `settingsShortcutPresetFallsBackWhenPersistedValueIsInvalid` | Corrupted/invalid persisted shortcut value | Store-level fallback safety for shortcut preset | Done |
| APP-014 | `groqModelFallbackUsesSpeedFirstDefault` | Stored Groq model is invalid | Safe default model fallback (`llama-3.1-8b-instant`) | Done |
| APP-015 | `providerFactoryReturnsNilWhenGroqDisabled` | Groq toggle is off | Provider is not created while refinement is disabled | Done |
| APP-016 | `providerFactoryReturnsNilWhenApiKeyMissing` | Groq toggle is on but key is missing | Provider creation guard for missing credentials | Done |
| APP-017 | `providerFactoryReturnsGroqProviderWhenEnabledAndConfigured` | Groq toggle is on and key exists | Provider factory wiring for Groq path | Done |
| APP-018 | `groqRequestBuilderProducesSpeedFirstPayload` | LLM request is converted for Groq API | Payload model, temperature, and messages structure | Done |
| APP-019 | `groqProviderReturnsResponseMessageContent` | Groq API returns a valid completion payload | Response decoding and output extraction | Done |
| APP-020 | `groqProviderThrowsForBadStatusCode` | Groq API responds with non-2xx status | Error handling for HTTP failure responses | Done |
| APP-021 | `runtimeLoadsStoredGroqApiKeyIntoSecureFieldState` | App starts with existing Groq key in Keychain | Options secure field preloads saved API key | Done |
| APP-022 | `saveGroqApiKeyKeepsValueAndClearRemovesIt` | User saves then clears API key from options | Saved key remains in secure field and clear resets state | Done |

Source files:
- `PromptRefactorApp/PromptRefactorAppTests/PromptRefactorAppTests.swift`
- `PromptRefactorApp/PromptRefactorApp/AppOptions.swift`
- `PromptRefactorApp/PromptRefactorAppTests/HotkeyServiceTests.swift`
- `PromptRefactorApp/PromptRefactorAppTests/AppSettingsStoreTests.swift`
- `PromptRefactorApp/PromptRefactorAppTests/ProviderFactoryTests.swift`
- `PromptRefactorApp/PromptRefactorAppTests/GroqProviderTests.swift`
- `PromptRefactorApp/PromptRefactorApp/Platform/Hotkey/HotkeyModels.swift`
- `PromptRefactorApp/PromptRefactorApp/Platform/Storage/AppSettingsStore.swift`
- `PromptRefactorApp/PromptRefactorApp/Providers/ProviderFactory.swift`
- `PromptRefactorApp/PromptRefactorApp/Providers/Groq/GroqRequestBuilder.swift`
- `PromptRefactorApp/PromptRefactorApp/Providers/Groq/GroqProvider.swift`
- `PromptRefactorApp/PromptRefactorAppTests/AppRuntimeControllerTests.swift`

## Planned Next Test Groups

| Group | Scenarios to Add | Priority |
|---|---|---|
| Provider Contracts | Timeout, malformed payload, empty response, retry/backoff | Medium |
| Orchestration | Trigger pipeline success/failure, cancellation on rapid re-trigger | High |
| Accessibility Flow | Permission denied/granted/revoked, focused field read/write failure fallback | High |
| Performance | Local normalization budget and end-to-end latency budget checks | Medium |

## Last Updated

- Date: 2026-03-04
- Command baseline:
  - `swift test` passing (4 tests)
  - `xcodebuild -project "PromptRefactorApp/PromptRefactorApp.xcodeproj" -scheme "PromptRefactorApp" -destination "platform=macOS" -only-testing:PromptRefactorAppTests test` passing (22 tests)
