// OverlayRenderer — transparent AppKit windows hosting a SwiftUI watermark.

import AppKit
import Combine
import CoreGraphics
import Persistence
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

/// Observable watermark appearance shared by the overlay and Preferences window.
@MainActor
public final class WatermarkAppearance: ObservableObject {
  @Published public var preferences: WatermarkPreferences

  public init(preferences: WatermarkPreferences = .defaults) {
    self.preferences = preferences
  }

  public var color: CodableColor {
    get { preferences.color }
    set { preferences = preferences.replacing(color: newValue.withOpaqueAlpha) }
  }

  public var opacity: Double {
    get { preferences.opacity }
    set { preferences = preferences.replacing(opacity: newValue) }
  }

  public var fontSize: CGFloat {
    get { preferences.fontSize }
    set { preferences = preferences.replacing(fontSize: newValue) }
  }

  public var fontFamily: WatermarkFontFamily {
    get { preferences.fontFamily }
    set { preferences = preferences.replacing(fontFamily: newValue) }
  }

  public var position: WatermarkPosition {
    get { preferences.position }
    set { preferences = preferences.replacing(position: newValue) }
  }
}

/// Named color options that preserve the app's quiet signage language.
public struct WatermarkSwatch: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let color: CodableColor

  public init(id: String, name: String, color: CodableColor) {
    self.id = id
    self.name = name
    self.color = color
  }

  public static let curated: [WatermarkSwatch] = [
    WatermarkSwatch(id: "warm-off-white", name: "Warm off-white", color: CodableColor(red: 0.957, green: 0.945, blue: 0.918, alpha: 1.0)),
    WatermarkSwatch(id: "cool-gray", name: "Cool gray", color: CodableColor(red: 0.72, green: 0.76, blue: 0.78, alpha: 1.0)),
    WatermarkSwatch(id: "soft-amber", name: "Soft amber", color: CodableColor(red: 0.92, green: 0.72, blue: 0.44, alpha: 1.0)),
    WatermarkSwatch(id: "muted-teal", name: "Muted teal", color: CodableColor(red: 0.48, green: 0.72, blue: 0.70, alpha: 1.0)),
    WatermarkSwatch(id: "dust-blue", name: "Dust blue", color: CodableColor(red: 0.55, green: 0.64, blue: 0.78, alpha: 1.0)),
    WatermarkSwatch(id: "soft-lavender", name: "Soft lavender", color: CodableColor(red: 0.70, green: 0.62, blue: 0.82, alpha: 1.0)),
  ]
}

/// Testable view-model surface for preference controls.
@MainActor
public final class WatermarkPreferencesViewModel: ObservableObject {
  public let appearance: WatermarkAppearance

  public init(appearance: WatermarkAppearance) {
    self.appearance = appearance
  }

  public var swatches: [WatermarkSwatch] { WatermarkSwatch.curated }
  public var cornerPositions: [WatermarkPosition] { WatermarkPosition.cornerCases }
  public var opacityLabel: String { "\(Int((appearance.opacity * 100).rounded()))%" }
  public var fontSizeLabel: String { "\(Int(appearance.fontSize.rounded())) pt" }

  @discardableResult
  public func apply(_ preferences: WatermarkPreferences) -> WatermarkPreferences {
    let normalized = normalized(preferences)
    appearance.preferences = normalized
    return normalized
  }

  public func chooseSwatch(_ swatch: WatermarkSwatch) {
    apply(appearance.preferences.replacing(color: swatch.color.withOpaqueAlpha))
  }

  public func setColor(_ color: CodableColor) {
    apply(appearance.preferences.replacing(color: color.withOpaqueAlpha))
  }

  public func setOpacity(_ opacity: Double) {
    apply(appearance.preferences.replacing(opacity: opacity))
  }

  public func setFontSize(_ fontSize: CGFloat) {
    apply(appearance.preferences.replacing(fontSize: fontSize))
  }

  public func setFontFamily(_ fontFamily: WatermarkFontFamily) {
    apply(appearance.preferences.replacing(fontFamily: fontFamily))
  }

  public func setPosition(_ position: WatermarkPosition) {
    guard WatermarkPosition.cornerCases.contains(position) else { return }
    apply(appearance.preferences.replacing(position: position))
  }

