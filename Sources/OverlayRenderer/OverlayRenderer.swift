// OverlayRenderer — transparent AppKit windows hosting a SwiftUI watermark.

import AppKit
import CoreGraphics
import SwiftUI

/// Renderable overlay content for one display.
public struct OverlayContent: Sendable {
  /// Text shown in the watermark.
  public let text: String

  /// Text opacity, normally in the 0.05–0.12 range.
  public let opacity: CGFloat

  /// CoreGraphics display identifier for the target screen.
  public let screenID: CGDirectDisplayID

  /// Creates display-specific overlay content.
  public init(text: String, opacity: CGFloat = 0.10, screenID: CGDirectDisplayID) {
    self.text = text
    self.opacity = opacity
    self.screenID = screenID
  }
}

/// User interaction events emitted by the overlay layer.
public enum OverlayInteractionEvent: Sendable {
  /// Option-click on a display's overlay.
  case optionClick(screenID: CGDirectDisplayID)
}

/// Abstraction for objects that render overlay watermarks.
@MainActor
public protocol OverlayRendering: AnyObject {
  /// Publisher/callback for user interaction events on the overlay.
  var onInteraction: (@Sendable (OverlayInteractionEvent) -> Void)? { get set }

  /// Shows or updates overlays.
  func update(content: [OverlayContent])

  /// Tears down all overlay windows.
  func hide()
}

/// Source of text updates for `OverlayController`.
public enum OverlayTextSource: Sendable {
  /// A single fixed watermark string.
  case constant(String)

  /// A stream of watermark strings.
  case stream(AsyncStream<String>)

  /// Default v1 prototype text.
  public static var prototype: OverlayTextSource { .constant("PROTOTYPE") }
}

/// Supported screen positions for the watermark.
public enum WatermarkPosition: Sendable {
  case lowerRight, lowerLeft, upperRight, upperLeft, center

  /// Position used when the cursor enters this watermark position.
  public var diagonalOpposite: WatermarkPosition {
    switch self {
    case .lowerRight:
      return .upperLeft
    case .lowerLeft:
      return .upperRight
    case .upperRight:
      return .lowerLeft
    case .upperLeft:
      return .lowerRight
    case .center:
      return .center
    }
  }

  fileprivate var alignment: Alignment {
    switch self {
    case .lowerRight:
      return .bottomTrailing
    case .lowerLeft:
      return .bottomLeading
    case .upperRight:
      return .topTrailing
    case .upperLeft:
      return .topLeading
    case .center:
      return .center
    }
  }

  fileprivate var padding: EdgeInsets {
    switch self {
    case .lowerRight, .lowerLeft:
      return EdgeInsets(top: 60, leading: 80, bottom: 60, trailing: 80)
    case .upperRight, .upperLeft:
      return EdgeInsets(top: 60, leading: 80, bottom: 60, trailing: 80)
    case .center:
      return EdgeInsets()
    }
  }
}

/// SwiftUI view that draws the watermark text and inline rename field.
public struct WatermarkView: View {
  private let text: String
  private let opacity: CGFloat
  private let position: WatermarkPosition
  private let isEditing: Bool
  private let onTap: (() -> Void)?
  private let onCommit: ((String) -> Void)?
  private let onCancel: (() -> Void)?

  @State private var draft: String
  @FocusState private var fieldIsFocused: Bool

  /// Creates a watermark view.
  public init(
    text: String,
    opacity: CGFloat = 0.10,
    position: WatermarkPosition = .lowerRight,
    isEditing: Bool = false,
    onTap: (() -> Void)? = nil,
    onCommit: ((String) -> Void)? = nil,
    onCancel: (() -> Void)? = nil
  ) {
    self.text = text
    self.opacity = opacity
    self.position = position
    self.isEditing = isEditing
    self.onTap = onTap
    self.onCommit = onCommit
    self.onCancel = onCancel
    self._draft = State(initialValue: text)
  }

