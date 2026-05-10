// SpaceFingerprinter — public Core Graphics signal collection for heuristic Space identity.

import AppKit
import CoreGraphics
import CryptoKit
import Foundation

/// Normalized window data used to build a stable Space window signature.
public struct SpaceWindowSnapshot: Hashable, Sendable {
    public let bundleID: String
    public let title: String
    public let layer: Int
    public let bounds: CGRect

    public init(bundleID: String, title: String, layer: Int, bounds: CGRect) {
        self.bundleID = bundleID
        self.title = title
        self.layer = layer
        self.bounds = bounds
    }

    var signatureToken: String {
        "\(bundleID):\(title)"
    }
}

/// Collects current-display and current-window signals for public-API Space identity.
@MainActor
public final class SpaceFingerprinter {
    private struct SeenSpace {
        let ordinal: Int
        let firstSeen: Date
    }

    private struct SeenKey: Hashable {
        let displayUUID: String
        let windowSignature: WindowSignature
        let frontmostAppBundleID: String?
        let windowCount: Int
        let windowGeometrySignature: [String]
    }

    private var seenSpaces: [SeenKey: SeenSpace] = [:]
    private var nextOrdinalByDisplay: [String: Int] = [:]
    private let now: () -> Date
    private let windowProvider: @MainActor () -> [[String: Any]]
    private let cgsSpaceIDProvider: (String) -> UInt64?

    public init(
        now: @escaping () -> Date = Date.init,
        windowProvider: (@MainActor () -> [[String: Any]])? = nil,
        cgsSpaceIDProvider: ((String) -> UInt64?)? = nil
    ) {
        self.now = now
        self.windowProvider = windowProvider ?? SpaceFingerprinter.currentCGWindowInfo
        self.cgsSpaceIDProvider = cgsSpaceIDProvider ?? { currentCGSSpaceID(forDisplayUUID: $0) }
    }

    /// Builds a stable signature from normalized layer-0 application windows.
    nonisolated public static func windowSignature(from snapshots: [SpaceWindowSnapshot]) -> WindowSignature {
        WindowSignature(entries: snapshots
            .filter { $0.layer == 0 && !$0.bundleID.isEmpty && !$0.bounds.isEmpty }
            .map(\.signatureToken))
    }

    /// Produces compact, sorted geometry hashes from visible application windows.
    nonisolated public static func windowGeometrySignature(from snapshots: [SpaceWindowSnapshot], limit: Int = 8) -> [String] {
        snapshots
            .filter { $0.layer == 0 && !$0.bundleID.isEmpty && !$0.bounds.isEmpty }
            .map { snapshot in
                let bounds = snapshot.bounds.integral
                let token = "\(snapshot.bundleID):\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.width)),\(Int(bounds.height))"
                let digest = SHA256.hash(data: Data(token.utf8))
                return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
            }
            .sorted()
            .prefix(max(0, limit))
            .map { $0 }
    }

    /// Produces the primary current active-Space identity, matching the first display snapshot used by the app read path.
    public func currentIdentity() -> SpaceIdentity? {
        currentSnapshots().first?.identity
    }

    /// Produces current active-Space snapshots for each known screen.
    public func currentSnapshots() -> [SpaceSnapshot] {
        let observedAt = now()
        let rawWindows = windowProvider()
        let frontmostAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return NSScreen.screens.map { screen in
            let displayID = screen.displayID ?? 0
            let displayUUID = Self.displayUUID(for: displayID)
            // Private/undocumented CGS gotcha: CGSGetActiveSpace is global to the focused
            // display. Per-overlay identity must use CGSManagedDisplayGetCurrentSpace with
            // this NSScreen's display UUID, or multi-display Space names can be cross-bound.
            let cgsID = cgsSpaceIDProvider(displayUUID)
            let screenWindows = Self.normalizedWindows(from: rawWindows, intersecting: screen.frame)
            let signature = Self.windowSignature(from: screenWindows)
            let geometrySignature = Self.windowGeometrySignature(from: screenWindows)
            let key = SeenKey(
                displayUUID: displayUUID,
                windowSignature: signature,
                frontmostAppBundleID: frontmostAppBundleID,
                windowCount: screenWindows.count,
                windowGeometrySignature: geometrySignature
            )
            let seen = seenSpaces[key] ?? rememberNewSpace(for: key, at: observedAt)

            return SpaceSnapshot(
                identity: SpaceIdentity(
                    displayUUID: displayUUID,
                    windowSignature: signature,
                    ordinal: seen.ordinal,
                    firstSeen: seen.firstSeen,
                    frontmostAppBundleID: frontmostAppBundleID,
                    windowCount: screenWindows.count,
                    windowGeometrySignature: geometrySignature,
                    cgsSpaceID: cgsID
                ),
                displayID: displayID,
                confidence: cgsID == nil ? (signature.entries.isEmpty && frontmostAppBundleID == nil ? .low : .medium) : .high,
                timestamp: observedAt
            )
        }
    }

    private func rememberNewSpace(for key: SeenKey, at date: Date) -> SeenSpace {
        let ordinal = nextOrdinalByDisplay[key.displayUUID, default: 1]
        nextOrdinalByDisplay[key.displayUUID] = ordinal + 1
        let seen = SeenSpace(ordinal: ordinal, firstSeen: date)
        seenSpaces[key] = seen
        return seen
    }

    private static func currentCGWindowInfo() -> [[String: Any]] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return info
    }

    nonisolated public static func normalizedWindows(from windows: [[String: Any]], intersecting displayFrame: CGRect? = nil) -> [SpaceWindowSnapshot] {
        windows.compactMap { window in
            let layer = window[kCGWindowLayer as String] as? Int ?? (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? Int.min
            guard layer == 0 else { return nil }

            let bounds = Self.bounds(from: window[kCGWindowBounds as String])
            guard !bounds.isEmpty else { return nil }
            if let displayFrame, !bounds.intersects(displayFrame) { return nil }

            let bundleID = Self.bundleID(from: window)
            guard !bundleID.isEmpty else { return nil }
            let title = (window[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return SpaceWindowSnapshot(bundleID: bundleID, title: title, layer: layer, bounds: bounds)
        }
    }

    nonisolated private static func bundleID(from window: [String: Any]) -> String {
        if let bundleID = window["bundleID"] as? String {
            return bundleID
        }
        if let bundleID = window["bundleIdentifier"] as? String {
            return bundleID
        }
        if let pidNumber = window[kCGWindowOwnerPID as String] as? NSNumber,
           let app = NSRunningApplication(processIdentifier: pidNumber.int32Value),
           let bundleID = app.bundleIdentifier
        {
            return bundleID
        }
        return (window[kCGWindowOwnerName as String] as? String) ?? ""
    }

    nonisolated private static func bounds(from value: Any?) -> CGRect {
        guard let dictionary = value as? NSDictionary else { return .null }
        var rect = CGRect.null
        return CGRectMakeWithDictionaryRepresentation(dictionary, &rect) ? rect : .null
    }

    private static func displayUUID(for displayID: CGDirectDisplayID) -> String {
        guard displayID != 0, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return "unknown-display"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

public extension WindowSignature {
    /// SHA-256 of the sorted signature entries, shortened for diagnostics and stable tests.
    var stableHash: String {
        let joined = entries.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
