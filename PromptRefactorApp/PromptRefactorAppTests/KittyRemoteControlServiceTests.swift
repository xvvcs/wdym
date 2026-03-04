import Foundation
import Testing

@testable import PromptRefactorApp

@MainActor
struct KittyRemoteControlServiceTests {
  @Test func checkConnectionResolvesToHighestPidSocketWhenBasePathMissing() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-100")
    try fixture.createFile(named: "prompt-refactor-kitty-200")

    let expectedSuffix = "/prompt-refactor-kitty-200"
    let runner = SpyProcessRunner { arguments in
      guard Self.listenAddress(in: arguments)?.hasSuffix(expectedSuffix) == true else {
        return ProcessExecutionResult(exitCode: 1, stdout: "", stderr: "connect failed")
      }

      return ProcessExecutionResult(exitCode: 0, stdout: "[]", stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let status = await service.checkConnection(listenAddress: "unix:\(basePath)")

    switch status {
    case .available(let listenAddress):
      #expect(listenAddress.hasSuffix(expectedSuffix))
    case .unavailable(let reason):
      Issue.record("Expected available status, got: \(reason)")
    }
    #expect(runner.calls.count == 1)
    #expect(Self.listenAddress(in: runner.calls[0].arguments)?.hasSuffix(expectedSuffix) == true)
  }

  @Test func checkConnectionFallsBackToLowerPidSocketWhenNewestCandidateFails() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-100")
    try fixture.createFile(named: "prompt-refactor-kitty-200")

    let newestSuffix = "/prompt-refactor-kitty-200"
    let fallbackSuffix = "/prompt-refactor-kitty-100"
    let runner = SpyProcessRunner { arguments in
      guard let address = Self.listenAddress(in: arguments) else {
        return ProcessExecutionResult(exitCode: 1, stdout: "", stderr: "missing address")
      }

      if address.hasSuffix(newestSuffix) {
        return ProcessExecutionResult(exitCode: 1, stdout: "", stderr: "stale socket")
      }

      if address.hasSuffix(fallbackSuffix) {
        return ProcessExecutionResult(exitCode: 0, stdout: "[]", stderr: "")
      }

      return ProcessExecutionResult(exitCode: 1, stdout: "", stderr: "unexpected address")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let status = await service.checkConnection(listenAddress: "unix:\(basePath)")

    switch status {
    case .available(let listenAddress):
      #expect(listenAddress.hasSuffix(fallbackSuffix))
    case .unavailable(let reason):
      Issue.record("Expected available status, got: \(reason)")
    }
    #expect(runner.calls.count == 2)
    #expect(Self.listenAddress(in: runner.calls[0].arguments)?.hasSuffix(newestSuffix) == true)
    #expect(Self.listenAddress(in: runner.calls[1].arguments)?.hasSuffix(fallbackSuffix) == true)
  }

  @Test func checkConnectionUsesConfiguredAddressWhenSocketPathExists() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-999")

    let configuredAddress = "unix:\(basePath)"
    let runner = SpyProcessRunner { arguments in
      guard Self.listenAddress(in: arguments) == configuredAddress else {
        return ProcessExecutionResult(
          exitCode: 1, stdout: "", stderr: "should use configured address")
      }

      return ProcessExecutionResult(exitCode: 0, stdout: "[]", stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let status = await service.checkConnection(listenAddress: configuredAddress)

    #expect(status == .available(configuredAddress))
    #expect(runner.calls.count == 1)
    #expect(Self.listenAddress(in: runner.calls[0].arguments) == configuredAddress)
  }

  @Test func readFocusedSelectionUsesResolvedPidSocket() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let expectedSuffix = "/prompt-refactor-kitty-700"
    let runner = SpyProcessRunner { arguments in
      guard Self.listenAddress(in: arguments)?.hasSuffix(expectedSuffix) == true else {
        return ProcessExecutionResult(exitCode: 1, stdout: "", stderr: "wrong socket")
      }

      return ProcessExecutionResult(exitCode: 0, stdout: "  selected text\n", stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedSelection(listenAddress: "unix:\(basePath)")

    #expect(result == .success("selected text"))
    #expect(runner.calls.count == 1)
    #expect(Self.listenAddress(in: runner.calls[0].arguments)?.hasSuffix(expectedSuffix) == true)
    #expect(Self.extent(in: runner.calls[0].arguments) == "selection")
  }

  @Test func readFocusedScreenTextUsesScreenExtent() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let runner = SpyProcessRunner { _ in
      let screen = Self.screenCapture(
        lines: [
          "some output",
          "┃ visible text",
          "Enter to send | Esc to cancel",
        ],
        cursorRow: 2,
        cursorColumn: 15
      )
      return ProcessExecutionResult(exitCode: 0, stdout: screen, stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedScreenText(listenAddress: "unix:\(basePath)")

    #expect(result == .success("visible text"))
    #expect(runner.calls.count == 1)
    #expect(Self.extent(in: runner.calls[0].arguments) == "screen")
    #expect(Self.hasFlag("--add-cursor", in: runner.calls[0].arguments))
    #expect(Self.hasFlag("--add-wrap-markers", in: runner.calls[0].arguments))
  }

  @Test func readFocusedScreenTextReturnsEmptySelectionWithoutCursorMetadata() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let runner = SpyProcessRunner { _ in
      ProcessExecutionResult(
        exitCode: 0,
        stdout: """
          older transcript line
          ┃ typed text
          Enter to send | Esc to cancel
          """,
        stderr: ""
      )
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedScreenText(listenAddress: "unix:\(basePath)")

    #expect(result == .failure(.emptySelection))
  }

  @Test func readFocusedScreenTextReturnsEmptySelectionWhenPromptFieldCannotBeDetected()
    async throws
  {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let runner = SpyProcessRunner { _ in
      let screen = Self.screenCapture(
        lines: [
          "log output line 1",
          "log output line 2",
          "log output line 3",
        ],
        cursorRow: 3,
        cursorColumn: 10
      )
      return ProcessExecutionResult(exitCode: 0, stdout: screen, stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedScreenText(listenAddress: "unix:\(basePath)")

    #expect(result == .failure(.emptySelection))
  }

  @Test func readFocusedScreenTextExtractsPromptFieldLineWhenVisible() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let runner = SpyProcessRunner { _ in
      let screen = Self.screenCapture(
        lines: [
          "previous output line",
          "another output line",
          "┃ make this sentence shorter",
          "┃ Build GPT-5.3 Codex OpenAI · high",
          "Enter to send | Esc to cancel",
        ],
        cursorRow: 3,
        cursorColumn: 29
      )
      return ProcessExecutionResult(exitCode: 0, stdout: screen, stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedScreenText(listenAddress: "unix:\(basePath)")

    #expect(result == .success("make this sentence shorter"))
  }

  @Test func readFocusedScreenTextExtractsPromptFieldContinuationLines() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let runner = SpyProcessRunner { _ in
      let screen = Self.screenCapture(
        lines: [
          "log output",
          "┃ rewrite this paragraph in",
          "┃ a concise style for docs",
          "┃ with a direct tone",
          "┃ Build GPT-5.3 Codex OpenAI · high",
          "Enter to send | Esc to cancel",
        ],
        cursorRow: 4,
        cursorColumn: 23
      )
      return ProcessExecutionResult(exitCode: 0, stdout: screen, stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedScreenText(listenAddress: "unix:\(basePath)")

    #expect(
      result == .success("rewrite this paragraph in a concise style for docs with a direct tone"))
  }

  @Test func readFocusedScreenTextSkipsComposerMetadataAndTranscript() async throws {
    let fixture = try TempDirectoryFixture()
    defer { fixture.remove() }

    let basePath = fixture.path("prompt-refactor-kitty")
    try fixture.createFile(named: "prompt-refactor-kitty-700")

    let runner = SpyProcessRunner { _ in
      let screen = Self.screenCapture(
        lines: [
          "older transcript line",
          "┃ refine this prompt to be concise",
          "┃ mode: build  model: gpt-5  variant: high",
          "Enter to send | Esc to cancel",
        ],
        cursorRow: 2,
        cursorColumn: 36
      )
      return ProcessExecutionResult(exitCode: 0, stdout: screen, stderr: "")
    }

    let service = DefaultKittyRemoteControlService(processRunner: runner)

    let result = await service.readFocusedScreenText(listenAddress: "unix:\(basePath)")

    #expect(result == .success("refine this prompt to be concise"))
  }

  @Test func checkConnectionAddsKittyLookupPathsToProcessEnvironment() async {
    let runner = SpyProcessRunner { _ in
      ProcessExecutionResult(exitCode: 0, stdout: "[]", stderr: "")
    }

    let service = DefaultKittyRemoteControlService(
      processRunner: runner,
      processEnvironment: ["PATH": "/usr/bin:/bin"],
      kittyExecutableLookupPaths: [
        "/Applications/kitty.app/Contents/MacOS",
        "/opt/homebrew/bin",
      ]
    )

    _ = await service.checkConnection(listenAddress: "unix:/tmp/prompt-refactor-kitty")

    #expect(runner.calls.count == 1)
    let path = runner.calls[0].environment["PATH"] ?? ""
    #expect(path.contains("/usr/bin:/bin"))
    #expect(path.contains("/Applications/kitty.app/Contents/MacOS"))
    #expect(path.contains("/opt/homebrew/bin"))
  }

  private static func listenAddress(in arguments: [String]) -> String? {
    guard let toIndex = arguments.firstIndex(of: "--to") else {
      return nil
    }

    let addressIndex = arguments.index(after: toIndex)
    guard addressIndex < arguments.endIndex else {
      return nil
    }

    return arguments[addressIndex]
  }

  private static func extent(in arguments: [String]) -> String? {
    guard let extentIndex = arguments.firstIndex(of: "--extent") else {
      return nil
    }

    let valueIndex = arguments.index(after: extentIndex)
    guard valueIndex < arguments.endIndex else {
      return nil
    }

    return arguments[valueIndex]
  }

  private static func hasFlag(_ flag: String, in arguments: [String]) -> Bool {
    arguments.contains(flag)
  }

  private static func screenCapture(lines: [String], cursorRow: Int, cursorColumn: Int) -> String {
    let body = lines.joined(separator: "\n")
    return "\(body)\n\u{001B}[?25h\u{001B}[\(cursorRow);\(cursorColumn)H\u{001B}[1 q\n"
  }
}

private final class SpyProcessRunner: ProcessRunner {
  struct Call {
    let executablePath: String
    let arguments: [String]
    let environment: [String: String]
  }

  private let responseProvider: ([String]) -> ProcessExecutionResult
  private(set) var calls: [Call] = []

  init(responseProvider: @escaping ([String]) -> ProcessExecutionResult) {
    self.responseProvider = responseProvider
  }

  func run(executablePath: String, arguments: [String], environment: [String: String]) async
    -> ProcessExecutionResult
  {
    calls.append(
      Call(executablePath: executablePath, arguments: arguments, environment: environment))
    return responseProvider(arguments)
  }
}

private struct TempDirectoryFixture {
  private let fileManager = FileManager.default
  private let rootURL: URL

  init() throws {
    rootURL = fileManager.temporaryDirectory.appendingPathComponent(
      "KittyRemoteControlServiceTests.\(UUID().uuidString)",
      isDirectory: true
    )
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
  }

  func path(_ name: String) -> String {
    rootURL.appendingPathComponent(name).path
  }

  func createFile(named name: String) throws {
    let url = rootURL.appendingPathComponent(name)
    guard fileManager.createFile(atPath: url.path, contents: Data()) else {
      throw FixtureError.unableToCreateFile(url.path)
    }
  }

  func remove() {
    try? fileManager.removeItem(at: rootURL)
  }
}

private enum FixtureError: Error {
  case unableToCreateFile(String)
}
