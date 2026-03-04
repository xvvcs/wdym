import AppKit
import Combine
import Foundation
import PromptRefactorCore

@MainActor
final class ShortcutRecorder: ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var statusMessage = "Press Record Shortcut"

  private var monitor: Any?

  func startRecording(onCapture: @escaping (HotkeyBinding) -> Void) {
    stopRecording()
    isRecording = true
    statusMessage = "Press any key combo (Esc to cancel)"

    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else {
        return event
      }

      guard self.isRecording else {
        return event
      }

      if event.keyCode == 53 {
        self.stopRecording(message: "Recording cancelled")
        return nil
      }

      guard let binding = HotkeyBinding.capture(from: event) else {
        self.statusMessage = "Include Command, Shift, Option, or Control"
        return nil
      }

      onCapture(binding)
      self.stopRecording(message: "Captured \(binding.title)")
      return nil
    }
  }

  func stopRecording(message: String = "Press Record Shortcut") {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }

    isRecording = false
    statusMessage = message
  }

  deinit {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}
