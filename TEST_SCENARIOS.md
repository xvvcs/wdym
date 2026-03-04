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
| PRS-005 | `clarifyPromptRemovesParenthesesAndStripsLeadingTrailingQuotes` | Output has parens and is wrapped in quotes | Post-refactor cleanup: removes `()`, strips leading/trailing `"` | Done |
| PRS-005b | `clarifyPromptStripsLeadingAndTrailingDoubleQuotes` | Output is wrapped in double quotes | Strips surrounding quotes for clear prompt | Done |
| PRS-006 | `clarifyPromptPreservesCommasDotsExclamationMarksAndQuestionMarks` | Output has punctuation | Preserves `,.!?` in clarified prompt | Done |
| PRS-007 | `clarifyPromptReturnsEmptyForEmptyInput` | Input is empty/whitespace | Empty-input guard path | Done |

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
| APP-023 | `refactorNowUsesFocusedFieldAndReplacesPlusCopiesOutput` | Focused editable field text is available | Replaces focused text and copies output in default mode | Done |
| APP-024 | `refactorNowUsesSelectionCopyWhenFocusedFieldUnavailable` | AX value read fails but selected text exists | Cmd+C capture fallback + paste replacement path | Done |
| APP-025 | `refactorNowSkipsSecretLikeInput` | Input resembles API token | Secret guard prevents processing and output writes | Done |
| APP-026 | `requestAccessibilityAccessOpensSettingsWhenNotTrusted` | User triggers accessibility request while not trusted | Request flow opens accessibility settings and updates status | Done |
| APP-027 | `requestAccessibilityAccessDoesNothingWhenAlreadyTrusted` | Accessibility permission already granted | Request flow avoids redundant prompts and preserves trusted state | Done |
| APP-028 | `refactorNowReportsAccessibilityMissingWhenNotTrusted` | Accessibility is not granted but clipboard has text | Status explicitly reports missing accessibility permission during replace attempt | Done |
| APP-029 | `refactorNowDoesNotReuseStaleClipboardWhenSelectionCopyFails` | AX read and Cmd+C capture both fail | Prevent stale clipboard reprocessing loop | Done |
| APP-030 | `refactorNowSkipsSelectAllWhenAutoSelectSettingDisabled` | Auto-select setting is disabled | Command pipeline copies without issuing Cmd+A | Done |
| APP-031 | `storeDefaultsEnableTerminalModeAndAutoSelectAll` | Fresh settings initialization | Terminal mode and auto-select defaults are enabled | Done |
| APP-032 | `refactorNowUsesKittyShortcutFallbackProfile` | Frontmost app is Kitty terminal | Uses terminal shortcut fallback profile for select/copy capture | Done |
| APP-033 | `refactorNowUsesKittyRemoteControlWhenRequiredAndAvailable` | Kitty RC mode is required and reachable | Reads selected text via Kitty RC and replaces via paste flow | Done |
| APP-034 | `refactorNowRequiresKittyRemoteControlWhenUnavailable` | Kitty RC mode is required but not reachable | Fails fast with explicit RC setup status and no silent fallback | Done |
| APP-035 | `runKittyRemoteControlCheckUpdatesStatusMessage` | User triggers manual Kitty diagnostics check | Options diagnostics state includes resolved Kitty socket address from probe result | Done |
| APP-036 | `checkConnectionResolvesToHighestPidSocketWhenBasePathMissing` | Configured unix socket base path is missing but PID-suffixed sockets exist | Auto-resolves Kitty PID-suffixed socket and connects successfully | Done |
| APP-037 | `checkConnectionFallsBackToLowerPidSocketWhenNewestCandidateFails` | Highest PID socket is stale but older candidate is reachable | Retries PID candidates in descending order until one responds | Done |
| APP-038 | `checkConnectionUsesConfiguredAddressWhenSocketPathExists` | Configured socket path exists directly | Preserves explicit socket address without PID scan override | Done |
| APP-039 | `readFocusedSelectionUsesResolvedPidSocket` | Selection capture runs with base path and only PID socket exists | PID-suffixed socket resolution is shared by text capture command | Done |
| APP-040 | `checkConnectionAddsKittyLookupPathsToProcessEnvironment` | GUI app environment does not expose a path to `kitten` | Runner PATH is augmented with common Kitty install directories before invoking `kitten @` | Done |
| APP-041 | `refactorNowFallsBackToVisibleScreenTextWhenKittySelectionEmpty` | Kitty RC selection is empty in focused terminal app | Runtime falls back to focused screen text and continues replace/copy flow | Done |
| APP-042 | `readFocusedScreenTextUsesScreenExtent` | Kitty RC screen text capture is requested | Service invokes `kitten @ get-text --extent screen --add-cursor --add-wrap-markers` and returns cursor-anchored prompt text | Done |
| APP-043 | `readFocusedScreenTextExtractsPromptFieldLineWhenVisible` | Focused screen text includes OpenCode transcript and prompt line | Service extracts prompt-field line and excludes transcript/footer hints | Done |
| APP-044 | `readFocusedScreenTextExtractsPromptFieldContinuationLines` | Prompt-field content spans multiple visible continuation lines | Service stitches continuation lines into one prompt string before returning | Done |
| APP-045 | `readFocusedScreenTextReturnsEmptySelectionWhenPromptFieldCannotBeDetected` | Screen fallback sees only transcript/output with no prompt markers | Service rejects whole-screen capture and reports empty selection instead | Done |
| APP-046 | `readFocusedScreenTextSkipsComposerMetadataAndTranscript` | OpenCode composer footer includes mode/model/variant under prompt input | Service ignores metadata/footer/transcript and returns only prompt input line | Done |
| APP-047 | `readFocusedScreenTextReturnsEmptySelectionWithoutCursorMetadata` | Screen fallback output does not include Kitty cursor trailer | Service rejects non-cursor-anchored capture to avoid transcript/footer false positives | Done |
| APP-048 | `storePublishesUpdatedSettingsImmediately` | User updates a settings control in Options | Store publishes state updates immediately so controls reflect changes without repeated interaction | Done |
| APP-049 | `storePublishesForEveryDistinctSettingChange` | User changes multiple options in one session | Store publishes each distinct change so toggles and dependent controls stay in sync | Done |
| APP-050 | `storeDoesNotPublishWhenValueDoesNotChange` | User clicks an option that resolves to the same value | Store avoids redundant publishes and unnecessary UI churn | Done |
| APP-051 | `runtimeUpdatesHotkeyBindingWhenCustomShortcutChanges` | User enables custom shortcut and records a new key combo | Runtime updates active global hotkey binding without restart | Done |
| APP-052 | `hotkeyBindingCaptureRejectsEventsWithoutModifiers` | User presses a key without modifiers while recording custom shortcut | Recorder guard rejects invalid bare-key shortcut capture | Done |
| APP-053 | `hotkeyBindingTitleFormatsCapturedShortcut` | Custom shortcut binding is displayed in options feedback text | Shortcut title rendering shows normalized modifier + key format | Done |

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
- `PromptRefactorApp/PromptRefactorApp/Platform/Accessibility/AXPermissionService.swift`
- `PromptRefactorApp/PromptRefactorApp/Platform/Accessibility/AXFocusedTextService.swift`
- `PromptRefactorApp/PromptRefactorApp/Platform/Clipboard/ClipboardService.swift`
- `PromptRefactorApp/PromptRefactorApp/Platform/Interaction/TextCommandService.swift`
- `PromptRefactorApp/PromptRefactorApp/Platform/Interaction/KittyRemoteControlService.swift`
- `PromptRefactorApp/PromptRefactorAppTests/KittyRemoteControlServiceTests.swift`

## Planned Next Test Groups

| Group | Scenarios to Add | Priority |
|---|---|---|
| Provider Contracts | Timeout, malformed payload, empty response, retry/backoff | Medium |
| Orchestration | Trigger pipeline success/failure, cancellation on rapid re-trigger | High |
| Accessibility Flow | Permission denied/granted/revoked, focused field read/write failure fallback | Medium |
| Performance | Local normalization budget and end-to-end latency budget checks | Medium |

## Last Updated

- Date: 2026-03-04
- Command baseline:
  - `swift test` passing (7 tests)
  - `xcodebuild -project "PromptRefactorApp/PromptRefactorApp.xcodeproj" -scheme "PromptRefactorApp" -destination "platform=macOS" -only-testing:PromptRefactorAppTests test` passing (53 tests)
