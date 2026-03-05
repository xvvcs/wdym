import Foundation

enum KittyRemoteControlConnectionStatus: Equatable {
    case available(String)
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }

        return false
    }

    var message: String {
        switch self {
        case .available(let listenAddress):
            return "Kitty remote control is reachable at \(listenAddress)"
        case .unavailable(let reason):
            return reason
        }
    }
}

enum KittyRemoteControlError: Error, Equatable {
    case unavailable(String)
    case emptySelection
}

protocol KittyRemoteControlService {
    func checkConnection(listenAddress: String) async -> KittyRemoteControlConnectionStatus
    func readFocusedSelection(listenAddress: String) async -> Result<
        String, KittyRemoteControlError
    >
    func readFocusedScreenText(listenAddress: String) async -> Result<
        String, KittyRemoteControlError
    >
}

struct DefaultKittyRemoteControlService: KittyRemoteControlService {
    private let processRunner: any ProcessRunner
    private let fileManager: FileManager
    private let processEnvironment: [String: String]
    private let kittyExecutableLookupPaths: [String]
    private let promptPrefixes: Set<Character> = [">", "›", "❯", "»", "⟩"]
    private let inputMarkers: Set<Character> = ["|", "│", "┃", "▏", "▕"]
    private let boxBorderCharacters = CharacterSet(
        charactersIn: "-=_+~.`ˉ¯─━═┄┅┈┉┌┐└┘├┤┬┴┼╭╮╰╯╞╡╪╫╬│┃▏▕")
    private let shortcutHintMarkers = [
        "enter",
        "esc",
        "ctrl",
        "cmd",
        "tab",
        "shift",
        "alt",
        "option",
        "⌘",
        "⌥",
        "⌃",
        "↵",
    ]
    private let composerMetadataKeys = ["mode:", "model:", "variant:", "provider:", "context:"]
    private let composerModelTokens = [
        "gpt", "claude", "gemini", "llama", "qwen", "mistral", "codex",
    ]
    private let composerModeTokens = ["build", "plan", "agent", "mode"]

    init(
        processRunner: any ProcessRunner = DefaultProcessRunner(),
        fileManager: FileManager = .default,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        kittyExecutableLookupPaths: [String] = [
            "/Applications/kitty.app/Contents/MacOS",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
    ) {
        self.processRunner = processRunner
        self.fileManager = fileManager
        self.processEnvironment = processEnvironment
        self.kittyExecutableLookupPaths = kittyExecutableLookupPaths
    }

    func checkConnection(listenAddress: String) async -> KittyRemoteControlConnectionStatus {
        let commandResult = await runKittenCommand(
            listenAddress: listenAddress, commandArguments: ["ls"])
        guard commandResult.executionResult.exitCode == 0 else {
            return .unavailable(unavailableMessage(from: commandResult.executionResult))
        }

        let resolvedAddress =
            commandResult.resolvedListenAddress
            ?? listenAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        return .available(resolvedAddress)
    }

    func readFocusedSelection(listenAddress: String) async -> Result<
        String, KittyRemoteControlError
    > {
        await readFocusedText(listenAddress: listenAddress, extent: "selection")
    }

    func readFocusedScreenText(listenAddress: String) async -> Result<
        String, KittyRemoteControlError
    > {
        await readFocusedText(listenAddress: listenAddress, extent: "screen")
    }

    private func readFocusedText(listenAddress: String, extent: String) async -> Result<
        String, KittyRemoteControlError
    > {
        var commandArguments = [
            "get-text",
            "--match",
            "state:focused",
            "--extent",
            extent,
        ]

        if extent == "screen" {
            commandArguments.append(contentsOf: ["--add-cursor", "--add-wrap-markers"])
        }

        let commandResult = await runKittenCommand(
            listenAddress: listenAddress, commandArguments: commandArguments)
        let result = commandResult.executionResult

        guard result.exitCode == 0 else {
            return .failure(.unavailable(unavailableMessage(from: result)))
        }

        let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .failure(.emptySelection)
        }

        if extent == "screen" {
            guard let promptFieldText = extractCursorAnchoredPromptFieldText(from: text) else {
                return .failure(.emptySelection)
            }

            return .success(promptFieldText)
        }

        return .success(text)
    }

    private func extractCursorAnchoredPromptFieldText(from screenText: String) -> String? {
        guard let capture = parseCursorScreenCapture(from: screenText) else {
            return nil
        }

        let cursorLineIndex = capture.cursorRow - 1
        guard cursorLineIndex >= 0, cursorLineIndex < capture.lines.count else {
            return nil
        }

        let lowerBound = max(0, cursorLineIndex - 12)
        var parts: [String] = []
        var foundCandidate = false

        for index in stride(from: cursorLineIndex, through: lowerBound, by: -1) {
            let cursorColumn = index == cursorLineIndex ? capture.cursorColumn : nil
            let inspected = inspectComposerLine(capture.lines[index], cursorColumn: cursorColumn)

            if inspected.isBoundary {
                if foundCandidate {
                    break
                }

                continue
            }

            if !inspected.hasInputAffordance {
                if foundCandidate {
                    break
                }

                continue
            }

            guard let text = inspected.text else {
                continue
            }

            parts.insert(text, at: 0)
            foundCandidate = true
        }

        guard foundCandidate, let candidate = joinPromptParts(parts) else {
            return nil
        }

        guard !looksLikeShortcutHint(candidate), !looksLikeComposerMetadata(candidate) else {
            return nil
        }

        return candidate
    }

