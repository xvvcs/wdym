# Prompt Refactor for Dictation (macOS) — Implementation Plan

## 1) Product Goal

Build a lightweight, fast macOS app (Swift) that takes freshly dictated text from the currently focused input field, refactors it into a clearer AI-ready prompt, and replaces the field text with the improved version.

Primary user flow:
1. User dictates using a speech-to-text tool.
2. Speech tool inserts raw text into the focused field.
3. User presses a global shortcut.
4. App captures full field text, refactors it, and replaces the full field text.

English is the initial focus; architecture should support future multilingual expansion.

## 2) Distribution and Project Style

- Open-source project.
- Direct distribution via notarized `.dmg` (outside Mac App Store).
- Menu bar app to keep footprint small and usage fast.

## 3) Key Decisions (Locked)

- Platform: macOS, Swift.
- Main interaction: global shortcut.
- v1 text replacement strategy: **replace entire field text**.
- Model provider: **Groq** (speed-first setup).
- App should run in background and be available system-wide.

## 4) MVP Scope

### MVP 1 — Core Manual Flow (Priority)

Deliver the exact core workflow:
- Global shortcut triggers refactor.
- Capture currently focused editable field text.
- Refactor text quickly.
- Replace full field text with refactored result.
- Optional copy of refactored output to clipboard.

Minimal settings:
- Shortcut binding.
- Output mode (`Replace + Copy`, `Replace only`, `Copy only`).
- Groq API key.
- Model selection (speed-first default).
- Prompt style preset (basic in v1).

### MVP 2 — Auto Mode

- Optional auto-refactor after text stops changing (debounce/inactivity window).
- Per-app allowlist/blocklist.
- Safer handling for secure/password fields.

### MVP 3 — Polish and OSS Readiness

- Additional presets (coding/email/planning).
- Better app compatibility coverage.
- Optional multilingual support path.
- Stronger diagnostics + UX polish.

## 5) Functional Requirements

- Works system-wide with a global shortcut.
- Captures and replaces text in focused editable fields.
- Runs in background (menu bar app behavior).
- Provides user-selectable output behavior.
- Clear failure fallback (if field replacement fails, still copy output).

## 6) Non-Functional Requirements

- Fast perceived response.
- Lightweight idle behavior (low CPU and memory).
- Privacy-aware defaults (no unnecessary transcript storage).
- Stable under repeated quick invocations.

## 7) Technical Architecture

### App Shell
- `NSStatusItem` menu bar app.
- SwiftUI settings window/panels.

### Core Modules
- `ShortcutOrchestrator`: owns end-to-end trigger flow.
- `FocusedTextReader`: retrieves text from focused AX element.
- `PromptRefactorService`: local cleanup + structured prompt generation.
- `LLMProvider` protocol: model provider abstraction.
- `GroqProvider`: Groq API implementation.
- `FocusedTextWriter`: writes updated text back to focused AX element.

### Data Flow
1. Global shortcut fires.
2. Read focused field text via Accessibility APIs.
3. Run local normalization.
4. Send to Groq for final refactor.
5. Replace full field value.
6. Optional clipboard copy + lightweight status feedback.

### Persistence and Security
- Store API key in Keychain.
- Store preferences in UserDefaults.
- Avoid persistent transcript logging by default.

## 8) TDD-First Implementation Plan

### Phase 1 — Domain Tests
- Create tests for `PromptRefactorService` first.
- Cover dictation cleanup, punctuation recovery, structure creation.
- Include edge-case fixtures from real-world dictation style input.

### Phase 2 — Provider Contract Tests
- Define `LLMProvider` contract and mock provider.
- Test timeout, empty output, malformed payload, retry paths.
- Keep deterministic tests with fixed fixture responses.

### Phase 3 — Orchestration Tests
- Test full shortcut pipeline success/failure paths.
- Test rapid repeated triggers and cancellation behavior.
- Test fallback behavior when AX write fails.

### Phase 4 — Accessibility Integration
- Test permission states (not granted / granted / revoked).
- Test focused field read/write adapters with mocks.
- Add manual QA matrix for common app types.

### Phase 5 — Performance + Packaging
- Add `XCTest.measure` coverage for local pipeline speed.
- Validate end-to-end timing budget.
- Add CI test workflow and release pipeline for signed/notarized `.dmg`.

## 9) Accessibility and System-Wide Strategy

- Build with AX architecture from day one, even if v1 demo path is simpler.
- Include onboarding guidance for Accessibility permissions.
- Add safeguards for non-editable or secure fields.

## 10) Reference Project Note

Use the **FreeFlow open-source speech-to-text project** as a practical reference for Groq-based low-latency behavior and integration patterns. The goal is to mirror its responsiveness principles while keeping this app focused on post-dictation prompt refactoring.

## 11) Definition of Done for MVP 1

- Global shortcut works reliably in background.
- Full focused-field text is captured and replaced with refactored output.
- Groq integration is functional with secure key management.
- Core tests (domain + orchestration + provider) pass in CI.
- App can be built and packaged for direct `.dmg` distribution.

## 12) Confirmed Defaults Before Implementation

- License: **MIT**.
- Default output behavior: **Replace + Copy**.
- Default optimization: **Speed-first model configuration**.
