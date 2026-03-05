import CoreGraphics
import Foundation

protocol PasteMonitorService: Sendable {
  func startMonitoring(handler: @escaping @Sendable () -> Void)
  func stopMonitoring()
  func suppressNextEvent()
}

final class CGEventPasteMonitorService: PasteMonitorService, @unchecked Sendable {
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: (@Sendable () -> Void)?
  private var suppressCount = 0
  private let lock = NSLock()

  func startMonitoring(handler: @escaping @Sendable () -> Void) {
    lock.lock()
    defer { lock.unlock() }

    self.handler = handler

    guard eventTap == nil else {
      return
    }

    let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue

    let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .listenOnly,
      eventsOfInterest: mask,
      callback: { _, _, event, userInfo in
        guard let userInfo else {
          return Unmanaged.passRetained(event)
        }

        let service = Unmanaged<CGEventPasteMonitorService>.fromOpaque(userInfo)
          .takeUnretainedValue()
        service.handleEvent(event)
        return Unmanaged.passRetained(event)
      },
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    )

    guard let tap else {
      return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    self.eventTap = tap
    self.runLoopSource = source
  }

  func stopMonitoring() {
    lock.lock()
    defer { lock.unlock() }

    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      if let source = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
      }
    }

    eventTap = nil
    runLoopSource = nil
    handler = nil
  }

  func suppressNextEvent() {
    lock.lock()
    defer { lock.unlock() }
    suppressCount += 1
  }

  private func handleEvent(_ event: CGEvent) {
    lock.lock()
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let currentHandler = handler

    if suppressCount > 0 && flags.contains(.maskCommand) && keyCode == 9 {
      suppressCount -= 1
      lock.unlock()
      return
    }

    let isPaste = flags.contains(.maskCommand) && keyCode == 9
    lock.unlock()

    if isPaste {
      currentHandler?()
    }
  }
}
