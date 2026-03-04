# Prompt Refactor for Dictation

Swift-based macOS project for refactoring raw dictation text into clearer AI-ready prompts.

## Current Status

- Implementation plan is documented in `IMPLEMENTATION_PLAN.md`.
- Core TDD scaffolding is in place as a Swift package.
- Menu bar preview app is available in `PromptRefactorApp/PromptRefactorApp.xcodeproj`.
- Groq integration is implemented with key input in the Options window.

## Decisions Locked

- License: MIT
- Default behavior: Replace + Copy
- Provider strategy: Groq speed-first configuration

## Reference

- FreeFlow open-source speech-to-text project is used as a reference point for low-latency Groq integration patterns.

## Run Tests

```bash
swift test
```

```bash
xcodebuild -project "PromptRefactorApp/PromptRefactorApp.xcodeproj" -scheme "PromptRefactorApp" -destination "platform=macOS" -only-testing:PromptRefactorAppTests test
```
