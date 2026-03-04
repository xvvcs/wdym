# Prompt Refactor for Dictation

Swift-based macOS project for refactoring raw dictation text into clearer AI-ready prompts.

## Current Status

- Implementation plan is documented in `IMPLEMENTATION_PLAN.md`.
- Core TDD scaffolding is in place as a Swift package.
- Menu bar preview app is available in `PromptRefactorApp/PromptRefactorApp.xcodeproj`.
- Groq integration is implemented with key input in the Options window.
- Terminal-first command pipeline is enabled by default (`Cmd+A` -> `Cmd+C` -> refactor -> `Cmd+V`) with focused-field AX fallback.
- Kitty deterministic mode is available: when enabled, Kitty/OpenCode capture requires Kitty Remote Control (`kitten @`) and does not silently fall back.

## Kitty/OpenCode Setup (Deterministic)

Add this to your Kitty config and restart Kitty:

```text
allow_remote_control socket-only
listen_on unix:/tmp/prompt-refactor-kitty
```

Then set the same listen address in Prompt Refactor Options.

Note: Kitty appends a PID suffix to UNIX socket paths (for example `/tmp/prompt-refactor-kitty-73492`). If you set the base path (`unix:/tmp/prompt-refactor-kitty`) in Prompt Refactor, the app auto-detects active PID-suffixed sockets and the Options check shows the resolved address.

When running full-screen terminal apps (like OpenCode) where selection can be empty, Prompt Refactor falls back to focused screen text using Kitty cursor metadata (`--add-cursor`) and extracts only cursor-anchored prompt input. It ignores composer metadata rows (mode/model/variant) and transcript lines; if prompt input cannot be detected confidently, it returns empty instead of using the full screen transcript.

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
