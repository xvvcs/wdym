import AppKit
import Foundation
import Testing

@testable import PromptRefactorApp

struct SoundCueServiceTests {
  @Test func playDoesNothingWhenSoundCuesDisabled() {
    let recorder = RecordingSoundPlayer()
    let service = SoundCueService(player: recorder, isEnabled: { false })

    service.play(.refactorStarted)
    service.play(.refactorCompleted)
    service.play(.refactorFailed)

    #expect(recorder.playedNames.isEmpty)
  }

  @Test func playForwardsToPlayerWhenSoundCuesEnabled() {
    let recorder = RecordingSoundPlayer()
    let service = SoundCueService(player: recorder, isEnabled: { true })

    service.play(.refactorStarted)
    service.play(.refactorCompleted)
    service.play(.refactorFailed)

    #expect(recorder.playedNames.count == 3)
  }

  @Test func refactorStartedPlaysCorrectSound() {
    let recorder = RecordingSoundPlayer()
    let service = SoundCueService(player: recorder, isEnabled: { true })

    service.play(.refactorStarted)

    #expect(recorder.playedNames == ["Tink"])
  }

  @Test func refactorCompletedPlaysCorrectSound() {
    let recorder = RecordingSoundPlayer()
    let service = SoundCueService(player: recorder, isEnabled: { true })

    service.play(.refactorCompleted)

    #expect(recorder.playedNames == ["Pop"])
  }

  @Test func refactorFailedPlaysCorrectSound() {
    let recorder = RecordingSoundPlayer()
    let service = SoundCueService(player: recorder, isEnabled: { true })

    service.play(.refactorFailed)

    #expect(recorder.playedNames == ["Basso"])
  }

  @Test func playRespectsLiveEnabledFlag() {
    let recorder = RecordingSoundPlayer()
    var enabled = true
    let service = SoundCueService(player: recorder, isEnabled: { enabled })

    service.play(.refactorStarted)
    enabled = false
    service.play(.refactorCompleted)
    enabled = true
    service.play(.refactorFailed)

    #expect(recorder.playedNames == ["Tink", "Basso"])
  }

  @Test func defaultSoundCuesEnabledIsTrue() {
    #expect(AppSettings.default.soundCuesEnabled == true)
  }
}

private final class RecordingSoundPlayer: SoundPlayer {
  private(set) var playedNames: [String] = []

  func play(named name: String) {
    playedNames.append(name)
  }
}
