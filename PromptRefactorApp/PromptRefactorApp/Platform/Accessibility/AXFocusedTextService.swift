import AppKit
import ApplicationServices
import Foundation

enum AXFocusedTextError: Error {
  case noFocusedElement
  case notReadable
  case notWritable(AXError)
}

protocol AXFocusedTextService {
  func readFocusedText() throws -> String
  func writeFocusedText(_ value: String) throws
}

struct DefaultAXFocusedTextService: AXFocusedTextService {
  func readFocusedText() throws -> String {
    let element = try focusedElement()

    for candidate in candidateElements(startingAt: element) {
      if let selectedText = try readStringAttribute(
        kAXSelectedTextAttribute as CFString, from: candidate), !selectedText.isEmpty
      {
        return selectedText
      }

      if let value = try readStringAttribute(kAXValueAttribute as CFString, from: candidate),
        !value.isEmpty
      {
        return value
      }
    }

    throw AXFocusedTextError.notReadable
  }

  func writeFocusedText(_ value: String) throws {
    let element = try focusedElement()

    for candidate in candidateElements(startingAt: element) {
      if let selectedText = try readStringAttribute(
        kAXSelectedTextAttribute as CFString, from: candidate), !selectedText.isEmpty
      {
        let replaceSelectionStatus = AXUIElementSetAttributeValue(
          candidate,
          kAXSelectedTextAttribute as CFString,
          value as CFString
        )

        if replaceSelectionStatus == .success {
          return
        }
      }

      let status = AXUIElementSetAttributeValue(
        candidate, kAXValueAttribute as CFString, value as CFString)
      if status == .success {
        return
      }
    }

    throw AXFocusedTextError.notWritable(.cannotComplete)
  }

  private func focusedElement() throws -> AXUIElement {
    if let fromFocusedApp = try focusedElementFromFocusedApplication() {
      return fromFocusedApp
    }

    let system = AXUIElementCreateSystemWide()
    var focusedObject: CFTypeRef?

    let status = AXUIElementCopyAttributeValue(
      system, kAXFocusedUIElementAttribute as CFString, &focusedObject)
    guard status == .success, let focusedObject, let element = asAXUIElement(focusedObject) else {
      throw AXFocusedTextError.noFocusedElement
    }

    return element
  }

  private func focusedElementFromFocusedApplication() throws -> AXUIElement? {
    let system = AXUIElementCreateSystemWide()
    var focusedApplication: CFTypeRef?

    let appStatus = AXUIElementCopyAttributeValue(
      system, kAXFocusedApplicationAttribute as CFString, &focusedApplication)
    guard appStatus == .success, let focusedApplication,
      let appElement = asAXUIElement(focusedApplication)
    else {
      return nil
    }

    var focusedElement: CFTypeRef?
    let elementStatus = AXUIElementCopyAttributeValue(
      appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
    guard elementStatus == .success, let focusedElement, let element = asAXUIElement(focusedElement)
    else {
      return nil
    }

    return element
  }

  private func readStringAttribute(_ attribute: CFString, from element: AXUIElement) throws
    -> String?
  {
    var rawValue: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute, &rawValue)
    guard status == .success else {
      return nil
    }

    if let value = rawValue as? String {
      return value
    }

    if let value = rawValue as? NSAttributedString {
      return value.string
    }

    return nil
  }

  private func asAXUIElement(_ value: CFTypeRef) -> AXUIElement? {
    guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }

    return unsafeBitCast(value, to: AXUIElement.self)
  }

  private func candidateElements(startingAt element: AXUIElement) -> [AXUIElement] {
    var results: [AXUIElement] = [element]
    var current = element

    for _ in 0..<6 {
      var parent: CFTypeRef?
      let status = AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent)
      guard status == .success, let parent, let parentElement = asAXUIElement(parent) else {
        break
      }

      results.append(parentElement)
      current = parentElement
    }

    return results
  }
}
