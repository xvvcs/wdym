# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**wdym** ("What do you mean?") is a macOS menu bar app (Swift 6.0, macOS 14+) that captures text from any focused field via a global hotkey, refines it into a clean prompt using local processing or Groq LLM, and replaces/copies the result. Privacy-first: no history, no analytics, API keys in Keychain.

## Build & Test Commands

```bash
# Core library tests (Swift Package)
swift test

# App tests (Xcode project)
xcodebuild \
  -project "PromptRefactorApp/PromptRefactorApp.xcodeproj" \
  -scheme "PromptRefactorApp" \
  -destination "platform=macOS" \
  -only-testing:PromptRefactorAppTests \
  test

# Open in Xcode (build & run the PromptRefactorApp scheme)
open PromptRefactorApp/PromptRefactorApp.xcodeproj
```

Requirements: Xcode 16+, macOS 14+.

## Architecture

**Hybrid setup:** Swift Package (`PromptRefactorCore`) for testable business logic + Xcode app target for UI/platform code.

### Core Library (`Sources/PromptRefactorCore/`)

Pure logic, no platform dependencies:
- `PromptRefactorService` — main refactor orchestration
- `PromptStyle` — 6 prompt styles (General, Coding, Writing, Search, Research, Best Practices)
- `LLMProvider` — provider abstraction protocol
- `RefactorBuildOptions` — configuration options

### App (`PromptRefactorApp/PromptRefactorApp/`)

Organized by domain, not by type:

- **Platform/Hotkey/** — Global shortcut registration and recording (`HotkeyService`, `ShortcutRecorder`)
- **Platform/Accessibility/** — macOS AX API for reading/writing focused text fields
- **Platform/Storage/** — `KeychainStore` (API keys), `AppSettingsStore` (UserDefaults prefs)
- **Platform/Clipboard/** — Clipboard read/write and paste monitoring
- **Platform/Interaction/** — Terminal control (`KittyRemoteControlService` for Kitty/OpenCode integration)
- **Providers/Groq/** — Groq API client (`GroqProvider`, `GroqRequestBuilder`, `GroqModels`)
- **Providers/ProviderFactory** — Multi-provider selection from settings
- **Features/Setup/** — Onboarding UI

### Key Flow

Global hotkey → capture text (AX focused field or clipboard fallback) → `PromptRefactorService` local cleanup → optional Groq LLM refinement → replace in field / copy to clipboard.

## Conventions

- **Git commits:** Conventional format `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci)
- **Immutability:** Return new objects, never mutate existing ones
- **File size:** Keep files under 800 lines; prefer many small files
- **Security:** API keys only in Keychain; validate all external input; no secrets in code