  /// The rendered watermark body.
  public var body: some View {
    ZStack {
      if isEditing {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { onCancel?() }
      }

      watermarkContent
        .padding(position.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    }
    .animation(.easeInOut(duration: 0.25), value: position)
  }

  @ViewBuilder private var watermarkContent: some View {
    if isEditing {
      TextField("", text: $draft)
        .textFieldStyle(.plain)
        .font(.system(size: 240, weight: .ultraLight, design: .default))
        .tracking(12)
        .foregroundStyle(Color.white.opacity(0.35))
        .lineLimit(1)
        .minimumScaleFactor(0.1)
        .focused($fieldIsFocused)
        .onSubmit { onCommit?(draft) }
        .onExitCommand { onCancel?() }
        .onAppear {
          DispatchQueue.main.async {
            fieldIsFocused = true
          }
        }
    } else {
      Text(text)
        .font(.system(size: 240, weight: .ultraLight, design: .default))
        .tracking(12)
        .foregroundStyle(Color.white.opacity(opacity))
        .lineLimit(1)
        .minimumScaleFactor(0.1)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
  }
}

/// Tracks hover-flee state for one watermark.
public struct WatermarkHoverFleeState: Sendable {
  public let configuredPosition: WatermarkPosition
  public private(set) var currentPosition: WatermarkPosition

  public init(configuredPosition: WatermarkPosition) {
    self.configuredPosition = configuredPosition
    self.currentPosition = configuredPosition
  }

  @discardableResult
  public mutating func cursorMoved(
    to cursorPosition: CGPoint,
    currentWatermarkBounds: CGRect,
    isOptionHeld: Bool = false
  ) -> WatermarkPosition {
    guard !isOptionHeld else { return currentPosition }
    return cursorMoved(isInsideCurrentWatermark: currentWatermarkBounds.contains(cursorPosition))
  }

  @discardableResult
  public mutating func cursorMoved(isInsideCurrentWatermark: Bool, isOptionHeld: Bool = false)
    -> WatermarkPosition
  {
    guard !isOptionHeld else { return currentPosition }
    guard isInsideCurrentWatermark else { return currentPosition }

    let opposite = configuredPosition.diagonalOpposite
    if currentPosition == configuredPosition {
      currentPosition = opposite
    } else {
      currentPosition = configuredPosition
    }
    return currentPosition
  }
}

/// Borderless, transparent, click-through overlay window.
@MainActor
public final class OverlayWindow: NSWindow {
  public var allowsKeyWindow = false

  /// Creates an overlay window sized to a screen's visible frame.
  public init(screen: NSScreen) {
    super.init(
      contentRect: screen.visibleFrame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    ignoresMouseEvents = true
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    isReleasedWhenClosed = false
    hidesOnDeactivate = false
  }

  override public var canBecomeKey: Bool { allowsKeyWindow }
  override public var canBecomeMain: Bool { allowsKeyWindow }
}

/// Manages per-screen overlay windows and applies watermark text updates.
@MainActor
public final class OverlayController: OverlayRendering {
  private struct ManagedWindow {
    let window: OverlayWindow
    let hostingView: NSHostingView<WatermarkView>
    let screenID: CGDirectDisplayID
    var hoverState: WatermarkHoverFleeState
  }

  /// Publisher/callback for user interaction events on the overlay.
  public var onInteraction: (@Sendable (OverlayInteractionEvent) -> Void)?

  private var managedWindows: [ManagedWindow] = []
  internal private(set) var currentText: String = "PROTOTYPE"
  private let watermarkPosition: WatermarkPosition
  private var textTask: Task<Void, Never>?
  private var mouseMonitor: Any?
  private var lastMouseSampleTime: TimeInterval = 0
  private var lastInsideStates: [CGDirectDisplayID: Bool] = [:]
  private let mouseSampleInterval: TimeInterval = 1.0 / 30.0
  private var isOptionHeld = false
  private var isRenaming = false
  private var renameCommit: ((String) -> Void)?
  private var renameCancel: (() -> Void)?

  /// Creates an overlay controller with injectable text and position defaults.
  public init(
    textSource: OverlayTextSource = .prototype, watermarkPosition: WatermarkPosition = .lowerRight
  ) {
    self.watermarkPosition = watermarkPosition
    switch textSource {
    case .constant(let text):
      currentText = text
    case .stream(let stream):
      textTask = Task { @MainActor [weak self] in
        for await text in stream {
          self?.updateText(text)
        }
      }
    }
  }

  deinit {
    textTask?.cancel()
    NotificationCenter.default.removeObserver(self)
    MainActor.assumeIsolated {
      if let mouseMonitor {
        NSEvent.removeMonitor(mouseMonitor)
      }
      managedWindows.forEach { managed in
        managed.window.orderOut(nil)
        managed.window.close()
      }
    }
  }

  /// Starts rendering and observing screen topology changes.
  public func start() {
    rebuildWindows()
    startMouseMonitorIfNeeded()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  /// Stops rendering and removes observers.
  public func stop() {
    NotificationCenter.default.removeObserver(self)
    if let mouseMonitor {
      NSEvent.removeMonitor(mouseMonitor)
      self.mouseMonitor = nil
    }
    hide()
  }

  /// Replaces the watermark text on every managed screen.
  public func updateText(_ text: String) {
    guard currentText != text else { return }
    currentText = text
    guard !isRenaming else { return }
    renderDisplayMode()
  }

  /// Temporarily lets overlay windows receive mouse events while Option is held or rename is active.
  public func setMouseEventsEnabled(_ enabled: Bool) {
    managedWindows.forEach { managed in
      managed.window.ignoresMouseEvents = !enabled
    }
  }

  /// Tracks whether Option means the user is intentionally interacting with the watermark.
  public func setOptionKeyHeld(_ isHeld: Bool) {
    guard isOptionHeld != isHeld else { return }
    isOptionHeld = isHeld
    lastInsideStates.removeAll()
  }

  /// Starts inline rename mode using the same watermark surface.
  public func beginRename(text: String, onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
    currentText = text
    isRenaming = true
    renameCommit = onCommit
    renameCancel = onCancel
    setMouseEventsEnabled(true)
    managedWindows.forEach { managed in
      managed.window.allowsKeyWindow = true
      managed.window.makeKeyAndOrderFront(nil)
      managed.hostingView.rootView = WatermarkView(
        text: text,
        position: managed.hoverState.currentPosition,
        isEditing: true,
        onCommit: { [weak self] value in self?.completeRename(with: value) },
        onCancel: { [weak self] in self?.cancelRename() }
      )
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Exits inline rename mode after a save or cancel.
  public func endRename(keepMouseEventsEnabled: Bool = false) {
    isRenaming = false
    renameCommit = nil
    renameCancel = nil
    managedWindows.forEach { managed in
      managed.window.allowsKeyWindow = false
      managed.window.resignKey()
    }
    setMouseEventsEnabled(keepMouseEventsEnabled)
    renderDisplayMode()
  }

  /// Shows or updates overlays.
  public func update(content: [OverlayContent]) {
    guard let firstContent = content.first else {
      hide()
      return
    }
    updateText(firstContent.text)
  }

  /// Tears down all overlay windows.
  public func hide() {
    managedWindows.forEach { managed in
      managed.window.orderOut(nil)
      managed.window.close()
    }
    managedWindows.removeAll()
    lastInsideStates.removeAll()
  }

  @objc private func screenParametersDidChange() {
    rebuildWindows()
  }

  private func renderDisplayMode() {
    managedWindows.forEach { managed in
      managed.hostingView.rootView = WatermarkView(
        text: currentText,
        position: managed.hoverState.currentPosition,
        onTap: { [weak self] in
          guard let self else { return }
          self.onInteraction?(.optionClick(screenID: managed.screenID))
        }
      )
    }
  }

  private func completeRename(with value: String) {
    renameCommit?(value)
  }

  private func cancelRename() {
    renameCancel?()
  }

  private func rebuildWindows() {
    hide()
    managedWindows = NSScreen.screens.map { screen in
      let window = OverlayWindow(screen: screen)
      let hoverState = WatermarkHoverFleeState(configuredPosition: watermarkPosition)
      let hostingView = NSHostingView(
        rootView: WatermarkView(
          text: currentText,
          position: hoverState.currentPosition,
          onTap: { [weak self] in
            guard let self else { return }
            self.onInteraction?(.optionClick(screenID: displayID(for: screen)))
          }
        ))
      hostingView.frame = NSRect(origin: .zero, size: screen.visibleFrame.size)
      hostingView.autoresizingMask = [.width, .height]
      hostingView.wantsLayer = true
      hostingView.layer?.backgroundColor = NSColor.clear.cgColor
      window.contentView = hostingView
      window.orderFrontRegardless()
      return ManagedWindow(
        window: window,
        hostingView: hostingView,
        screenID: displayID(for: screen),
        hoverState: hoverState
      )
    }
  }

  private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
  }

  private func startMouseMonitorIfNeeded() {
    guard mouseMonitor == nil else { return }

    // Overlay windows are click-through (`ignoresMouseEvents = true`), so tracking areas on
    // the watermark cannot see enter/exit. A single global mouse monitor keeps click-through
    // behavior intact and lets us cheaply hit-test the current watermark rect per screen.
    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
      let location = NSEvent.mouseLocation
      let timestamp = event.timestamp
      DispatchQueue.main.async {
        self?.handleMouseMoved(to: location, timestamp: timestamp)
      }
    }
  }

  private func handleMouseMoved(to location: NSPoint, timestamp: TimeInterval) {
    guard !isOptionHeld else { return }
    guard timestamp - lastMouseSampleTime >= mouseSampleInterval else { return }
    lastMouseSampleTime = timestamp

    for index in managedWindows.indices {
      let rect = watermarkRect(for: managedWindows[index])
      let isInside = rect.contains(location)
      let screenID = managedWindows[index].screenID
      guard lastInsideStates[screenID] != isInside else { continue }
      lastInsideStates[screenID] = isInside

      guard isInside else { continue }
      let previousPosition = managedWindows[index].hoverState.currentPosition
      let nextPosition = managedWindows[index].hoverState.cursorMoved(
        isInsideCurrentWatermark: true)
      guard nextPosition != previousPosition else { continue }
      managedWindows[index].hostingView.rootView = WatermarkView(
        text: currentText,
        position: nextPosition,
        onTap: { [weak self] in
          self?.onInteraction?(.optionClick(screenID: screenID))
        }
      )
    }
  }

  private func watermarkRect(for managed: ManagedWindow) -> NSRect {
    WatermarkGeometry.rect(
      for: currentText,
      position: managed.hoverState.currentPosition,
      in: managed.window.frame
    )
  }
}

private enum WatermarkGeometry {
  static func rect(for text: String, position: WatermarkPosition, in container: NSRect) -> NSRect {
    let size = measuredTextSize(for: text)
    let padding = position.nsEdgeInsets

    let origin: NSPoint
    switch position {
    case .lowerLeft:
      origin = NSPoint(x: container.minX + padding.left, y: container.minY + padding.bottom)
    case .lowerRight:
      origin = NSPoint(
        x: container.maxX - padding.right - size.width, y: container.minY + padding.bottom)
    case .upperLeft:
      origin = NSPoint(
        x: container.minX + padding.left, y: container.maxY - padding.top - size.height)
    case .upperRight:
      origin = NSPoint(
        x: container.maxX - padding.right - size.width,
        y: container.maxY - padding.top - size.height)
    case .center:
      origin = NSPoint(x: container.midX - size.width / 2, y: container.midY - size.height / 2)
    }

    return NSRect(origin: origin, size: size).insetBy(dx: -12, dy: -12)
  }

  private static func measuredTextSize(for text: String) -> NSSize {
    let font = NSFont.systemFont(ofSize: 240, weight: .ultraLight)
    let rawSize = (text as NSString).size(withAttributes: [.font: font])
    let tracking = CGFloat(max(text.count - 1, 0)) * 12
    return NSSize(
      width: rawSize.width + tracking, height: font.ascender - font.descender + font.leading)
  }
}

extension WatermarkPosition {
  fileprivate var nsEdgeInsets: NSEdgeInsets {
    switch padding {
    case let insets:
      return NSEdgeInsets(
        top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
  }
}
