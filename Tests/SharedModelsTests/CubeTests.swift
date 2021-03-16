import SharedModels
import TestHelpers
import XCTest

class CubeTest: XCTestCase {
  func testIsPlayer_TopMiddleAndFrontMostCornerRemoved() {
    var cubes = Puzzle.mock
    cubes.2.2.2.wasRemoved = true
    cubes.1.2.1.wasRemoved = true

    XCTAssertEqual(
      cubes.isPlayable(side: .top, index: .init(x: .one, y: .one, z: .one)),
      false
    )
  }

  func testIsPlayer_MiddleLeftRemoved() {
    var cubes = Puzzle.mock
    cubes.1.1.2.wasRemoved = true

    XCTAssertEqual(
      cubes.isPlayable(side: .left, index: .init(x: .one, y: .one, z: .one)),
      false
    )
  }

  func testIsPlayer_MiddleRightRemoved() {
    var cubes = Puzzle.mock
    cubes.2.1.1.wasRemoved = true

    XCTAssertEqual(
      cubes.isPlayable(side: .right, index: .init(x: .one, y: .one, z: .one)),
      false
    )
  }

  func testIsPlayer_MiddleLeftAndBelowMiddleLeftRemoved() {
    var cubes = Puzzle.mock
    cubes.1.1.2.wasRemoved = true
    cubes.1.0.2.wasRemoved = true

    XCTAssertEqual(
      cubes.isPlayable(side: .left, index: .init(x: .one, y: .zero, z: .one)),
      false
    )
  }

  func testIsPlayable() {
    var cubes = Puzzle.mock

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.2.2.2.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.1.2.2.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.2.2.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.2.1.2.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.2.2.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.1.2.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.1.1.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.2.2.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.1.1.2.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.2.1.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.1.0.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.0.0.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), true)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), false)

    cubes.1.0.0.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), true)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), true)

    cubes.1.1.0.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), true)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), true)

    cubes.0.1.1.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), false)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), true)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), true)

    cubes.0.1.0.wasRemoved = true

    XCTAssertEqual(cubes.isPlayable(side: .top, index: .zero), true)
    XCTAssertEqual(cubes.isPlayable(side: .left, index: .zero), true)
    XCTAssertEqual(cubes.isPlayable(side: .right, index: .zero), true)
  }
}