    private func parseCursorScreenCapture(from screenText: String) -> CursorScreenCapture? {
        let pattern = #"\u001B\[\?25[hl]\u001B\[(\d+);(\d+)H\u001B\[[0-9; ]+q\n?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let source = screenText as NSString
        let fullRange = NSRange(location: 0, length: source.length)

        guard let match = regex.firstMatch(in: screenText, range: fullRange) else {
            return nil
        }

        let rowRange = match.range(at: 1)
        let columnRange = match.range(at: 2)
        guard rowRange.location != NSNotFound, columnRange.location != NSNotFound else {
            return nil
        }

        guard
            let cursorRow = Int(source.substring(with: rowRange)),
            let cursorColumn = Int(source.substring(with: columnRange)),
            cursorRow > 0,
            cursorColumn > 0
        else {
            return nil
        }

        let body = source.substring(to: match.range.location)
        var lines = body.components(separatedBy: "\n")
        if lines.last?.isEmpty == true {
            lines.removeLast()
        }

        guard !lines.isEmpty else {
            return nil
        }

        return CursorScreenCapture(lines: lines, cursorRow: cursorRow, cursorColumn: cursorColumn)
    }

    private func inspectComposerLine(_ rawLine: String, cursorColumn: Int?)
        -> ComposerLineInspection
    {
        let line = rawLine.replacingOccurrences(of: "\r", with: "")
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return ComposerLineInspection(
                text: nil,
                hasInputAffordance: lineHasInputMarker(line) || lineHasPromptPrefix(line),
                isBoundary: false
            )
        }

        if isBoxBorderLine(trimmed) || looksLikeShortcutHint(trimmed)
            || looksLikeComposerMetadata(trimmed)
        {
            return ComposerLineInspection(text: nil, hasInputAffordance: false, isBoundary: true)
        }

        let hasInputAffordance = lineHasInputMarker(line) || lineHasPromptPrefix(line)
        guard hasInputAffordance else {
            return ComposerLineInspection(text: nil, hasInputAffordance: false, isBoundary: false)
        }

        let lineForCapture: String
        if let cursorColumn {
            lineForCapture = prefixUpToCursor(in: line, cursorColumn: cursorColumn)
        } else {
            lineForCapture = line
        }

        var normalized = normalizePromptContinuation(lineForCapture)
        if let promptRemoved = promptLineWithoutPrefix(from: normalized, requireContent: true) {
            normalized = promptRemoved
        }

        guard !normalized.isEmpty else {
            return ComposerLineInspection(text: nil, hasInputAffordance: true, isBoundary: false)
        }

        if looksLikeShortcutHint(normalized) || looksLikeComposerMetadata(normalized) {
            return ComposerLineInspection(text: nil, hasInputAffordance: false, isBoundary: true)
        }

