import AppKit

protocol ClipboardService {
  func readString() -> String?
  func writeString(_ value: String)
}

struct PasteboardClipboardService: ClipboardService {
  private let pasteboard: NSPasteboard

  init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
  }

  func readString() -> String? {
    pasteboard.string(forType: .string)
  }

  func writeString(_ value: String) {
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
  }
}
