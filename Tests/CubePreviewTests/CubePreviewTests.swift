import ComposableArchitecture
import CubeCore
import SharedModels
import TestHelpers
import XCTest

@testable import CubePreview

class CubePreviewTests: XCTestCase {
  func testBasics() {
  }
}

let moves: Moves = [
  .init(
    playedAt: Date(),
    playerIndex: nil,
    reactions: nil,
    score: 0,
    type: .removedCube(.init(x: .two, y: .two, z: .two))
  ),
  .init(
    playedAt: Date(),
    playerIndex: nil,
    reactions: nil,
    score: 0,
    type: .removedCube(.init(x: .two, y: .one, z: .two))
  ),
  .init(
    playedAt: Date(),
    playerIndex: nil,
    reactions: nil,
    score: 0,
    type: .removedCube(.init(x: .one, y: .two, z: .two))
  ),
  .init(
    playedAt: Date(),
    playerIndex: nil,
    reactions: nil,
    score: 0,
    type: .removedCube(.init(x: .two, y: .two, z: .one))
  ),
  .init(
    playedAt: Date(),
    playerIndex: nil,
    reactions: nil,
    score: 100,
    type: .playedWord([
      .init(index: .init(x: .one, y: .zero, z: .two), side: .left),
      .init(index: .init(x: .zero, y: .zero, z: .two), side: .left),
      .init(index: .init(x: .one, y: .one, z: .two), side: .left),
      .init(index: .init(x: .one, y: .two, z: .two), side: .left),
      .init(index: .init(x: .zero, y: .two, z: .two), side: .left),
    ])
  ),
  .init(
    playedAt: Date(),
    playerIndex: nil,
    reactions: nil,
    score: 100,
    type: .playedWord([
      .init(index: .init(x: .two, y: .zero, z: .two), side: .left),
      .init(index: .init(x: .two, y: .zero, z: .two), side: .top),
      .init(index: .init(x: .two, y: .one, z: .one), side: .left),
      .init(index: .init(x: .one, y: .two, z: .one), side: .left),
      .init(index: .init(x: .zero, y: .two, z: .one), side: .top),
    ])
  ),
]
