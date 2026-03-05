import Combine
import Foundation

// MARK: - Model

struct GitHubRelease: Decodable, Equatable, Sendable {
  let tagName: String
  let htmlUrl: URL
  let body: String?
  let publishedAt: Date?
  let prerelease: Bool
  let draft: Bool

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case htmlUrl = "html_url"
    case body
    case publishedAt = "published_at"
    case prerelease
    case draft
  }
}

// MARK: - Protocol

protocol UpdateCheckerService: AnyObject, Sendable {
  var availableRelease: GitHubRelease? { get }
  var isChecking: Bool { get }
  func startPeriodicChecks() async
  func checkForUpdates(userInitiated: Bool) async
  func skipVersion(_ tag: String)
}

// MARK: - Implementation

@MainActor
final class UpdateChecker: ObservableObject, UpdateCheckerService {

  static let shared = UpdateChecker()

  @Published private(set) var availableRelease: GitHubRelease?
  @Published private(set) var isChecking = false
  @Published private(set) var lastCheckError: String?

  private let repoOwner = "xvvcs"
  private let repoName = "wdym"
  private let checkIntervalSeconds: TimeInterval = 86_400  // 24 h

  private let urlSession: URLSession
  private var checkTask: Task<Void, Never>?

  // MARK: UserDefaults keys

  private enum DefaultsKeys {
    static let lastChecked = "updateChecker.lastChecked"
    static let skippedTag = "updateChecker.skippedTag"
  }

  // MARK: Init

  init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
  }

  // MARK: - Periodic checks

  func startPeriodicChecks() async {
    stopPeriodicChecks()
    checkTask = Task { [weak self] in
      guard let self else { return }

      let last =
        UserDefaults.standard.object(forKey: DefaultsKeys.lastChecked) as? Date
        ?? .distantPast
      if Date().timeIntervalSince(last) >= checkIntervalSeconds {
        await checkForUpdates(userInitiated: false)
      }

      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(checkIntervalSeconds))
        guard !Task.isCancelled else { break }
        await checkForUpdates(userInitiated: false)
      }
    }
  }

  func stopPeriodicChecks() {
    checkTask?.cancel()
    checkTask = nil
  }

  // MARK: - Core check

  func checkForUpdates(userInitiated: Bool) async {
    guard !isChecking else { return }
    isChecking = true
    lastCheckError = nil
    defer { isChecking = false }

    UserDefaults.standard.set(Date(), forKey: DefaultsKeys.lastChecked)

    guard
      let url = URL(
        string:
          "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")
    else { return }

    var request = URLRequest(url: url, timeoutInterval: 15)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    let appVersion =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    request.setValue("\(repoName)/\(appVersion)", forHTTPHeaderField: "User-Agent")

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let (data, _) = try await urlSession.data(for: request)
      let release = try decoder.decode(GitHubRelease.self, from: data)

      guard !release.draft, !release.prerelease else { return }

      let current =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
      guard isNewer(remote: release.tagName, than: current) else {
        if userInitiated {
          availableRelease = nil
        }
        return
      }

      let skipped = UserDefaults.standard.string(forKey: DefaultsKeys.skippedTag)
      if !userInitiated, skipped == release.tagName { return }

      availableRelease = release
    } catch {
      lastCheckError = error.localizedDescription
      if userInitiated {
        lastCheckError = "Update check failed: \(error.localizedDescription)"
      }
    }
  }

  // MARK: - Skip version

  func skipVersion(_ tag: String) {
    UserDefaults.standard.set(tag, forKey: DefaultsKeys.skippedTag)
    availableRelease = nil
  }

  func dismissAvailableRelease() {
    availableRelease = nil
  }

  // MARK: - Semver helper

  /// Returns true when `remote` is strictly newer than `local`.
  /// Strips a leading "v" before doing a numeric component comparison.
  func isNewer(remote: String, than local: String) -> Bool {
    let clean: (String) -> String = { s in
      s.hasPrefix("v") ? String(s.dropFirst()) : s
    }
    return clean(remote).compare(clean(local), options: .numeric) == .orderedDescending
  }
}

// MARK: - Stub (for testing / injection)

@MainActor
final class StubUpdateChecker: ObservableObject, UpdateCheckerService {
  var availableRelease: GitHubRelease?
  var isChecking = false
  var checkForUpdatesCalled = false
  var userInitiatedPassedValue: Bool?
  var skippedTag: String?

  func startPeriodicChecks() async {}

  func checkForUpdates(userInitiated: Bool) async {
    checkForUpdatesCalled = true
    userInitiatedPassedValue = userInitiated
  }

  func skipVersion(_ tag: String) {
    skippedTag = tag
    availableRelease = nil
  }
}
