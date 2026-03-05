import Foundation
import Testing

@testable import PromptRefactorApp

@Suite(.serialized)
@MainActor
struct UpdateCheckerTests {

  // MARK: - isNewer helper

  @Test func isNewerReturnsTrueWhenRemoteVersionIsHigher() {
    let checker = UpdateChecker()

    #expect(checker.isNewer(remote: "v1.1.0", than: "v1.0.0"))
    #expect(checker.isNewer(remote: "v2.0.0", than: "v1.9.9"))
    #expect(checker.isNewer(remote: "v1.10.0", than: "v1.9.0"))
  }

  @Test func isNewerReturnsFalseWhenRemoteVersionIsEqualOrLower() {
    let checker = UpdateChecker()

    #expect(!checker.isNewer(remote: "v1.0.0", than: "v1.0.0"))
    #expect(!checker.isNewer(remote: "v0.9.9", than: "v1.0.0"))
    #expect(!checker.isNewer(remote: "v1.0.0", than: "v1.1.0"))
  }

  @Test func isNewerHandlesTagsWithoutVPrefix() {
    let checker = UpdateChecker()

    #expect(checker.isNewer(remote: "1.2.0", than: "1.1.0"))
    #expect(!checker.isNewer(remote: "1.0.0", than: "1.0.0"))
  }

  @Test func isNewerHandlesMixedPrefixes() {
    let checker = UpdateChecker()

    #expect(checker.isNewer(remote: "v1.2.0", than: "1.1.0"))
    #expect(checker.isNewer(remote: "1.2.0", than: "v1.1.0"))
  }

  // MARK: - checkForUpdates with HTTP stubs

  @Test func checkForUpdatesSetAvailableReleaseWhenNewerVersionExists() async {
    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v99.0.0", draft: false, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: true)

    #expect(checker.availableRelease?.tagName == "v99.0.0")
  }

  @Test func checkForUpdatesDoesNotSetReleaseWhenVersionIsNotNewer() async {
    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v0.0.1", draft: false, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: true)

    #expect(checker.availableRelease == nil)
  }

  @Test func checkForUpdatesIgnoresDraftReleases() async {
    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v99.0.0", draft: true, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: true)

    #expect(checker.availableRelease == nil)
  }

  @Test func checkForUpdatesIgnoresPrereleases() async {
    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v99.0.0", draft: false, prerelease: true)
    )
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: true)

    #expect(checker.availableRelease == nil)
  }

  @Test func checkForUpdatesSetsLastCheckErrorOnNetworkFailure() async {
    let session = makeFailingSession()
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: true)

    #expect(checker.availableRelease == nil)
    #expect(checker.lastCheckError != nil)
  }

  @Test func checkForUpdatesClearsAvailableReleaseWhenUpToDateAndUserInitiated() async {
    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v0.0.1", draft: false, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)

    // Manually set a stale available release
    await checker.checkForUpdates(userInitiated: true)

    // Force a newer release first, then check with up-to-date
    let updatedSession = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v0.0.1", draft: false, prerelease: false)
    )
    let checker2 = UpdateChecker(urlSession: updatedSession)
    await checker2.checkForUpdates(userInitiated: true)
    #expect(checker2.availableRelease == nil)
  }

  // MARK: - skipVersion

  @Test func skipVersionClearsAvailableReleaseAndPersistsTag() async {
    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v99.0.0", draft: false, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)
    await checker.checkForUpdates(userInitiated: true)
    #expect(checker.availableRelease != nil)

    checker.skipVersion("v99.0.0")

    #expect(checker.availableRelease == nil)
    let persisted = UserDefaults.standard.string(forKey: "updateChecker.skippedTag")
    #expect(persisted == "v99.0.0")

    // Clean up
    UserDefaults.standard.removeObject(forKey: "updateChecker.skippedTag")
  }

  @Test func checkForUpdatesRespectsSkippedTagOnBackgroundCheck() async {
    UserDefaults.standard.set("v99.0.0", forKey: "updateChecker.skippedTag")
    defer { UserDefaults.standard.removeObject(forKey: "updateChecker.skippedTag") }

    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v99.0.0", draft: false, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: false)

    // Skipped tag should suppress the available release
    #expect(checker.availableRelease == nil)
  }

  @Test func checkForUpdatesIgnoresSkippedTagWhenUserInitiated() async {
    UserDefaults.standard.set("v99.0.0", forKey: "updateChecker.skippedTag")
    defer { UserDefaults.standard.removeObject(forKey: "updateChecker.skippedTag") }

    let session = makeSession(
      statusCode: 200,
      json: makeReleaseJSON(tagName: "v99.0.0", draft: false, prerelease: false)
    )
    let checker = UpdateChecker(urlSession: session)

    await checker.checkForUpdates(userInitiated: true)

    // User-initiated checks bypass the skip list
    #expect(checker.availableRelease?.tagName == "v99.0.0")
  }

  // MARK: - AppSettings default

  @Test func appSettingsDefaultEnablesCheckForUpdates() {
    #expect(AppSettings.default.checkForUpdatesEnabled == true)
  }

  @Test func appSettingsStorePersistsCheckForUpdatesEnabled() {
    let suiteName = "PromptRefactorAppTests.updateChecker.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let store = UserDefaultsAppSettingsStore(userDefaults: userDefaults)
    store.updateCheckForUpdatesEnabled(false)

    let reloaded = UserDefaultsAppSettingsStore(userDefaults: userDefaults)
    #expect(reloaded.settings.checkForUpdatesEnabled == false)
  }

  // MARK: - Helpers

  private func makeSession(statusCode: Int, json: String) -> URLSession {
    GitHubAPIProtocolStub.statusCode = statusCode
    GitHubAPIProtocolStub.data = Data(json.utf8)
    GitHubAPIProtocolStub.shouldFail = false

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GitHubAPIProtocolStub.self]
    return URLSession(configuration: configuration)
  }

  private func makeFailingSession() -> URLSession {
    GitHubAPIProtocolStub.shouldFail = true

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GitHubAPIProtocolStub.self]
    return URLSession(configuration: configuration)
  }

  private func makeReleaseJSON(tagName: String, draft: Bool, prerelease: Bool) -> String {
    """
    {
      "tag_name": "\(tagName)",
      "html_url": "https://github.com/xvvcs/wdym/releases/tag/\(tagName)",
      "body": "Release notes for \(tagName)",
      "published_at": "2026-03-01T12:00:00Z",
      "draft": \(draft),
      "prerelease": \(prerelease)
    }
    """
  }
}

// MARK: - URL protocol stub

private final class GitHubAPIProtocolStub: URLProtocol {
  static var data = Data()
  static var statusCode = 200
  static var shouldFail = false

  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == "api.github.com"
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    if Self.shouldFail {
      client?.urlProtocol(
        self,
        didFailWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
      )
      return
    }

    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: Self.statusCode,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
