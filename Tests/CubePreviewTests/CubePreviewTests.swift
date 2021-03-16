import ComposableArchitecture
import CubeCore
import SharedModels
import TestHelpers
import XCTest

@testable import CubePreview

class CubePreviewTests: XCTestCase {
  func testBasics() {
    let store = TestStore(
      initialState: CubePreviewState(
        preview: .game(
          .init(
            cubes: .mock,
            currentMoveIndex: .start,
            moves: moves
          )
        )
      ),
      reducer: cubePreviewReducer,
      environment: CubePreviewEnvironment()
    )
    .scope(
      state: { state -> CubeSceneView.ViewState? in
        switch state.preview {
        case let .game(game):
          return CubeSceneView.ViewState(game: game)
        case .words:
          fatalError()
        }
      }
    )

    store.send(.game(.nextButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.two][.two][.two].isInPlay = false
      }
    }
    store.send(.game(.nextButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.two][.one][.two].isInPlay = false
      }
    }
    store.send(.game(.nextButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.one][.two][.two].isInPlay = false
      }
    }
    store.send(.game(.nextButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.two][.two][.one].isInPlay = false
      }
    }
    store.send(.game(.nextButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.init(x: .one, y: .zero, z: .two)].left.status = .selected
        $0.cubes[.init(x: .zero, y: .zero, z: .two)].left.status = .selected
        $0.cubes[.init(x: .one, y: .one, z: .two)].left.status = .selected
        $0.cubes[.init(x: .one, y: .two, z: .two)].left.status = .selected
        $0.cubes[.init(x: .zero, y: .two, z: .two)].left.status = .selected
      }
    }
    store.send(.game(.previousButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.init(x: .one, y: .zero, z: .two)].left.status = .deselected
        $0.cubes[.init(x: .zero, y: .zero, z: .two)].left.status = .deselected
        $0.cubes[.init(x: .one, y: .one, z: .two)].left.status = .deselected
        $0.cubes[.init(x: .one, y: .two, z: .two)].left.status = .deselected
        $0.cubes[.init(x: .zero, y: .two, z: .two)].left.status = .deselected
      }
    }
    store.send(.game(.previousButtonTapped)) {
      $0 = try XCTUnwrap($0) {
        $0.cubes[.two][.two][.one].isInPlay = true
      }
    }
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