  private func normalized(_ preferences: WatermarkPreferences) -> WatermarkPreferences {
    let position = WatermarkPosition.cornerCases.contains(preferences.position)
      ? preferences.position
      : appearance.position
    return WatermarkPreferences(
      color: preferences.color.withOpaqueAlpha,
      opacity: min(1.0, max(0.01, preferences.opacity)),
      fontSize: min(400, max(80, preferences.fontSize)),
      fontFamily: preferences.fontFamily,
      position: position
    )
  }
}

public extension WatermarkPreferences {
  func replacing(
    color: CodableColor? = nil,
    opacity: Double? = nil,
    fontSize: CGFloat? = nil,
    fontFamily: WatermarkFontFamily? = nil,
    position: WatermarkPosition? = nil
  ) -> WatermarkPreferences {
    WatermarkPreferences(
      color: color ?? self.color,
      opacity: opacity ?? self.opacity,
      fontSize: fontSize ?? self.fontSize,
      fontFamily: fontFamily ?? self.fontFamily,
      position: position ?? self.position
    )
  }
}

public extension CodableColor {
  var swiftUIColor: Color {
    Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
  }

  var nsColor: NSColor {
    NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
  }

  init(nsColor: NSColor) {
    let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
    self.init(red: Double(color.redComponent), green: Double(color.greenComponent), blue: Double(color.blueComponent), alpha: Double(color.alphaComponent))
  }

  init(swiftUIColor: Color) {
    self.init(nsColor: NSColor(swiftUIColor))
  }
}

public extension WatermarkPosition {
  var displayName: String {
    switch self {
    case .lowerRight: return "Lower Right"
    case .lowerLeft: return "Lower Left"
    case .upperRight: return "Upper Right"
    case .upperLeft: return "Upper Left"
    case .center: return "Center"
    }
  }

  var diagonalOpposite: WatermarkPosition {
    switch self {
    case .lowerRight: return .upperLeft
    case .lowerLeft: return .upperRight
    case .upperRight: return .lowerLeft
    case .upperLeft: return .lowerRight
    case .center: return .center
    }
  }

  fileprivate var alignment: Alignment {
    switch self {
    case .lowerRight: return .bottomTrailing
    case .lowerLeft: return .bottomLeading
    case .upperRight: return .topTrailing
    case .upperLeft: return .topLeading
    case .center: return .center
    }
  }

  fileprivate var padding: EdgeInsets {
    switch self {
    case .lowerRight, .lowerLeft, .upperRight, .upperLeft:
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
  private let color: CodableColor
  private let fontSize: CGFloat
  private let fontFamily: WatermarkFontFamily
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
    color: CodableColor = .defaultWatermark,
    opacity: CGFloat = 0.10,
    fontSize: CGFloat = 240,
    fontFamily: WatermarkFontFamily = .sfPro,
    position: WatermarkPosition = .lowerRight,
    isEditing: Bool = false,
    onTap: (() -> Void)? = nil,
    onCommit: ((String) -> Void)? = nil,
    onCancel: (() -> Void)? = nil
  ) {
    self.text = text
    self.opacity = opacity
    self.color = color
    self.fontSize = fontSize
    self.fontFamily = fontFamily
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
        .font(Font(fontFamily.nsFont(size: fontSize, weight: .ultraLight)))
        .tracking(12)
        .foregroundStyle(Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: max(0.35, opacity)))
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
        .font(Font(fontFamily.nsFont(size: fontSize, weight: .ultraLight)))
        .tracking(12)
        .foregroundStyle(color.swiftUIColor.opacity(opacity))
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
    var text: String
    var hoverState: WatermarkHoverFleeState
  }

  /// Publisher/callback for user interaction events on the overlay.
  public var onInteraction: (@Sendable (OverlayInteractionEvent) -> Void)?

