// Interaction — Option-click inline rename coordination.

import AppKit
import Foundation
import OverlayRenderer
import Persistence
import SpaceDetection

/// A user request to rename a Space.
public struct RenameRequest: Sendable {
    /// The Space identity being renamed.
    public let identity: SpaceIdentity

    /// Optional text proposed by the interaction surface.
    public let proposedName: String?

    /// Creates a rename request.
    public init(identity: SpaceIdentity, proposedName: String? = nil) {
        self.identity = identity
        self.proposedName = proposedName
    }
}

/// Source of user-initiated rename requests.
@MainActor
public protocol RenameRequestSource: AnyObject {
    /// Stream of rename requests.
    var renameRequests: AsyncStream<RenameRequest> { get }

    /// Starts listening for rename requests.
    func start()

    /// Stops listening for rename requests.
    func stop()
}

/// Small pure state machine for inline Space rename.
public struct RenameStateMachine: Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case editing(original: String, draft: String)
    }

    public private(set) var state: State = .idle

    public init() {}

    public mutating func begin(currentName: String) {
        state = .editing(original: currentName, draft: currentName)
    }

    public mutating func updateDraft(_ draft: String) {
        guard case .editing(let original, _) = state else { return }
        state = .editing(original: original, draft: draft)
    }

    public mutating func save() -> String? {
        guard case .editing(_, let draft) = state else { return nil }
        state = .idle
        return draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func cancel() {
        state = .idle
    }

    public var isEditing: Bool {
        if case .editing = state { return true }
        return false
    }
}

/// Coordinates Option-key mouse enabling, watermark clicks, and persisted inline rename.
@MainActor
public final class OptionClickRenameController {
    private let overlayController: OverlayController
    private let nameStore: SpaceNameStore
    private let currentIdentity: () -> SpaceIdentity?
    private let refreshDisplayName: () -> Void
    private var flagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var optionIsHeld = false
    private var stateMachine = RenameStateMachine()

    public init(
        overlayController: OverlayController,
        nameStore: SpaceNameStore,
        currentIdentity: @escaping () -> SpaceIdentity?,
        refreshDisplayName: @escaping () -> Void
    ) {
        self.overlayController = overlayController
        self.nameStore = nameStore
        self.currentIdentity = currentIdentity
        self.refreshDisplayName = refreshDisplayName
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    public func start() {
        overlayController.onInteraction = { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .optionClick = event, self.optionIsHeld {
                    self.beginRenameProgrammatically()
                }
            }
        }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async {
                self?.setOptionHeld(event.modifierFlags.contains(.option))
            }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.setOptionHeld(event.modifierFlags.contains(.option))
            return event
        }
    }

    public func stop() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
            self.localFlagsMonitor = nil
        }
        overlayController.onInteraction = nil
        overlayController.setOptionKeyHeld(false)
        overlayController.setMouseEventsEnabled(false)
    }

    public func beginRenameProgrammatically() {
        guard !stateMachine.isEditing, let identity = currentIdentity() else { return }
        let currentName = nameStore.name(for: identity) ?? "UNNAMED"
        stateMachine.begin(currentName: currentName)
        overlayController.beginRename(
            text: currentName,
            onCommit: { [weak self] newName in
                self?.commitRename(newName)
            },
            onCancel: { [weak self] in
                self?.cancelRename()
            }
        )
    }

    #if DEBUG
    func beginRenameForTesting(currentName: String) {
        stateMachine.begin(currentName: currentName)
    }
    #endif

    func commitRename(_ rawName: String) {
        // Invariant: capture the Space identity fresh at submit time, using the same
        // fingerprinter path as display refresh, so rename writes exactly what is current now.
        guard let identity = currentIdentity() else {
            cancelRename()
            return
        }
        stateMachine.updateDraft(rawName)
        let savedName = stateMachine.save().flatMap { $0.isEmpty ? nil : $0 } ?? "UNNAMED"
        nameStore.setName(savedName, for: identity)
        overlayController.endRename(keepMouseEventsEnabled: optionIsHeld)
        refreshDisplayName()
    }

    private func cancelRename() {
        stateMachine.cancel()
        overlayController.endRename(keepMouseEventsEnabled: optionIsHeld)
        refreshDisplayName()
    }

    private func setOptionHeld(_ isHeld: Bool) {
        optionIsHeld = isHeld
        overlayController.setOptionKeyHeld(isHeld)
        if !stateMachine.isEditing {
            overlayController.setMouseEventsEnabled(isHeld)
        }
    }
}

/// Stub rename source retained for tests and older wiring; it emits no requests.
@MainActor
public final class StubRenameRequestSource: RenameRequestSource {
    public let renameRequests: AsyncStream<RenameRequest>
    private let continuation: AsyncStream<RenameRequest>.Continuation

    public init() {
        let streamPair = AsyncStream<RenameRequest>.makeStream()
        self.renameRequests = streamPair.stream
        self.continuation = streamPair.continuation
    }

    deinit { continuation.finish() }
    public func start() {}
    public func stop() {}
}
