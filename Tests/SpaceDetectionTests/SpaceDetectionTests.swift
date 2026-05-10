// SpaceDetectionTests — verifies public notification events flow through the detector.

import CoreGraphics
import XCTest
@testable import SpaceDetection

final class SpaceDetectionTests: XCTestCase {
    @MainActor
    func testNotificationProducesSpaceChangeEventWithinOneMainActorTick() async {
        let center = NotificationCenter()
        let name = Notification.Name("SpaceDetectionTests.changed")
        let identity = SpaceIdentity(
            displayUUID: "display-test",
            windowSignature: WindowSignature(entries: ["Xcode:VirtualOverlay"]),
            ordinal: 1,
            firstSeen: Date(timeIntervalSince1970: 0)
        )
        let snapshot = SpaceSnapshot(identity: identity, displayID: CGDirectDisplayID(1), confidence: .low, timestamp: Date())
        let detector = NSWorkspaceSpaceDetector(notificationCenter: center, notificationName: name) { [snapshot] in
            [snapshot]
        }

        var iterator = detector.changes.makeAsyncIterator()
        detector.startObserving()
        let eventTask = Task { await iterator.next() }

        center.post(name: name, object: nil)
        await Task.yield()
        let event = await eventTask.value

        XCTAssertEqual(event?.snapshots.first?.identity, identity)
        detector.stopObserving()
    }

    func testSpaceFingerprinterProducesStableWindowSignatureFromSnapshot() {
        let windows = [
            SpaceWindowSnapshot(bundleID: "com.apple.Safari", title: "Docs", layer: 0, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
            SpaceWindowSnapshot(bundleID: "com.apple.Terminal", title: "Build", layer: 0, bounds: CGRect(x: 10, y: 10, width: 50, height: 50)),
            SpaceWindowSnapshot(bundleID: "com.apple.dock", title: "Dock", layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 10))
        ]
        let reversed = Array(windows.reversed())

        let signature = SpaceFingerprinter.windowSignature(from: windows)
        let reversedSignature = SpaceFingerprinter.windowSignature(from: reversed)

        XCTAssertEqual(signature.entries, ["com.apple.Safari:Docs", "com.apple.Terminal:Build"])
        XCTAssertEqual(signature, reversedSignature)
        XCTAssertEqual(signature.stableHash, reversedSignature.stableHash)
        XCTAssertEqual(signature.stableHash.count, 16)
    }

    func testSpaceFingerprinterProducesWindowGeometryHashes() {
        let windows = [
            SpaceWindowSnapshot(bundleID: "com.apple.Safari", title: "Docs", layer: 0, bounds: CGRect(x: 0.2, y: 0.3, width: 100.4, height: 100.5)),
            SpaceWindowSnapshot(bundleID: "com.apple.Terminal", title: "Build", layer: 0, bounds: CGRect(x: 10, y: 10, width: 50, height: 50)),
            SpaceWindowSnapshot(bundleID: "com.apple.dock", title: "Dock", layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 10))
        ]

        let geometry = SpaceFingerprinter.windowGeometrySignature(from: windows)

        XCTAssertEqual(geometry.count, 2)
        XCTAssertTrue(geometry.allSatisfy { $0.count == 16 })
        XCTAssertEqual(geometry, geometry.sorted())
    }

    func testCGSResolverPrefersPerDisplayManagedSpaceLookup() {
        MockCGS.reset()
        MockCGS.managedSpaceByDisplayUUID = ["display-a": 4242]
        let symbols = CGSPrivateSymbols(
            mainConnectionID: MockCGS.mainConnectionID,
            managedDisplayGetCurrentSpace: MockCGS.managedDisplayGetCurrentSpace,
            getActiveSpace: MockCGS.getActiveSpace
        )

        let id = currentCGSSpaceID(forDisplayUUID: "display-a", symbols: symbols)

        XCTAssertEqual(id, 4242)
        XCTAssertEqual(MockCGS.managedDisplayUUIDs, ["display-a"])
        XCTAssertEqual(MockCGS.activeSpaceCallCount, 0)
    }

    func testCGSResolverFallsBackToGlobalActiveSpaceWhenPerDisplaySymbolMissing() {
        MockCGS.reset()
        MockCGS.activeSpaceID = 99
        let symbols = CGSPrivateSymbols(
            mainConnectionID: MockCGS.mainConnectionID,
            managedDisplayGetCurrentSpace: nil,
            getActiveSpace: MockCGS.getActiveSpace
        )

        let id = currentCGSSpaceID(forDisplayUUID: "display-a", symbols: symbols)

        XCTAssertEqual(id, 99)
        XCTAssertEqual(MockCGS.managedDisplayUUIDs, [])
        XCTAssertEqual(MockCGS.activeSpaceCallCount, 1)
    }
}

private enum MockCGS {
    static var managedSpaceByDisplayUUID: [String: CGSSpaceID] = [:]
    static var managedDisplayUUIDs: [String] = []
    static var activeSpaceID: CGSSpaceID = 0
    static var activeSpaceCallCount = 0

    static func reset() {
        managedSpaceByDisplayUUID = [:]
        managedDisplayUUIDs = []
        activeSpaceID = 0
        activeSpaceCallCount = 0
    }

    static func mainConnectionID() -> CGSConnectionID {
        7
    }

    static func managedDisplayGetCurrentSpace(_ connection: CGSConnectionID, _ displayUUID: CFString) -> CGSSpaceID {
        XCTAssertEqual(connection, 7)
        let uuid = displayUUID as String
        managedDisplayUUIDs.append(uuid)
        return managedSpaceByDisplayUUID[uuid] ?? 0
    }

    static func getActiveSpace(_ connection: CGSConnectionID) -> CGSSpaceID {
        XCTAssertEqual(connection, 7)
        activeSpaceCallCount += 1
        return activeSpaceID
    }
}