        return ComposerLineInspection(text: normalized, hasInputAffordance: true, isBoundary: false)
    }

    private func prefixUpToCursor(in line: String, cursorColumn: Int) -> String {
        guard cursorColumn > 1 else {
            return ""
        }

        return String(line.prefix(cursorColumn - 1))
    }

    private func lineHasPromptPrefix(_ line: String) -> Bool {
        promptLineWithoutPrefix(from: line, requireContent: false) != nil
    }

    private func promptLineWithoutPrefix(from line: String, requireContent: Bool) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let firstCharacter = trimmed.first else {
            return nil
        }

        guard promptPrefixes.contains(firstCharacter) else {
            return nil
        }

        let remainder = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        if requireContent, remainder.isEmpty {
            return nil
        }

        return String(remainder)
    }

    private func joinPromptParts(_ parts: [String]) -> String? {
        let candidate =
            parts
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return candidate.isEmpty ? nil : candidate
    }

    private func lineHasInputMarker(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else {
            return false
        }

        return inputMarkers.contains(first)
    }

    private func isBoxBorderLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.unicodeScalars.allSatisfy { boxBorderCharacters.contains($0) }
    }

    private func normalizePromptContinuation(_ line: String) -> String {
        var normalized = line.trimmingCharacters(in: .whitespaces)
        if normalized.hasPrefix("|") || normalized.hasPrefix("│") || normalized.hasPrefix("┃")
            || normalized.hasPrefix("▏") || normalized.hasPrefix("▕")
        {
            normalized = String(normalized.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        if normalized.hasSuffix("|") || normalized.hasSuffix("│") || normalized.hasSuffix("┃")
            || normalized.hasSuffix("▏") || normalized.hasSuffix("▕")
        {
            normalized = String(normalized.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return normalized
    }

    private func looksLikeShortcutHint(_ line: String) -> Bool {
        let lowered = line.lowercased()

        return shortcutHintMarkers.contains { lowered.contains($0) }
    }

    private func looksLikeComposerMetadata(_ line: String) -> Bool {
        let lowered = line.lowercased()
        let matchCount = composerMetadataKeys.reduce(into: 0) { count, key in
            if lowered.contains(key) {
                count += 1
            }
        }

        if matchCount >= 2 {
            return true
        }

        let hasModelToken = composerModelTokens.contains { lowered.contains($0) }
        let hasModeToken = composerModeTokens.contains { lowered.contains($0) }
        let hasUISeparator = line.contains("·") || line.contains("|")

        return hasModelToken && hasModeToken && hasUISeparator
    }

    private func runKittenCommand(listenAddress: String, commandArguments: [String]) async
        -> KittenCommandResult
    {
        let candidateAddresses = candidateListenAddresses(for: listenAddress)

        var lastFailure = ProcessExecutionResult(
            exitCode: -1,
            stdout: "",
            stderr: "Kitty remote control unavailable"
        )

        for candidateAddress in candidateAddresses {
            let result = await runKittenCommand(
                arguments: ["@", "--to", candidateAddress] + commandArguments)
            if result.exitCode == 0 {
                return KittenCommandResult(
                    executionResult: result, resolvedListenAddress: candidateAddress)
            }

            lastFailure = result
        }

        return KittenCommandResult(executionResult: lastFailure, resolvedListenAddress: nil)
    }

    private func candidateListenAddresses(for listenAddress: String) -> [String] {
        let sanitizedAddress = listenAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitizedAddress.hasPrefix("unix:") else {
            return [sanitizedAddress]
        }

        let socketPath = String(sanitizedAddress.dropFirst("unix:".count))
        guard !socketPath.isEmpty, !socketPath.hasPrefix("@") else {
            return [sanitizedAddress]
        }

        guard !fileManager.fileExists(atPath: socketPath) else {
            return [sanitizedAddress]
        }

        let socketURL = URL(fileURLWithPath: socketPath)
        let parentURL = socketURL.deletingLastPathComponent()
        let prefix = "\(socketURL.lastPathComponent)-"

        guard
            let entries = try? fileManager.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            return [sanitizedAddress]
        }

        let resolved = entries.compactMap { entry -> (pid: Int, address: String)? in
            let filename = entry.lastPathComponent
            guard filename.hasPrefix(prefix) else {
                return nil
            }

            let suffix = String(filename.dropFirst(prefix.count))
            guard let pid = Int(suffix) else {
                return nil
            }

            return (pid: pid, address: "unix:\(entry.path)")
        }
        .sorted { $0.pid > $1.pid }
        .map(\.address)

        guard !resolved.isEmpty else {
            return [sanitizedAddress]
        }

        return resolved
    }

    private func runKittenCommand(arguments: [String]) async -> ProcessExecutionResult {
        let environment = environmentIncludingKittyLookupPaths()

        return await processRunner.run(
            executablePath: "/usr/bin/env",
            arguments: ["kitten"] + arguments,
            environment: environment
        )
    }

    private func environmentIncludingKittyLookupPaths() -> [String: String] {
        var environment = processEnvironment
        let existing = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        var merged = existing
        for path in kittyExecutableLookupPaths where !merged.contains(path) {
            merged.append(path)
        }

        environment["PATH"] = merged.joined(separator: ":")
        return environment
    }

    private func unavailableMessage(from result: ProcessExecutionResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return "Kitty remote control unavailable: \(stderr)"
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            return "Kitty remote control unavailable: \(stdout)"
        }

        return "Kitty remote control unavailable"
    }
}

private struct CursorScreenCapture {
    let lines: [String]
    let cursorRow: Int
    let cursorColumn: Int
}

private struct ComposerLineInspection {
    let text: String?
    let hasInputAffordance: Bool
    let isBoundary: Bool
}

private struct KittenCommandResult {
    let executionResult: ProcessExecutionResult
    let resolvedListenAddress: String?
}

struct ProcessExecutionResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol ProcessRunner {
    func run(executablePath: String, arguments: [String], environment: [String: String]) async
        -> ProcessExecutionResult
}

struct DefaultProcessRunner: ProcessRunner {
    func run(executablePath: String, arguments: [String], environment: [String: String]) async
        -> ProcessExecutionResult
    {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                process.environment = environment

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    continuation.resume(
                        returning: ProcessExecutionResult(
                            exitCode: process.terminationStatus,
                            stdout: stdout,
                            stderr: stderr
                        ))
                } catch {
                    continuation.resume(
                        returning: ProcessExecutionResult(
                            exitCode: -1,
                            stdout: "",
                            stderr: error.localizedDescription
                        ))
                }
            }
        }
    }
}
