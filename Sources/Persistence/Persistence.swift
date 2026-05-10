// Persistence — JSON-backed storage for user-assigned Space names.

import AppKit
import CoreGraphics
import Foundation
import SpaceDetection


/// RGBA color value suitable for stable JSON persistence. Components are sRGB doubles in 0...1.
public struct CodableColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let defaultWatermark = CodableColor(red: 1, green: 1, blue: 1, alpha: 1.0)

    public var withOpaqueAlpha: CodableColor {
        CodableColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

/// Supported screen positions for the watermark.
public enum WatermarkPosition: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case lowerRight
    case lowerLeft
    case upperRight
    case upperLeft
    case center

    public var id: String { rawValue }

    public static let cornerCases: [WatermarkPosition] = [.upperLeft, .upperRight, .lowerLeft, .lowerRight]
}

/// Curated system font families available for the watermark.
public enum WatermarkFontFamily: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case sfPro
    case sfMono
    case newYork
    case helveticaNeue
    case menlo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sfPro: return "SF Pro"
        case .sfMono: return "SF Mono"
        case .newYork: return "New York"
        case .helveticaNeue: return "Helvetica Neue"
        case .menlo: return "Menlo"
        }
    }

    public func nsFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        switch self {
        case .sfPro:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .sfMono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .newYork:
            return Self.designedSystemFont(size: size, weight: weight, design: .serif)
        case .helveticaNeue:
            return Self.namedSystemFont(familyName: "Helvetica Neue", size: size, weight: weight)
                ?? NSFont.systemFont(ofSize: size, weight: weight)
        case .menlo:
            return Self.namedSystemFont(familyName: "Menlo", size: size, weight: weight)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    private static func designedSystemFont(size: CGFloat, weight: NSFont.Weight, design: NSFontDescriptor.SystemDesign) -> NSFont {
        let baseDescriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        let designedDescriptor = baseDescriptor.withDesign(design) ?? baseDescriptor
        return NSFont(descriptor: designedDescriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    private static func namedSystemFont(familyName: String, size: CGFloat, weight: NSFont.Weight) -> NSFont? {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: familyName,
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        return NSFont(descriptor: descriptor, size: size)
    }
}

/// User-tunable watermark appearance preferences.
public struct WatermarkPreferences: Codable, Equatable, Sendable {
    public var color: CodableColor
    public var opacity: Double
    public var fontSize: CGFloat
    public var fontFamily: WatermarkFontFamily
    public var position: WatermarkPosition

    public init(
        color: CodableColor,
        opacity: Double,
        fontSize: CGFloat,
        fontFamily: WatermarkFontFamily = .sfPro,
        position: WatermarkPosition
    ) {
        self.color = color.withOpaqueAlpha
        self.opacity = WatermarkPreferences.clampedOpacity(opacity)
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.position = position
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedColor = try container.decode(CodableColor.self, forKey: .color)
        let decodedOpacity = try container.decodeIfPresent(Double.self, forKey: .opacity)
        color = decodedColor.withOpaqueAlpha
        opacity = WatermarkPreferences.clampedOpacity(decodedOpacity ?? decodedColor.alpha)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        fontFamily = try container.decodeIfPresent(WatermarkFontFamily.self, forKey: .fontFamily) ?? .sfPro
        position = try container.decode(WatermarkPosition.self, forKey: .position)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color.withOpaqueAlpha, forKey: .color)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(position, forKey: .position)
    }

    public static let defaults = WatermarkPreferences(
        color: .defaultWatermark,
        opacity: 0.10,
        fontSize: 240,
        fontFamily: .sfPro,
        position: .lowerRight
    )

    private enum CodingKeys: String, CodingKey {
        case color
        case opacity
        case fontSize
        case fontFamily
        case position
    }

    private static func clampedOpacity(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

/// Stores and retrieves persisted watermark preferences.
@MainActor
public protocol PreferencesStore: AnyObject {
    func preferences() -> WatermarkPreferences
    func save(_ preferences: WatermarkPreferences)
}

/// JSON file implementation of `PreferencesStore`.
@MainActor
public final class JSONFilePreferencesStore: PreferencesStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? JSONFilePreferencesStore.defaultFileURL()
    }

    public func preferences() -> WatermarkPreferences {
        guard let data = try? Data(contentsOf: fileURL),
              let preferences = try? JSONDecoder.virtualOverlay.decode(WatermarkPreferences.self, from: data)
        else { return .defaults }
        return preferences
    }

    public func save(_ preferences: WatermarkPreferences) {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder.virtualOverlay.encode(preferences)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save preferences: \(error)")
        }
    }

    private static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("VirtualOverlay", isDirectory: true)
            .appendingPathComponent("preferences.json")
    }
}

/// Stores and retrieves user-assigned names for heuristic Space identities.
@MainActor
public protocol SpaceNameStore: AnyObject {
    /// Returns the stored name for a Space identity, if one is known.
    func name(for identity: SpaceIdentity) -> String?

    /// Stores or replaces the name for a Space identity.
    func setName(_ name: String, for identity: SpaceIdentity)

    /// Matches a current Space fingerprint to a stored identity, exact first, then fuzzy.
    func match(currentFingerprint: SpaceIdentity) -> SpaceIdentity?

    /// Returns every known Space identity and its stored name.
    func allKnown() -> [SpaceIdentity: String]
}

