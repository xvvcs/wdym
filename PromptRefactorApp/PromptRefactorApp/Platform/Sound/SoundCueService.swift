import AppKit

enum SoundCueEvent {
  case refactorStarted
  case refactorCompleted
  case refactorFailed
}

protocol SoundPlayer: Sendable {
  func play(named name: String)
}

struct NSSoundPlayer: SoundPlayer {
  func play(named name: String) {
    NSSound(named: name)?.play()
  }
}

struct SoundCueService {
  private let player: any SoundPlayer
  private let isEnabled: () -> Bool

  init(player: any SoundPlayer = NSSoundPlayer(), isEnabled: @escaping () -> Bool) {
    self.player = player
    self.isEnabled = isEnabled
  }

  func play(_ event: SoundCueEvent) {
    guard isEnabled() else { return }
    player.play(named: soundName(for: event))
  }

  private func soundName(for event: SoundCueEvent) -> String {
    switch event {
    case .refactorStarted:
      return "Tink"
    case .refactorCompleted:
      return "Pop"
    case .refactorFailed:
      return "Basso"
    }
  }
}