  private var managedWindows: [ManagedWindow] = []
  internal private(set) var currentText: String = "PROTOTYPE"
  internal private(set) var textsByScreenID: [CGDirectDisplayID: String] = [:]
  private let appearance: WatermarkAppearance
  private var appearanceCancellable: AnyCancellable?
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
    textSource: OverlayTextSource = .prototype,
    watermarkPosition: WatermarkPosition = .lowerRight,
    watermarkAppearance: WatermarkAppearance? = nil
  ) {
    self.appearance = watermarkAppearance ?? WatermarkAppearance(
      preferences: WatermarkPreferences(color: .defaultWatermark, opacity: 0.10, fontSize: 240, position: watermarkPosition)
    )
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
    appearanceCancellable = appearance.objectWillChange.sink { [weak self] _ in
      DispatchQueue.main.async {
        self?.appearanceDidChange()
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
    let existingTexts = Dictionary(uniqueKeysWithValues: managedWindows.map { ($0.screenID, $0.text) })
    guard currentText != text || existingTexts.values.contains(where: { $0 != text }) else { return }
    currentText = text
    textsByScreenID = Dictionary(uniqueKeysWithValues: managedWindows.map { ($0.screenID, text) })
    for index in managedWindows.indices {
      managedWindows[index].text = text
    }
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
        color: appearance.color,
        opacity: CGFloat(appearance.opacity),
        fontSize: appearance.fontSize,
        fontFamily: appearance.fontFamily,
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
    guard !content.isEmpty else {
      hide()
      return
    }

    let textByScreenID = Dictionary(uniqueKeysWithValues: content.map { ($0.screenID, $0.text) })
    currentText = content.first?.text ?? currentText
    textsByScreenID = textByScreenID

    var changed = false
    for index in managedWindows.indices {
      guard let text = textByScreenID[managedWindows[index].screenID], managedWindows[index].text != text else { continue }
      managedWindows[index].text = text
      changed = true
    }

    guard changed, !isRenaming else { return }
    renderDisplayMode()
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

  private func appearanceDidChange() {
    guard !managedWindows.isEmpty else { return }
    var positionChanged = false
    for index in managedWindows.indices where managedWindows[index].hoverState.configuredPosition != appearance.position {
      managedWindows[index].hoverState = WatermarkHoverFleeState(configuredPosition: appearance.position)
      positionChanged = true
    }
    if positionChanged {
      lastInsideStates.removeAll()
    }
    guard !isRenaming else { return }
    renderDisplayMode()
  }

  @objc private func screenParametersDidChange() {
    rebuildWindows()
  }

  private func renderDisplayMode() {
    managedWindows.forEach { managed in
      managed.hostingView.rootView = WatermarkView(
        text: managed.text,
        color: appearance.color,
        opacity: CGFloat(appearance.opacity),
        fontSize: appearance.fontSize,
        fontFamily: appearance.fontFamily,
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
      let screenID = displayID(for: screen)
      let text = textsByScreenID[screenID] ?? currentText
      let hoverState = WatermarkHoverFleeState(configuredPosition: appearance.position)
      let hostingView = NSHostingView(
        rootView: WatermarkView(
          text: text,
          color: appearance.color,
          opacity: CGFloat(appearance.opacity),
          fontSize: appearance.fontSize,
          fontFamily: appearance.fontFamily,
          position: hoverState.currentPosition,
          onTap: { [weak self] in
            guard let self else { return }
            self.onInteraction?(.optionClick(screenID: screenID))
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
        screenID: screenID,
        text: text,
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
        text: managedWindows[index].text,
        color: appearance.color,
        opacity: CGFloat(appearance.opacity),
        fontSize: appearance.fontSize,
        fontFamily: appearance.fontFamily,
        position: nextPosition,
        onTap: { [weak self] in
          self?.onInteraction?(.optionClick(screenID: screenID))
        }
      )
    }
  }

  private func watermarkRect(for managed: ManagedWindow) -> NSRect {
    WatermarkGeometry.rect(
      for: managed.text,
      position: managed.hoverState.currentPosition,
      fontSize: appearance.fontSize,
      fontFamily: appearance.fontFamily,
      in: managed.window.frame
    )
  }
}

private enum WatermarkGeometry {
  static func rect(
    for text: String,
    position: WatermarkPosition,
    fontSize: CGFloat = 240,
    fontFamily: WatermarkFontFamily = .sfPro,
    in container: NSRect
  ) -> NSRect {
    let size = measuredTextSize(for: text, fontSize: fontSize, fontFamily: fontFamily)
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

  private static func measuredTextSize(for text: String, fontSize: CGFloat, fontFamily: WatermarkFontFamily) -> NSSize {
    let font = fontFamily.nsFont(size: fontSize, weight: .ultraLight)
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
