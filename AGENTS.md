# AGENTS.md

Guidance for coding agents working in this repository.

## Project Snapshot

- Language: Swift (Swift tools 6.0).
- Package manager: Swift Package Manager.
- Platform target: macOS 14+.
- Primary module: `PromptRefactorCore`.
- Test module: `PromptRefactorCoreTests`.
- Current architecture is package-first (no checked-in Xcode app target yet).

## Source Layout

- `Package.swift` defines one library target and one test target.
- `Sources/PromptRefactorCore/` contains production code.
- `Tests/PromptRefactorCoreTests/` contains automated tests.
- `.build/` is local build output and should not be committed.

## Cursor / Copilot Rules

I checked the repository for additional agent rules:

- `.cursorrules`: not present.
- `.cursor/rules/`: not present.
- `.github/copilot-instructions.md`: not present.

If any of these files are added later, treat them as required constraints and merge them into this guide.

## Setup / Environment

- Verify Swift toolchain: `swift --version`.
- Resolve dependencies (safe even when none external): `swift package resolve`.
- Clean build artifacts when needed: `swift package clean`.

## Build Commands

- Debug build: `swift build`.
- Release build: `swift build -c release`.
- Build a specific target: `swift build --target PromptRefactorCore`.
- Verbose build logs: `swift build -v`.

## Lint and Formatting Commands

This repo currently has no `SwiftLint` config and no CI lint script.
Use `swift-format` as the canonical style checker/formatter.

- Lint package manifest: `swift format lint --strict Package.swift`.
- Lint sources and tests recursively: `swift format lint --strict --recursive Sources Tests`.
- Auto-format manifest: `swift format format --in-place Package.swift`.
- Auto-format sources/tests: `swift format format --in-place --recursive Sources Tests`.

If a formatter config file is added later, pass it via `--configuration <path>`.

## Test Commands

- Run full test suite: `swift test`.
- List discovered tests: `swift test list`.
- Run tests in parallel: `swift test --parallel`.
- Run with code coverage: `swift test --enable-code-coverage`.
- Show latest coverage artifact path: `swift test --show-codecov-path`.

### Run a Single Test (Important)

Use `swift test --filter` with the fully qualified test name from `swift test list`.

- Example exact test:
  `swift test --filter "PromptRefactorCoreTests.normalizeDictationAddsTerminalPunctuationIfMissing"`
- Example by pattern:
  `swift test --filter "PromptRefactorCoreTests.buildPrompt.*"`

Notes:

- Prefer exact filters in CI scripts for deterministic runs.
- When adding tests, verify they appear in `swift test list` output.

## Code Style Guidelines

These rules are based on existing repository conventions.

### Imports

- Import only what the file uses.
- Prefer `Foundation` only when needed (e.g., string processing utilities).
- In tests, use:
  - `import Testing`
  - `@testable import PromptRefactorCore`
- Avoid unused imports and wildcard-style import patterns.

### Formatting

- Use 4-space indentation; do not use tabs.
- Keep braces on the same line as declarations/control statements.
- Use trailing commas in multi-line collection/function argument literals.
- Use blank lines to separate logical phases (setup, transform, return).
- Keep files tidy and focused; prefer small helpers over long monolith methods.

### Types and API Design

- Prefer `struct` for value-semantic domain/services unless reference semantics are required.
- Mark cross-boundary types/protocols as `Sendable` when concurrency-safe.
- Keep public API surface explicit with `public` access modifiers.
- Keep helper implementation details `private`.
- Provide explicit initializers when exposing configurable options.

### Naming Conventions

- Types/protocols: UpperCamelCase (e.g., `PromptRefactorService`).
- Functions/properties/variables: lowerCamelCase.
- Enum cases: lowerCamelCase.
- Boolean names should read as predicates/flags (`includeClarifyingQuestions`).
- Test names should be descriptive scenario-style lowerCamelCase.

### Control Flow and Readability

- Prefer `guard` for early exits on invalid/empty input.
- Keep data transformations explicit and ordered.
- Minimize hidden side effects in core logic.
- Use small pure helper methods for repeated transforms.

### Error Handling

- Use `throws` for recoverable failures at integration boundaries.
- Return safe defaults for non-error guard paths when appropriate.
- Avoid `fatalError` in production paths.
- Preserve error context rather than swallowing failures silently.

### Concurrency

- Keep core services deterministic and side-effect-light.
- For async provider boundaries, keep protocol contracts explicit (`async throws`).
- Ensure new shared state is concurrency-safe before marking `Sendable`.
- Avoid introducing shared mutable state without clear synchronization.

### String and Text Processing

- Prefer deterministic normalization steps.
- Keep regex usage localized and test-covered.
- Re-trim and sanitize spacing/punctuation after regex replacements.
- Preserve user intent; avoid semantic drift during normalization.

### Testing Conventions

- Use Swift Testing (`@Test`, `#expect`) rather than XCTest style in this package.
- Make sure to update the `TEST_SCENARIOS.md` file after adding new tests or scenarios.
- Keep tests deterministic; avoid network/time/random dependencies.
- Follow Arrange-Act-Assert structure with spacing between phases.
- Validate both happy paths and edge/empty input behavior.
- When fixing bugs, add or update a test that fails before the fix.
- After any major or new changes - check for any new regressions.
- Iterate over implementation if tests that are not supposed to fail, fail.

## Change Management Guidelines for Agents

- Make minimal, targeted edits that match existing style.
- Do not introduce new frameworks/tooling unless requested.
- Update docs/tests alongside behavior changes.
- Prefer additive changes over broad refactors unless explicitly requested.
- Before finishing, run lint + relevant tests for touched code.

## Quick Pre-PR Checklist

- `swift format lint --strict Package.swift`
- `swift format lint --strict --recursive Sources Tests`
- `swift test`
- If applicable, run the exact impacted test with `swift test --filter ...`
- Confirm no accidental edits in `.build/` or local machine files
