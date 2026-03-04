# Prompt Refactor for Dictation

Swift-based macOS project for refactoring raw dictation text into clearer AI-ready prompts.

## Current Status

- Implementation plan is documented in `IMPLEMENTATION_PLAN.md`.
- Core TDD scaffolding is in place as a Swift package.
- `PromptRefactorService` currently provides deterministic local normalization and prompt construction.

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
