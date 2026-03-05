import AppKit
import Combine
import SwiftUI

enum PromptStyleHUDDirection: Equatable {
  case forward
  case backward
}

@MainActor
protocol PromptStyleHUDPresenting {
  func present(
    choices: [PromptStyleChoice],
    selectedIndex: Int,
    direction: PromptStyleHUDDirection
  )
  func dismiss()
}

@MainActor
final class PromptStyleHUDPresenter: PromptStyleHUDPresenting {
  private let model = PromptStyleHUDModel()
  private var panel: PromptStyleHUDPanel?
  private var dismissWorkItem: DispatchWorkItem?

  func present(
    choices: [PromptStyleChoice],
    selectedIndex: Int,
    direction: PromptStyleHUDDirection
  ) {
    guard !choices.isEmpty else {
      dismiss()
      return
    }

    ensurePanel()
    model.configure(choices: choices, selectedIndex: selectedIndex, direction: direction)
    positionPanel()

    guard let panel else {
      return
    }

    if !panel.isVisible {
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.12
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().alphaValue = 1
      }
    } else {
      panel.orderFrontRegardless()
      panel.alphaValue = 1
    }

    scheduleDismiss()
  }

  func dismiss() {
    dismissWorkItem?.cancel()
    dismissWorkItem = nil

    guard let panel, panel.isVisible else {
      return
    }

    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.14
        context.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.animator().alphaValue = 0
      },
      completionHandler: {
        panel.orderOut(nil)
      }
    )
  }

  private func ensurePanel() {
    guard panel == nil else {
      return
    }

    let panel = PromptStyleHUDPanel(
      contentRect: NSRect(x: 0, y: 0, width: 216, height: 164),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentView = NSHostingView(rootView: PromptStyleHUDView(model: model))
    self.panel = panel
  }

  private func positionPanel() {
    guard let panel, let screen = targetScreen() else {
      return
    }

    let frame = screen.visibleFrame
    let origin = CGPoint(
      x: frame.maxX - panel.frame.width - 20,
      y: frame.maxY - panel.frame.height - 22
    )
    panel.setFrameOrigin(origin)
  }

  private func targetScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first {
      NSMouseInRect(mouseLocation, $0.frame, false)
    } ?? NSScreen.main ?? NSScreen.screens.first
  }

  private func scheduleDismiss() {
    dismissWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      Task { @MainActor in
        self?.dismiss()
      }
    }
    dismissWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.95, execute: workItem)
  }

  deinit {
    dismissWorkItem?.cancel()
  }
}

private final class PromptStyleHUDPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  override init(
    contentRect: NSRect,
    styleMask style: NSWindow.StyleMask,
    backing bufferingType: NSWindow.BackingStoreType,
    defer flag: Bool
  ) {
    super.init(
      contentRect: contentRect,
      styleMask: style,
      backing: bufferingType,
      defer: flag
    )

    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    ignoresMouseEvents = true
    hidesOnDeactivate = false
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
    animationBehavior = .utilityWindow
  }
}

@MainActor
private final class PromptStyleHUDModel: ObservableObject {
  @Published private(set) var items: [PromptStyleHUDItem] = []
  @Published private(set) var selectedTitle = ""
  @Published private(set) var selectedSubtitle = ""
  @Published private(set) var direction: PromptStyleHUDDirection = .forward
  @Published private(set) var animationToken = UUID()

  func configure(
    choices: [PromptStyleChoice],
    selectedIndex: Int,
    direction: PromptStyleHUDDirection
  ) {
    let clampedIndex = min(max(selectedIndex, 0), choices.count - 1)
    let offsets = [-1, 0, 1]

    items = offsets.map { offset in
      let wrappedIndex = (clampedIndex + offset + choices.count) % choices.count
      return PromptStyleHUDItem(choice: choices[wrappedIndex], relativeOffset: offset)
    }
    selectedTitle = choices[clampedIndex].title
    selectedSubtitle = choices[clampedIndex].subtitle
    self.direction = direction
    animationToken = UUID()
  }
}

private struct PromptStyleHUDItem: Identifiable {
  let id = UUID()
  let choice: PromptStyleChoice
  let relativeOffset: Int

  var opacity: Double {
    switch abs(relativeOffset) {
    case 0:
      return 0.92
    case 1:
      return 0.42
    default:
      return 0.24
    }
  }

  var scale: CGFloat {
    switch abs(relativeOffset) {
    case 0:
      return 1
    case 1:
      return 0.96
    default:
      return 0.9
    }
  }

  var verticalPadding: CGFloat {
    relativeOffset == 0 ? 6 : 2
  }
}

private struct PromptStyleHUDView: View {
  @ObservedObject var model: PromptStyleHUDModel

  @State private var animatedOffset: CGFloat = 0
  @State private var viewOpacity = 0.0

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Prompt Style")
          .font(.caption2)
          .fontWeight(.semibold)
          .textCase(.uppercase)
          .foregroundStyle(Color.white.opacity(0.68))

        Text(model.selectedTitle)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .lineLimit(1)

        Text(model.selectedSubtitle)
          .font(.caption2)
          .foregroundStyle(Color.white.opacity(0.64))
          .lineLimit(1)
      }

      VStack(spacing: 0) {
        ForEach(model.items) { item in
          row(for: item)
        }
      }
      .offset(y: animatedOffset)
      .mask(
        LinearGradient(
          colors: [
            .white.opacity(0.14),
            .white.opacity(0.72),
            .white,
            .white,
            .white.opacity(0.72),
            .white.opacity(0.14),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(width: 216)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(
          LinearGradient(
            colors: [
              Color.black.opacity(0.95),
              Color.white.opacity(0.06),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    )
    .shadow(color: Color.black.opacity(0.28), radius: 10, y: 5)
    .opacity(viewOpacity)
    .onAppear {
      viewOpacity = 1
      runAnimation()
    }
    .onChange(of: model.animationToken) { _, _ in
      runAnimation()
    }
  }

  private func row(for item: PromptStyleHUDItem) -> some View {
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 4)
        .fill(item.relativeOffset == 0 ? Color.white.opacity(0.88) : Color.white.opacity(0.12))
        .frame(width: 2.5, height: item.relativeOffset == 0 ? 16 : 8)

      VStack(alignment: .leading, spacing: item.relativeOffset == 0 ? 3 : 1) {
        Text(item.choice.title)
          .font(item.relativeOffset == 0 ? .callout : .caption2)
          .fontWeight(item.relativeOffset == 0 ? .semibold : .regular)
          .foregroundStyle(.white.opacity(item.opacity))
          .lineLimit(1)

        if item.relativeOffset == 0 {
          Text(item.choice.subtitle)
            .font(.caption2)
            .foregroundStyle(Color.white.opacity(0.62))
            .lineLimit(1)
        }
      }

      Spacer(minLength: 0)

      if item.relativeOffset == 0 {
        Image(systemName: "checkmark.circle.fill")
          .font(.caption2)
          .foregroundStyle(Color.white.opacity(0.82))
      }
    }
    .padding(.vertical, item.verticalPadding)
    .scaleEffect(item.scale, anchor: .center)
  }

  private func runAnimation() {
    animatedOffset = model.direction == .forward ? 12 : -12

    withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
      animatedOffset = 0
    }
  }
}
