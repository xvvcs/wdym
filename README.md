# wdym

Wdym ("What do you mean") is a macOS menu bar app that refines rough dictation or messy text into clear, useful prompts in seconds.

## What it is for

- Improving prompt quality before sending to your coding assistant or AI tool.
- Speeding up editing flow with a global shortcut from any app.
- Keeping your workflow lightweight: no heavy UI, no extra app windows while you work.

## Highlights

- Menu bar first experience with quick status and controls.
- Output modes for replace, copy, or both.
- Prompt style presets for general and coding use.
- Custom global shortcut support, including user-recorded key combinations.
- Terminal-aware capture with Kitty/OpenCode support.

## Privacy

- No prompt history is stored.
- No analytics or tracking are included.
- Prompt text is handled in memory and discarded after processing.
- With Groq disabled, processing stays local.
- With Groq enabled, only the current prompt text is sent to Groq over HTTPS.
- API keys remain local in macOS Keychain, and app preferences remain local in UserDefaults.

## Download

Download the latest release from the GitHub **Releases** page:

- `wdym-<version>-unsigned.dmg` (recommended)
- `wdym-<version>-unsigned.zip` (fallback)

Move `wdym.app` to `/Applications` and launch.

Because free releases are unsigned, macOS may block first launch:

1. Right-click `wdym.app` and choose **Open**.
2. If needed, go to **System Settings -> Privacy & Security -> Open Anyway**.

Terminal fallback if required:

```bash
xattr -dr com.apple.quarantine /Applications/wdym.app
```

## Quick Start

1. Launch `wdym` from the menu bar.
2. Open **Options** and grant Accessibility permission.
3. Choose output mode, prompt style, and shortcut.
4. Place cursor in a text field (or select text) and press your shortcut.
5. `wdym` refines and applies output using your chosen mode.

## Kitty/OpenCode (optional)

If you use Kitty/OpenCode and want deterministic capture, add this to Kitty config:

```text
allow_remote_control socket-only
listen_on unix:/tmp/prompt-refactor-kitty
```

Then set the same address in `wdym` Options.

## For contributors

- Core package tests: `swift test`
- App tests: `xcodebuild -project "PromptRefactorApp/PromptRefactorApp.xcodeproj" -scheme "PromptRefactorApp" -destination "platform=macOS" -only-testing:PromptRefactorAppTests test`
- Free release workflow: `.github/workflows/release-and-publish.yml`
