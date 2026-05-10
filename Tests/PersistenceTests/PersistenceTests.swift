// PersistenceTests — verifies JSON store round-trips Space names and fuzzy identity matching.

import Foundation
import SpaceDetection
import XCTest
@testable import Persistence

final class PersistenceTests: XCTestCase {
    @MainActor
    func testRoundTripsSpaceIdentityNameThroughJSONStore() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let identity = identity(
            displayUUID: "display-a",
            windows: ["Xcode:VirtualOverlay", "Terminal:swift build"],
            ordinal: 2
        )
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("Writing", for: identity)

        let reloaded = JSONFileSpaceNameStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.name(for: identity), "Writing")
        XCTAssertEqual(reloaded.allKnown()[identity], "Writing")
    }

    @MainActor
    func testExactMatchReturnsStoredIdentity() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let stored = identity(displayUUID: "display-a", windows: ["Xcode:App", "Safari:Docs"], ordinal: 1)
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("Development", for: stored)

        XCTAssertEqual(store.match(currentFingerprint: stored), stored)
        XCTAssertEqual(store.name(for: stored), "Development")
    }

    @MainActor
    func testFuzzyMatchUpdatesSameDisplaySlightlyDifferentWindowSet() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let stored = identity(
            displayUUID: "display-a",
            windows: ["Xcode:App", "Safari:Docs", "Terminal:Tests", "Notes:Plan"],
            ordinal: 1,
            firstSeen: Date(timeIntervalSince1970: 10),
            frontmostAppBundleID: "com.apple.dt.Xcode"
        )
        let current = identity(
            displayUUID: "display-a",
            windows: ["Xcode:App", "Safari:Docs", "Terminal:Tests", "Notes:Plan", "Finder:Desktop"],
            ordinal: 3,
            firstSeen: Date(timeIntervalSince1970: 20),
            frontmostAppBundleID: "com.apple.dt.Xcode"
        )
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("Development", for: stored)

        let match = store.match(currentFingerprint: current)

        XCTAssertEqual(match?.displayUUID, current.displayUUID)
        XCTAssertEqual(match?.windowSignature, current.windowSignature)
        XCTAssertEqual(match?.ordinal, current.ordinal)
        XCTAssertEqual(match?.firstSeen, stored.firstSeen)
        XCTAssertEqual(store.name(for: current), "Development")
        XCTAssertNil(store.allKnown()[stored])
    }

    @MainActor
    func testSetNameThenMatchReturnsStoredName() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let stored = identity(displayUUID: "display-a", windows: ["Xcode:App", "Safari:Docs"], ordinal: 1)
        let current = identity(displayUUID: "display-a", windows: ["Xcode:App", "Safari:Docs"], ordinal: 1, firstSeen: Date(timeIntervalSince1970: 99))
        let store = JSONFileSpaceNameStore(fileURL: fileURL)

        store.setName("Production", for: stored)
        let matched = store.match(currentFingerprint: current)

        XCTAssertEqual(matched, stored)
        XCTAssertEqual(matched.flatMap { store.name(for: $0) }, "Production")
    }

    @MainActor
    func testDifferentDisplayDoesNotFuzzyMatch() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let stored = identity(displayUUID: "display-a", windows: ["Xcode:App", "Safari:Docs"], ordinal: 1, frontmostAppBundleID: "com.apple.dt.Xcode")
        let current = identity(displayUUID: "display-b", windows: ["Xcode:App", "Safari:Docs"], ordinal: 1, frontmostAppBundleID: "com.apple.dt.Xcode")
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("Development", for: stored)

        XCTAssertNil(store.match(currentFingerprint: current))
        XCTAssertNil(store.name(for: current))
    }

    @MainActor
    func testFuzzyMatchUsesFrontmostAppToChooseDistinctSpace() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let second = identity(displayUUID: "display-a", windows: ["Safari:Docs", "Terminal:Shell"], ordinal: 2, firstSeen: Date(timeIntervalSince1970: 20), frontmostAppBundleID: "com.apple.Safari")
        let third = identity(displayUUID: "display-a", windows: ["Safari:Docs", "Terminal:Shell"], ordinal: 3, firstSeen: Date(timeIntervalSince1970: 30), frontmostAppBundleID: "com.apple.Terminal")
        let currentThird = identity(
            displayUUID: "display-a",
            windows: ["Safari:Other Docs", "Terminal:Other Shell"],
            ordinal: 4,
            firstSeen: Date(timeIntervalSince1970: 50),
            frontmostAppBundleID: "com.apple.Terminal"
        )
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("second", for: second)
        store.setName("third", for: third)

        let match = store.match(currentFingerprint: currentThird)

        XCTAssertEqual(match?.firstSeen, third.firstSeen)
        XCTAssertEqual(store.name(for: currentThird), "third")
        XCTAssertNotEqual(match?.firstSeen, second.firstSeen)
    }

    @MainActor
    func testAmbiguousFuzzyMatchReturnsNil() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let candidateA = identity(displayUUID: "display-a", windows: ["Xcode:A", "Safari:A", "Terminal:A", "Notes:A"], ordinal: 1, frontmostAppBundleID: "com.apple.dt.Xcode")
        let candidateB = identity(displayUUID: "display-a", windows: ["Xcode:B", "Safari:B", "Terminal:B", "Finder:B"], ordinal: 2, frontmostAppBundleID: "com.apple.dt.Xcode")
        let current = identity(displayUUID: "display-a", windows: ["Xcode:Current", "Safari:Current", "Terminal:Current", "Notes:Current", "Finder:Current"], ordinal: 3, frontmostAppBundleID: "com.apple.dt.Xcode")
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("Candidate A", for: candidateA)
        store.setName("Candidate B", for: candidateB)

        XCTAssertNil(store.match(currentFingerprint: current))
        XCTAssertNil(store.name(for: current))
    }

    @MainActor
    func testCGSSpaceIDExactMatchWinsOverHeuristicSignals() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let first = identity(displayUUID: "display-a", windows: ["Xcode:First"], ordinal: 1, firstSeen: Date(timeIntervalSince1970: 10), frontmostAppBundleID: "com.apple.dt.Xcode", cgsSpaceID: 100)
        let second = identity(displayUUID: "display-a", windows: ["Safari:Second"], ordinal: 2, firstSeen: Date(timeIntervalSince1970: 20), frontmostAppBundleID: "com.apple.Safari", cgsSpaceID: 200)
        let current = identity(displayUUID: "display-a", windows: ["Safari:Second"], ordinal: 2, frontmostAppBundleID: "com.apple.Safari", cgsSpaceID: 100)
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("first", for: first)
        store.setName("second", for: second)

        let match = store.match(currentFingerprint: current)

        XCTAssertEqual(match?.cgsSpaceID, 100)
        XCTAssertEqual(match?.firstSeen, first.firstSeen)
        XCTAssertEqual(store.name(for: current), "first")
    }

    @MainActor
    func testNilCurrentCGSSpaceIDFallsBackToHeuristicMatch() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let stored = identity(displayUUID: "display-a", windows: ["Xcode:App", "Safari:Docs", "Terminal:Tests", "Notes:Plan"], ordinal: 1, firstSeen: Date(timeIntervalSince1970: 10), frontmostAppBundleID: "com.apple.dt.Xcode", cgsSpaceID: 100)
        let current = identity(displayUUID: "display-a", windows: ["Xcode:Other", "Safari:Other", "Terminal:Other", "Notes:Other", "Finder:Other"], ordinal: 2, frontmostAppBundleID: "com.apple.dt.Xcode", cgsSpaceID: nil)
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("Development", for: stored)

        let match = store.match(currentFingerprint: current)

        XCTAssertEqual(match?.firstSeen, stored.firstSeen)
        XCTAssertEqual(match?.cgsSpaceID, nil)
        XCTAssertEqual(store.name(for: current), "Development")
    }

    @MainActor
    func testReloadInvalidatesStaleCGSSpaceIDWithoutRebindingFreshID() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let stale = identity(displayUUID: "display-a", windows: ["Xcode:App", "Safari:Docs", "Terminal:Tests", "Notes:Plan"], ordinal: 1, firstSeen: Date(timeIntervalSince1970: 10), frontmostAppBundleID: "com.apple.dt.Xcode", cgsSpaceID: 100)
        let writer = JSONFileSpaceNameStore(fileURL: fileURL)
        writer.setName("Development", for: stale)

        let reloaded = JSONFileSpaceNameStore(fileURL: fileURL)
        XCTAssertTrue(reloaded.allKnown().keys.allSatisfy { $0.cgsSpaceID == nil })

        let current = identity(displayUUID: "display-a", windows: ["Xcode:Other", "Safari:Other", "Terminal:Other", "Notes:Other", "Finder:Other"], ordinal: 2, frontmostAppBundleID: "com.apple.dt.Xcode", cgsSpaceID: 200)

        XCTAssertNil(reloaded.match(currentFingerprint: current))
        XCTAssertNil(reloaded.name(for: current))
        XCTAssertFalse(reloaded.allKnown().keys.contains { $0.cgsSpaceID == 200 })
    }

    @MainActor
    func testOldHeuristicOnlyEntryDoesNotBindToFreshCGSIdentity() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let oldHeuristicOnly = identity(displayUUID: "display-a", windows: ["Safari:Docs", "Terminal:Shell"], ordinal: 3, firstSeen: Date(timeIntervalSince1970: 30), frontmostAppBundleID: "com.apple.Safari", cgsSpaceID: nil)
        let current = identity(displayUUID: "display-a", windows: ["Safari:Docs", "Terminal:Shell"], ordinal: 3, frontmostAppBundleID: "com.apple.Safari", cgsSpaceID: 200)
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        store.setName("third", for: oldHeuristicOnly)

        XCTAssertNil(store.match(currentFingerprint: current))
        XCTAssertNil(store.name(for: current))
        XCTAssertEqual(store.allKnown()[oldHeuristicOnly], "third")
        XCTAssertFalse(store.allKnown().keys.contains { $0.cgsSpaceID == 200 })
    }

    @MainActor
    func testRenameCurrentCGSIdentityImmediatelyResolvesStoredName() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let current = identity(displayUUID: "display-a", windows: ["Safari:Docs"], ordinal: 2, frontmostAppBundleID: "com.apple.Safari", cgsSpaceID: 200)
        let store = JSONFileSpaceNameStore(fileURL: fileURL)

        XCTAssertNil(store.name(for: current))
        store.setName("second", for: current)

        XCTAssertEqual(store.allKnown()[current], "second")
        XCTAssertEqual(store.name(for: current), "second")
    }

    private func uniqueStoreURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("PersistenceTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("spaces.json")
    }

    private func identity(
        displayUUID: String,
        windows: [String],
        ordinal: Int?,
        firstSeen: Date = Date(timeIntervalSince1970: 0),
        frontmostAppBundleID: String? = nil,
        windowCount: Int? = nil,
        windowGeometrySignature: [String] = [],
        cgsSpaceID: UInt64? = nil
    ) -> SpaceIdentity {
        SpaceIdentity(
            displayUUID: displayUUID,
            windowSignature: WindowSignature(entries: windows),
            ordinal: ordinal,
            firstSeen: firstSeen,
            frontmostAppBundleID: frontmostAppBundleID,
            windowCount: windowCount ?? windows.count,
            windowGeometrySignature: windowGeometrySignature,
            cgsSpaceID: cgsSpaceID
        )
    }
}
