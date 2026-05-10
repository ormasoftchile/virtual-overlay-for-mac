// SpaceDetection — public-API Space change observation and heuristic identities.

import AppKit
import CoreGraphics
import Foundation

/// A fuzzy-matchable signature for the window set visible on a Space.
public struct WindowSignature: Codable, Hashable, Sendable {
    /// Stable, sorted "Owner:Title" tokens used for Jaccard similarity.
    public let entries: [String]

    /// Creates a normalized signature from already-extracted window tokens.
    public init(entries: [String]) {
        self.entries = Array(Set(entries.filter { !$0.isEmpty })).sorted()
    }

    /// Creates a stable signature from the public Core Graphics window-list shape.
    public static func compute(from windows: [[String: Any]]) -> WindowSignature {
        SpaceFingerprinter.windowSignature(from: SpaceFingerprinter.normalizedWindows(from: windows))
    }

    /// Jaccard similarity between two window sets. Returns 1.0 for two empty signatures.
    public func similarity(to other: WindowSignature) -> Double {
        jaccardSimilarity(lhs: Set(entries), rhs: Set(other.entries))
    }

    /// Bundle identifiers extracted from the window tokens, for lower-noise fuzzy matching.
    public var bundleIDs: [String] {
        Array(Set(entries.compactMap { entry in
            let bundleID = entry.split(separator: ":", maxSplits: 1).first.map(String.init) ?? entry
            return bundleID.isEmpty ? nil : bundleID
        })).sorted()
    }

    /// Jaccard similarity over visible app bundle identifiers.
    public func bundleIDSimilarity(to other: WindowSignature) -> Double {
        jaccardSimilarity(lhs: Set(bundleIDs), rhs: Set(other.bundleIDs))
    }

    public static let empty = WindowSignature(entries: [])

    private func jaccardSimilarity(lhs: Set<String>, rhs: Set<String>) -> Double {
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 1.0 }
        return Double(lhs.intersection(rhs).count) / Double(union.count)
    }
}

/// Heuristic identity for a macOS Space, optionally anchored by a private CGS Space ID.
///
/// macOS does not expose a stable public Space UUID. This fingerprint combines display
/// UUID, visible-window signature, frontmost app, window count, lightweight window
/// geometry, inferred ordinal, and first-seen timestamp. When `cgsSpaceID` is present,
/// it is authoritative for the current login session only; stored CGS IDs are cleared
/// in memory on app launch and are not re-bound from heuristic-only entries.
public struct SpaceIdentity: Codable, Hashable, Sendable {
    /// Session-scoped private CGS Space ID. Not stable across reboots.
    public let cgsSpaceID: UInt64?

    /// The best available UUID string for the display that owns this Space.
    public let displayUUID: String

    /// A fuzzy-matchable fingerprint of windows visible on this Space.
    public let windowSignature: WindowSignature

    /// Bundle identifier for the app frontmost when the Space was fingerprinted.
    public let frontmostAppBundleID: String?

    /// Count of visible layer-0 application windows on this display.
    public let windowCount: Int

    /// Small, sorted hashes of visible window positions and sizes.
    public let windowGeometrySignature: [String]

    /// A one-based, session-scoped ordinal estimate for the Space on its display.
    public let ordinal: Int?

    /// The first time Virtual Overlay observed this candidate Space.
    public let firstSeen: Date

    /// Creates a heuristic Space identity.
    public init(
        displayUUID: String,
        windowSignature: WindowSignature,
        ordinal: Int?,
        firstSeen: Date,
        frontmostAppBundleID: String? = nil,
        windowCount: Int = 0,
        windowGeometrySignature: [String] = [],
        cgsSpaceID: UInt64? = nil
    ) {
        self.cgsSpaceID = cgsSpaceID
        self.displayUUID = displayUUID
        self.windowSignature = windowSignature
        self.frontmostAppBundleID = frontmostAppBundleID
        self.windowCount = windowCount
        self.windowGeometrySignature = windowGeometrySignature
        self.ordinal = ordinal
        self.firstSeen = firstSeen
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cgsSpaceID = try container.decodeIfPresent(UInt64.self, forKey: .cgsSpaceID)
        displayUUID = try container.decode(String.self, forKey: .displayUUID)
        windowSignature = try container.decode(WindowSignature.self, forKey: .windowSignature)
        frontmostAppBundleID = try container.decodeIfPresent(String.self, forKey: .frontmostAppBundleID)
        windowCount = try container.decodeIfPresent(Int.self, forKey: .windowCount) ?? -1
        windowGeometrySignature = try container.decodeIfPresent([String].self, forKey: .windowGeometrySignature) ?? []
        ordinal = try container.decodeIfPresent(Int.self, forKey: .ordinal)
        firstSeen = try container.decode(Date.self, forKey: .firstSeen)
    }

    /// Returns true when the stable match signals are identical.
    public func hasSameSignals(as other: SpaceIdentity) -> Bool {
        if let cgsSpaceID, let otherCGSSpaceID = other.cgsSpaceID {
            return cgsSpaceID == otherCGSSpaceID && displayUUID == other.displayUUID
        }
        return displayUUID == other.displayUUID &&
            windowSignature == other.windowSignature &&
            frontmostAppBundleID == other.frontmostAppBundleID &&
            windowCount == other.windowCount &&
            windowGeometrySignature == other.windowGeometrySignature &&
            ordinal == other.ordinal
    }

