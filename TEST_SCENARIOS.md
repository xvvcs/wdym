# Test Scenarios Tracker

Compact tracker for implemented and planned tests.

## Current Automated Tests

| ID | Test | Scenario | Coverage | Status |
|---|---|---|---|---|
| PRS-001 | `normalizeDictationRemovesFillerWordsAndCleansSpacing` | Input contains filler words and irregular spacing | Filler removal, whitespace cleanup, punctuation append | Done |
| PRS-002 | `normalizeDictationAddsTerminalPunctuationIfMissing` | Input has no ending punctuation | Sentence finalization (`.`) and capitalization | Done |
| PRS-003 | `buildPromptReturnsEmptyStringForEmptyInput` | Input is empty/whitespace | Empty-input guard path in prompt builder | Done |
| PRS-004 | `buildPromptIncludesCodingSpecificInstructions` | Style preset is `.coding` | Style-specific instructions + normalized task inclusion | Done |

Source file: `Tests/PromptRefactorCoreTests/PromptRefactorServiceTests.swift`

## Planned Next Test Groups

| Group | Scenarios to Add | Priority |
|---|---|---|
| Provider Contracts | Timeout, malformed payload, empty response, retry/backoff | High |
| Orchestration | Trigger pipeline success/failure, cancellation on rapid re-trigger | High |
| Accessibility Flow | Permission denied/granted/revoked, focused field read/write failure fallback | High |
| Performance | Local normalization budget and end-to-end latency budget checks | Medium |

## Last Updated

- Date: 2026-03-03
- Command baseline: `swift test` passing (4 tests)
