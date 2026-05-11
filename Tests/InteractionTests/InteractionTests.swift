// InteractionTests — smoke tests for the rename request source surface.

import Foundation
import OverlayRenderer
import Persistence
import SpaceDetection
import XCTest
@testable import Interaction

final class InteractionTests: XCTestCase {
    @MainActor
    func testStubRenameRequestSourceStartsAndStops() {
        let source = StubRenameRequestSource()
        source.start()
        source.stop()
        XCTAssertTrue(true)
    }

    func testRenameStateMachineSavesAndCancels() {
        var machine = RenameStateMachine()
        XCTAssertEqual(machine.state, .idle)

        machine.begin(currentName: "UNNAMED")
        XCTAssertEqual(machine.state, .editing(original: "UNNAMED", draft: "UNNAMED"))

        machine.updateDraft("PRODUCTION")
        XCTAssertEqual(machine.save(), "PRODUCTION")
        XCTAssertEqual(machine.state, .idle)

        machine.begin(currentName: "DEMO")
        machine.updateDraft("SHOULD NOT SAVE")
        machine.cancel()
        XCTAssertEqual(machine.state, .idle)
        XCTAssertNil(machine.save())
    }

    @MainActor
    func testRenameCommitWritesFreshSubmitIdentity() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let staleAtEditStart = identity(cgsSpaceID: 300)
        let currentAtSubmit = identity(cgsSpaceID: 200)
        var activeIdentity = staleAtEditStart
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        let controller = OptionClickRenameController(
            overlayController: OverlayController(),
            nameStore: store,
            currentIdentity: { activeIdentity },
            refreshDisplayName: {}
        )

        controller.beginRenameForTesting(currentName: "UNNAMED")
        activeIdentity = currentAtSubmit
        controller.commitRename("second")

        XCTAssertNil(store.allKnown()[staleAtEditStart])
        XCTAssertEqual(store.allKnown()[currentAtSubmit], "second")
        XCTAssertEqual(store.name(for: currentAtSubmit), "second")
    }

    @MainActor
    func testRenameCommitUsesClickedScreenIdentity() {
        let fileURL = uniqueStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let mainIdentity = identity(displayUUID: "main-display", cgsSpaceID: 100)
        let topIdentity = identity(displayUUID: "top-display", cgsSpaceID: 100)
        let store = JSONFileSpaceNameStore(fileURL: fileURL)
        let controller = OptionClickRenameController(
            overlayController: OverlayController(),
            nameStore: store,
            currentIdentityForScreen: { screenID in
                switch screenID {
                case 222: return topIdentity
                default: return mainIdentity
                }
            },
            refreshDisplayName: {}
        )

        controller.beginRenameForTesting(currentName: "UNNAMED", screenID: 222)
        controller.commitRename("top")

        XCTAssertNil(store.allKnown()[mainIdentity])
        XCTAssertEqual(store.allKnown()[topIdentity], "top")
    }

    private func uniqueStoreURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("InteractionTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("spaces.json")
    }

    private func identity(displayUUID: String = "display-a", cgsSpaceID: UInt64) -> SpaceIdentity {
        SpaceIdentity(
            displayUUID: displayUUID,
            windowSignature: WindowSignature(entries: ["Safari:Docs"]),
            ordinal: 2,
            firstSeen: Date(timeIntervalSince1970: 0),
            frontmostAppBundleID: "com.apple.Safari",
            windowCount: 1,
            cgsSpaceID: cgsSpaceID
        )
    }
}