    /// Carries forward the original first-seen anchor while refreshing volatile signals.
    public func refreshingSignals(from currentFingerprint: SpaceIdentity) -> SpaceIdentity {
        SpaceIdentity(
            displayUUID: currentFingerprint.displayUUID,
            windowSignature: currentFingerprint.windowSignature,
            ordinal: currentFingerprint.ordinal,
            firstSeen: firstSeen,
            frontmostAppBundleID: currentFingerprint.frontmostAppBundleID,
            windowCount: currentFingerprint.windowCount,
            windowGeometrySignature: currentFingerprint.windowGeometrySignature,
            cgsSpaceID: currentFingerprint.cgsSpaceID
        )
    }

    /// Returns this identity with the session-scoped CGS ID cleared.
    public func clearingCGSSpaceID() -> SpaceIdentity {
        SpaceIdentity(
            displayUUID: displayUUID,
            windowSignature: windowSignature,
            ordinal: ordinal,
            firstSeen: firstSeen,
            frontmostAppBundleID: frontmostAppBundleID,
            windowCount: windowCount,
            windowGeometrySignature: windowGeometrySignature,
            cgsSpaceID: nil
        )
    }
}

/// Confidence level for a detected Space snapshot.
public enum SpaceDetectionConfidence: Comparable, Sendable {
    /// The identity is a weak public-API heuristic.
    case low

    /// The identity combines enough public signals to be moderately trustworthy.
    case medium

    /// The identity is backed by a stable source. v1 public APIs do not reach this level.
    case high
}

/// A point-in-time view of the active Space for one display.
public struct SpaceSnapshot: Sendable {
    /// The heuristic identity for the active Space.
    public let identity: SpaceIdentity

    /// The CoreGraphics display identifier for the display.
    public let displayID: CGDirectDisplayID

    /// The confidence level for this snapshot.
    public let confidence: SpaceDetectionConfidence

    /// The time this snapshot was produced.
    public let timestamp: Date

    /// Creates a Space snapshot.
    public init(identity: SpaceIdentity, displayID: CGDirectDisplayID, confidence: SpaceDetectionConfidence, timestamp: Date) {
        self.identity = identity
        self.displayID = displayID
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

/// Event emitted when the public Space-change notification fires.
public struct SpaceChangeEvent: Sendable {
    /// Snapshots for the displays known at the moment of the event.
    public let snapshots: [SpaceSnapshot]

    /// The time the event was emitted.
    public let timestamp: Date

    /// Creates a Space-change event.
    public init(snapshots: [SpaceSnapshot], timestamp: Date) {
        self.snapshots = snapshots
        self.timestamp = timestamp
    }
}

/// Public surface for a pluggable Space detection strategy.
@MainActor
public protocol SpaceDetectionStrategy: AnyObject {
    /// Human-readable strategy name for diagnostics.
    var name: String { get }

    /// Continuous Space-change events emitted by the strategy.
    var changes: AsyncStream<SpaceChangeEvent> { get }

    /// One-shot detection of the currently active Space snapshots.
    func detect() async throws -> [SpaceSnapshot]

    /// Begins observing Space changes.
    func startObserving()

    /// Stops observing Space changes.
    func stopObserving()
}

/// Public-API-only detector backed by `NSWorkspace.activeSpaceDidChangeNotification`.
@MainActor
public final class NSWorkspaceSpaceDetector: SpaceDetectionStrategy {
    /// Human-readable strategy name for diagnostics.
    public let name = "NSWorkspacePublicAPI"

    /// Continuous Space-change events emitted by the detector.
    public let changes: AsyncStream<SpaceChangeEvent>

    private let continuation: AsyncStream<SpaceChangeEvent>.Continuation
    private let notificationCenter: NotificationCenter
    private let notificationName: Notification.Name
    private let snapshotProvider: @MainActor () -> [SpaceSnapshot]
    private var observer: NSObjectProtocol?

    /// Creates a detector using public `NSWorkspace` notifications.
    public init(
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        notificationName: Notification.Name = NSWorkspace.activeSpaceDidChangeNotification,
        snapshotProvider: (@MainActor () -> [SpaceSnapshot])? = nil
    ) {
        let streamPair = AsyncStream<SpaceChangeEvent>.makeStream()
        self.changes = streamPair.stream
        self.continuation = streamPair.continuation
        self.notificationCenter = notificationCenter
        self.notificationName = notificationName
        if let snapshotProvider {
            self.snapshotProvider = snapshotProvider
        } else {
            let fingerprinter = SpaceFingerprinter()
            self.snapshotProvider = { fingerprinter.currentSnapshots() }
        }
    }

    deinit {
        observer.map(notificationCenter.removeObserver)
        continuation.finish()
    }

    /// One-shot detection of the currently active Space snapshots.
    public func detect() async throws -> [SpaceSnapshot] {
        snapshotProvider()
    }

    /// Begins observing public Space-change notifications.
    public func startObserving() {
        guard observer == nil else { return }
        observer = notificationCenter.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.emitChange()
            }
        }
    }

    /// Stops observing public Space-change notifications.
    public func stopObserving() {
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func emitChange() {
        let event = SpaceChangeEvent(snapshots: snapshotProvider(), timestamp: Date())
        continuation.yield(event)
    }

    private static func defaultSnapshots() -> [SpaceSnapshot] {
        SpaceFingerprinter().currentSnapshots()
    }

    private static func displayUUID(for displayID: CGDirectDisplayID) -> String {
        guard displayID != 0, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return "unknown-display"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }

    // TODO.v2: slot a private-API strategy behind SpaceDetectionStrategy only if the team reverses the public-API-only v1 decision.
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