/// JSON file implementation of `SpaceNameStore`.
@MainActor
public final class JSONFileSpaceNameStore: SpaceNameStore {
    private struct Entry: Codable {
        let identity: SpaceIdentity
        let name: String
    }

    private static let fuzzyWindowThreshold = 0.8
    private static let fuzzyWinnerMargin = 0.15

    private let fileURL: URL
    private var names: [SpaceIdentity: String]

    /// Creates a JSON store at the default Application Support location or an injected file URL.
    public init(fileURL: URL? = nil) {
        let resolvedFileURL = fileURL ?? JSONFileSpaceNameStore.defaultFileURL()
        self.fileURL = resolvedFileURL
        self.names = JSONFileSpaceNameStore.invalidatingSessionCGSIDs(JSONFileSpaceNameStore.load(from: resolvedFileURL))
    }

    /// Returns the stored name for a Space identity, if one is known.
    public func name(for identity: SpaceIdentity) -> String? {
        if let exactKeyName = names[identity] {
            return exactKeyName
        }
        guard let matchedIdentity = match(currentFingerprint: identity) else {
            return nil
        }
        return names[matchedIdentity]
    }

    /// Stores or replaces the name for a Space identity and persists the JSON file.
    public func setName(_ name: String, for identity: SpaceIdentity) {
        names[identity] = name
        save()
    }

    /// Matches current signals to a stored Space identity.
    ///
    /// Contract: CGS exact equality wins while CGS is available. Heuristic-only stored
    /// entries are intentionally not re-bound to fresh CGS IDs because that stale match can
    /// poison the new session's true Space identities.
    public func match(currentFingerprint: SpaceIdentity) -> SpaceIdentity? {
        if let currentCGS = currentFingerprint.cgsSpaceID, currentCGS > 0 {
            return names.keys.first(where: { $0.cgsSpaceID == currentCGS && $0.displayUUID == currentFingerprint.displayUUID })
        }

        if let exact = names.keys.first(where: { $0.hasSameSignals(as: currentFingerprint) }) {
            guard exact.cgsSpaceID != currentFingerprint.cgsSpaceID,
                  let name = names.removeValue(forKey: exact)
            else { return exact }
            let refreshed = exact.refreshingSignals(from: currentFingerprint)
            names[refreshed] = name
            save()
            return refreshed
        }

        guard let fuzzy = bestFuzzyMatch(for: currentFingerprint) else {
            return nil
        }

        guard let name = names.removeValue(forKey: fuzzy) else {
            return fuzzy
        }
        let refreshed = fuzzy.refreshingSignals(from: currentFingerprint)
        names[refreshed] = name
        save()
        return refreshed
    }

    /// Returns every known Space identity and its stored name.
    public func allKnown() -> [SpaceIdentity: String] {
        names
    }

    private func bestFuzzyMatch(for currentFingerprint: SpaceIdentity) -> SpaceIdentity? {
        guard let currentFrontmostApp = currentFingerprint.frontmostAppBundleID, !currentFrontmostApp.isEmpty else {
            return nil
        }

        let ranked = names.keys
            .filter {
                let cgsCompatible: Bool
                if let storedCGS = $0.cgsSpaceID, let currentCGS = currentFingerprint.cgsSpaceID {
                    cgsCompatible = storedCGS == currentCGS
                } else {
                    cgsCompatible = true
                }
                return cgsCompatible &&
                    $0.displayUUID == currentFingerprint.displayUUID &&
                    $0.frontmostAppBundleID == currentFrontmostApp
            }
            .map { candidate in
                (
                    identity: candidate,
                    similarity: candidate.windowSignature.bundleIDSimilarity(to: currentFingerprint.windowSignature)
                )
            }
            .filter { $0.similarity >= JSONFileSpaceNameStore.fuzzyWindowThreshold }
            .sorted { lhs, rhs in
                if lhs.similarity != rhs.similarity {
                    return lhs.similarity > rhs.similarity
                }
                return lhs.identity.firstSeen < rhs.identity.firstSeen
            }

        guard let best = ranked.first else { return nil }
        if ranked.count > 1 {
            let runnerUp = ranked[1]
            guard best.similarity - runnerUp.similarity >= JSONFileSpaceNameStore.fuzzyWinnerMargin else {
                return nil
            }
        }
        return best.identity
    }

    private func save() {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let entries = names.map { Entry(identity: $0.key, name: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.identity.displayUUID == rhs.identity.displayUUID {
                        return (lhs.identity.ordinal ?? Int.max) < (rhs.identity.ordinal ?? Int.max)
                    }
                    return lhs.identity.displayUUID < rhs.identity.displayUUID
                }
            let data = try JSONEncoder.virtualOverlay.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save Space names: \(error)")
        }
    }

    private static func load(from fileURL: URL) -> [SpaceIdentity: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder.virtualOverlay.decode([Entry].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.identity, $0.name) })
    }

    private static func invalidatingSessionCGSIDs(_ names: [SpaceIdentity: String]) -> [SpaceIdentity: String] {
        names.reduce(into: [:]) { result, pair in
            result[pair.key.clearingCGSSpaceID()] = pair.value
        }
    }

    private static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("VirtualOverlay", isDirectory: true)
            .appendingPathComponent("spaces.json")
    }
}

private extension JSONEncoder {
    static var virtualOverlay: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var virtualOverlay: JSONDecoder {
        JSONDecoder()
    }
}
