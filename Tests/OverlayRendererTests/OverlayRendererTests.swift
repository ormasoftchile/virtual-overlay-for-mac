// OverlayRendererTests — smoke tests for the renderer module boundary.

import Persistence
import XCTest

@testable import OverlayRenderer

final class OverlayRendererTests: XCTestCase {
  func testWatermarkViewCanBeConstructed() {
    _ = WatermarkView(text: "TEST")
    XCTAssertTrue(true)
  }

  func testWatermarkViewCanBeConstructedWithEveryPosition() {
    let positions: [WatermarkPosition] = [
      .lowerRight, .lowerLeft, .upperRight, .upperLeft, .center,
    ]

    for position in positions {
      _ = WatermarkView(text: "TEST", position: position)
    }

    XCTAssertEqual(positions.count, 5)
  }

  @MainActor
  func testTextSourceUpdatesOverlayWithinOneMainActorTick() async {
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let controller = OverlayController(textSource: .stream(stream))
    await Task.yield()

    continuation.yield("LAB")
    for _ in 0..<10 where controller.currentText != "LAB" {
      await Task.yield()
    }

    XCTAssertEqual(controller.currentText, "LAB")
    continuation.finish()
  }

  func testDiagonalOppositePositions() {
    XCTAssertEqual(WatermarkPosition.lowerRight.diagonalOpposite, .upperLeft)
    XCTAssertEqual(WatermarkPosition.lowerLeft.diagonalOpposite, .upperRight)
    XCTAssertEqual(WatermarkPosition.upperRight.diagonalOpposite, .lowerLeft)
    XCTAssertEqual(WatermarkPosition.upperLeft.diagonalOpposite, .lowerRight)
    XCTAssertEqual(WatermarkPosition.center.diagonalOpposite, .center)
  }

  func testHoverFleeStateSuspendsWhileOptionIsHeld() {
    let watermarkBounds = CGRect(x: 100, y: 100, width: 200, height: 80)
    let insideCursor = CGPoint(x: 150, y: 120)

    var suspendedState = WatermarkHoverFleeState(configuredPosition: .lowerRight)
    XCTAssertEqual(
      suspendedState.cursorMoved(
        to: insideCursor, currentWatermarkBounds: watermarkBounds, isOptionHeld: true),
      .lowerRight)
    XCTAssertEqual(suspendedState.currentPosition, .lowerRight)

    var activeState = WatermarkHoverFleeState(configuredPosition: .lowerRight)
    XCTAssertEqual(
      activeState.cursorMoved(
        to: insideCursor, currentWatermarkBounds: watermarkBounds, isOptionHeld: false),
      .upperLeft)
    XCTAssertEqual(activeState.currentPosition, .upperLeft)
  }

  @MainActor
  func testPreferencesViewModelUpdatesAppearance() {
    let appearance = WatermarkAppearance()
    let viewModel = WatermarkPreferencesViewModel(appearance: appearance)
    let swatch = viewModel.swatches.first!

    viewModel.setOpacity(0.37)
    viewModel.chooseSwatch(swatch)
    viewModel.setFontSize(500)
    viewModel.setFontFamily(.sfMono)
    viewModel.setPosition(.upperLeft)

    XCTAssertEqual(appearance.color, swatch.color)
    XCTAssertEqual(appearance.opacity, 0.37, accuracy: 0.0001)
    XCTAssertEqual(appearance.fontSize, 400)
    XCTAssertEqual(appearance.fontFamily, .sfMono)
    XCTAssertEqual(appearance.position, .upperLeft)
    XCTAssertEqual(viewModel.opacityLabel, "37%")
    XCTAssertEqual(viewModel.fontSizeLabel, "400 pt")
    XCTAssertEqual(viewModel.swatches.count, 6)
    XCTAssertTrue(viewModel.swatches.allSatisfy { $0.color.alpha == 1.0 })
  }

  @MainActor
  func testPreferencesViewModelAppliesCompleteSnapshotDuringSliderPreview() {
    let initialPreferences = WatermarkPreferences(
      color: .defaultWatermark,
      opacity: 0.10,
      fontSize: 240,
      fontFamily: .helveticaNeue,
      position: .upperRight
    )
    let appearance = WatermarkAppearance(preferences: initialPreferences)
    let viewModel = WatermarkPreferencesViewModel(appearance: appearance)

    var draft = appearance.preferences
    draft.opacity = 0.42
    draft.fontSize = 180
    let applied = viewModel.apply(draft)

    XCTAssertEqual(applied.position, .upperRight)
    XCTAssertEqual(appearance.preferences.position, .upperRight)
    XCTAssertEqual(appearance.preferences.opacity, 0.42, accuracy: 0.0001)
    XCTAssertEqual(appearance.preferences.fontSize, 180)
    XCTAssertEqual(appearance.preferences.fontFamily, .helveticaNeue)
  }

  func testHoverFleeStateTogglesOnlyWhenCursorIsInsideCurrentWatermark() {
    let cases: [(configured: WatermarkPosition, opposite: WatermarkPosition)] = [
      (.lowerRight, .upperLeft),
      (.lowerLeft, .upperRight),
      (.upperRight, .lowerLeft),
      (.upperLeft, .lowerRight),
      (.center, .center),
    ]
    let watermarkBounds = CGRect(x: 100, y: 100, width: 200, height: 80)
    let outsideCursor = CGPoint(x: 20, y: 20)
    let insideCursor = CGPoint(x: 150, y: 120)

    for testCase in cases {
      var state = WatermarkHoverFleeState(configuredPosition: testCase.configured)

      XCTAssertEqual(state.currentPosition, testCase.configured)
      XCTAssertEqual(
        state.cursorMoved(to: outsideCursor, currentWatermarkBounds: watermarkBounds),
        testCase.configured)
      XCTAssertEqual(
        state.cursorMoved(to: insideCursor, currentWatermarkBounds: watermarkBounds),
        testCase.opposite)
      XCTAssertEqual(
        state.cursorMoved(to: outsideCursor, currentWatermarkBounds: watermarkBounds),
        testCase.opposite)
      XCTAssertEqual(
        state.cursorMoved(to: insideCursor, currentWatermarkBounds: watermarkBounds),
        testCase.configured)
    }
  }

}
