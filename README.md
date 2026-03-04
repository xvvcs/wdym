<div align="center">
<img width="200" height="223" alt="image" src="https://github.com/user-attachments/assets/981f1089-172e-4a1d-803f-bb8c230b939b" />

<h1>wdym</h1>

<p><strong>What do you mean?</strong> — Turn rough dictation and messy text into sharp, AI-ready prompts in seconds.</p>

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://github.com/xvvcs/wdym/releases)
[![Swift](https://img.shields.io/badge/Swift-6.0-f05138?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Releases](https://img.shields.io/github/v/release/xvvcs/wdym?label=latest)](https://github.com/xvvcs/wdym/releases)

</div>

---

## What is wdym?

**wdym** is a lightweight macOS menu bar app for people who think faster than they type or dictate.

Press a global shortcut from **any app**, and wdym instantly captures whatever is in your focused text field, cleans it up, and replaces it with a clear, structured prompt — ready for your AI coding assistant, chat tool, or search bar.

No window switching. No copy-paste loops. Just better prompts, instantly.

---

## Screenshots / Demo

> 📸 _Screenshots and a short demo video will be added here once the first public release is available._
>
> <!-- Replace the section below with actual screenshots or a demo GIF/video -->
>
> | Menu Bar | Options Panel |
> |----------|---------------|
> | _screenshot coming soon_ | _screenshot coming soon_ |

---

## Highlights

| Feature | Details |
|---------|---------|
| 🖥️ **Menu bar first** | Lives quietly in your menu bar — no Dock icon, no windows in the way |
| ⌨️ **Global shortcut** | Trigger from any app with a fully customisable key combination |
| ✏️ **Smart cleanup** | Removes filler words, fixes punctuation, and structures your intent |
| 🤖 **AI refinement** | Optional Groq integration for fast, high-quality LLM polish |
| 🎨 **Prompt styles** | General, Coding, Writing, Search, Research, Best Practices |
| 📋 **Flexible output** | Replace in-field, copy to clipboard, or both — your choice |
| 🐱 **Terminal-aware** | First-class Kitty/OpenCode support via remote control integration |
| 🔒 **Privacy first** | No history, no analytics — keys in Keychain, prefs in UserDefaults |

---

## Installation

### Download (recommended)

**Latest release:** [**v1.2.0**](https://github.com/xvvcs/wdym/releases/latest) <!-- README_VERSION -->

1. Grab the latest from the [**Releases page**](https://github.com/xvvcs/wdym/releases):
   - `wdym_installer.dmg` — drag-and-drop installer
   - `wdym_installer.zip` — manual fallback
2. Move `wdym.app` to `/Applications` and launch it.

> **Note:** Free releases are unsigned. macOS may block first launch.
>
> - Right-click `wdym.app` → **Open**, or
> - **System Settings → Privacy & Security → Open Anyway**
>
> Terminal fallback:
> ```bash
> xattr -dr com.apple.quarantine /Applications/wdym.app
> ```

### Build from source

Requirements: Xcode 16+, macOS 14+

```bash
git clone https://github.com/xvvcs/wdym.git
cd wdym
open PromptRefactorApp/PromptRefactorApp.xcodeproj
```

Build and run the `PromptRefactorApp` scheme on your local Mac.

---

## Quick Start

1. **Launch** `wdym` — a menu bar icon appears.
2. Open **Options** and grant **Accessibility** permission when prompted.
3. Choose your **output mode**, **prompt style**, and **shortcut**.
4. Place your cursor in any text field (or select text) in any app.
5. Press your shortcut — wdym refines the text and applies the output.

---

## Configuration

All settings live in the **Options** panel in the menu bar.

| Setting | Options |
|---------|---------|
| **Output mode** | Replace + Copy · Replace only · Copy only |
| **Prompt style** | General · Coding · Writing · Search · Research · Best Practices |
| **Shortcut** | Choose a preset or record your own key combination |
| **AI refinement** | Enable Groq and enter your API key for LLM-powered polish |
| **Groq model** | Speed-first default (`llama-3.1-8b-instant`), configurable |
| **Auto-select** | Automatically select all text in focused field before capture |

API keys are stored securely in **macOS Keychain**. All other preferences are stored in **UserDefaults** and never leave your machine.

---

## Kitty / OpenCode Integration

For deterministic text capture inside Kitty terminal (e.g. with OpenCode), enable Remote Control:

1. Add to your Kitty config (`~/.config/kitty/kitty.conf`):

   ```text
   allow_remote_control socket-only
   listen_on unix:/tmp/prompt-refactor-kitty
   ```

2. Restart Kitty.
3. In wdym **Options**, set the Kitty socket address to match (e.g. `unix:/tmp/prompt-refactor-kitty`).
4. Use **Run Kitty Check** in Options to verify the connection.

wdym will now read the focused prompt field directly via Kitty RC and write back via paste — no clipboard interference.

---

## Privacy

wdym is designed to stay out of your way and out of your data.

- ❌ No prompt history stored
- ❌ No analytics or telemetry
- ✅ Prompt text handled in memory, discarded after processing
- ✅ Local-only processing when Groq is disabled
- ✅ When Groq is enabled, only the current prompt text is sent over HTTPS
- ✅ API keys stored in macOS Keychain; preferences stored in UserDefaults

---

## Contributing

Contributions are welcome! Here's how to get started:

```bash
# Run core package tests
swift test

# Run app tests
xcodebuild \
  -project "PromptRefactorApp/PromptRefactorApp.xcodeproj" \
  -scheme "PromptRefactorApp" \
  -destination "platform=macOS" \
  -only-testing:PromptRefactorAppTests \
  test
```

The release workflow is [`.github/workflows/release-and-publish.yml`](.github/workflows/release-and-publish.yml).

---

## License

[MIT](LICENSE) © 2026 Prompt Refactor contributors
