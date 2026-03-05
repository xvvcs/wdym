import AppKit
import Carbon

@MainActor
protocol HotkeyService {
  func startListening(binding: HotkeyBinding, handler: @escaping () -> Void)
  func updateBinding(_ binding: HotkeyBinding)
  func stopListening()
}

@MainActor
final class GlobalHotkeyService: HotkeyService {
  private let signature = fourCharCode(from: "PRFX")
  private let hotKeyID: UInt32

  private static var nextHotKeyID: UInt32 = 1

  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var binding: HotkeyBinding?
  private var handler: (() -> Void)?

  init(hotKeyID: UInt32? = nil) {
    self.hotKeyID = hotKeyID ?? Self.makeHotKeyID()
  }

  func startListening(binding: HotkeyBinding, handler: @escaping () -> Void) {
    stopListening()

    self.binding = binding
    self.handler = handler

    installEventHandlerIfNeeded()
    registerHotkey(binding)
  }

  func updateBinding(_ binding: HotkeyBinding) {
    self.binding = binding

    unregisterHotkey()
    registerHotkey(binding)
  }

  func stopListening() {
    unregisterHotkey()

    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }

    handler = nil
    binding = nil
  }

  private func installEventHandlerIfNeeded() {
    guard eventHandlerRef == nil else {
      return
    }

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: OSType(kEventHotKeyPressed)
    )

    let userData = Unmanaged.passUnretained(self).toOpaque()
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      Self.hotKeyEventHandler,
      1,
      &eventSpec,
      userData,
      &eventHandlerRef
    )

    if status != noErr {
      eventHandlerRef = nil
    }
  }

  private func registerHotkey(_ binding: HotkeyBinding) {
    let status = RegisterEventHotKey(
      UInt32(binding.keyCode),
      carbonModifiers(from: binding.modifiers),
      eventHotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    if status != noErr {
      hotKeyRef = nil
    }
  }

  private func unregisterHotkey() {
    guard let hotKeyRef else {
      return
    }

    UnregisterEventHotKey(hotKeyRef)
    self.hotKeyRef = nil
  }

  private func handleHotkeyPressed(eventRef: EventRef?) -> OSStatus {
    guard let eventRef else {
      return OSStatus(eventNotHandledErr)
    }

    var id = EventHotKeyID()
    let status = GetEventParameter(
      eventRef,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &id
    )

    guard status == noErr else {
      return OSStatus(eventNotHandledErr)
    }

    return handlingStatus(for: id)
  }

  var eventHotKeyID: EventHotKeyID {
    EventHotKeyID(signature: signature, id: hotKeyID)
  }

  func matches(eventHotKeyID: EventHotKeyID) -> Bool {
    eventHotKeyID.signature == signature && eventHotKeyID.id == hotKeyID
  }

  func handlingStatus(for eventHotKeyID: EventHotKeyID) -> OSStatus {
    guard matches(eventHotKeyID: eventHotKeyID) else {
      return OSStatus(eventNotHandledErr)
    }

    handler?()
    return noErr
  }

  private static func makeHotKeyID() -> UInt32 {
    let id = nextHotKeyID
    nextHotKeyID &+= 1
    return id
  }

  private static let hotKeyEventHandler: EventHandlerUPP = { _, eventRef, userData in
    guard let userData else {
      return OSStatus(eventNotHandledErr)
    }

    let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
    return service.handleHotkeyPressed(eventRef: eventRef)
  }
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
  var modifiers: UInt32 = 0

  if flags.contains(.command) {
    modifiers |= UInt32(cmdKey)
  }
  if flags.contains(.shift) {
    modifiers |= UInt32(shiftKey)
  }
  if flags.contains(.option) {
    modifiers |= UInt32(optionKey)
  }
  if flags.contains(.control) {
    modifiers |= UInt32(controlKey)
  }

  return modifiers
}

private func fourCharCode(from value: String) -> OSType {
  value.utf16.reduce(0) { partialResult, unit in
    (partialResult << 8) + OSType(unit)
  }
}
