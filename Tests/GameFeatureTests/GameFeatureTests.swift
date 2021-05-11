import ClientModels
import Combine
import CombineHelpers
import ComposableArchitecture
import GameOverFeature
import Gen
import Overture
import Prelude
import ServerRouter
import SettingsFeature
import SharedModels
import XCTest

@testable import GameFeature

class GameFeatureTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testRemoveCubeMove() {
    let environment = update(GameEnvironment.failing) {
      $0.audioPlayer.play = { _ in .none }
      $0.fileClient.load = { _ in .none }
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: GameFeatureState(
        game: GameState(
          cubes: update(.mock) {
            $0.0.0.0 = .init(
              left: .init(letter: "A", side: .left),
              right: .init(letter: "B", side: .right),
              top: .init(letter: "C", side: .top)
            )
            $0.0.0.1 = .init(
              left: .init(letter: "A", side: .left),
              right: .init(letter: "B", side: .right),
              top: .init(letter: "C", side: .top)
            )
          },
          gameContext: .solo,
          gameCurrentTime: .mock,
          gameMode: .timed,
          gameStartTime: .mock,
          moves: [],
          secondsPlayed: 0
        ),
        settings: SettingsState()
      ),
      reducer: gameFeatureReducer,
      environment: environment
    )

    store.send(.game(.doubleTap(index: .zero)))
    store.receive(.game(.confirmRemoveCube(.zero))) {
      $0.game?.cubes.0.0.0.wasRemoved = true
      $0.game?.moves = [
        .init(
          playedAt: environment.$mainQueue.now,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        )
      ]
    }
  }

  func testDoubleTapRemoveCube_MultipleSelectedFaces() {
    let environment = update(GameEnvironment.failing) {
      $0.fileClient.load = { _ in .none }
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.mainQueue = self.mainQueue.eraseToAnyScheduler()
    }

    let store = TestStore(
      initialState: GameFeatureState(
        game: GameState(
          cubes: update(.mock),
          gameContext: .solo,
          gameCurrentTime: .mock,
          gameMode: .timed,
          gameStartTime: .mock,
          moves: [],
          secondsPlayed: 0,
          selectedWord: [
            .init(index: .init(x: .two, y: .two, z: .two), side: .left),
            .init(index: .init(x: .two, y: .two, z: .two), side: .right),
          ]
        ),
        settings: SettingsState()
      ),
      reducer: gameFeatureReducer,
      environment: environment
    )

    store.send(.game(.doubleTap(index: .zero)))
  }

  func testIsYourTurn() {
    var game = GameState(
      cubes: .mock,
      gameContext: .turnBased(
        .init(
          localPlayer: .mock,
          match: update(.inProgress) {
            $0.participants = [.local, .remote]
          },
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
      ),
      gameCurrentTime: .mock,
      gameMode: .unlimited,
      gameStartTime: .mock,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: 1,
          reactions: nil,
          score: 42,
          type: .playedWord([.init(index: .zero, side: .left)])
        )
      ]
    )
    XCTAssert(game.isYourTurn)

    game.moves.append(
      .init(
        playedAt: .mock,
        playerIndex: game.turnBasedContext?.localPlayerIndex,
        reactions: nil,
        score: 42,
        type: .playedWord([.init(index: .zero, side: .left)])
      )
    )
    XCTAssert(!game.isYourTurn)
  }

  func testIsYourTurn_CubeRemoval() {
    var game = GameState(
      cubes: .mock,
      gameContext: .turnBased(
        .init(
          localPlayer: .mock,
          match: update(.inProgress) {
            $0.participants = [.local, .remote]
          },
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
      ),
      gameCurrentTime: .mock,
      gameMode: .unlimited,
      gameStartTime: .mock,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: 1,
          reactions: nil,
          score: 42,
          type: .playedWord([.init(index: .zero, side: .left)])
        )
      ]
    )
    XCTAssert(game.isYourTurn)

    game.moves.append(
      .init(
        playedAt: .mock,
        playerIndex: 0,
        reactions: nil,
        score: 0,
        type: .removedCube(.zero)
      )
    )
    XCTAssert(game.isYourTurn)

    game.moves.append(
      .init(
        playedAt: .mock,
        playerIndex: 0,
        reactions: nil,
        score: 42,
        type: .playedWord([.init(index: .zero, side: .left)])
      )
    )
    XCTAssert(!game.isYourTurn)
  }

  func testIsYourTurn_RemoteTurn() {
    let game = GameState(
      cubes: .mock,
      gameContext: .turnBased(
        .init(
          localPlayer: .mock,
          match: update(.inProgress) {
            $0.currentParticipant = .remote
            $0.participants = [.local, .remote]
          },
          metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
        )
      ),
      gameCurrentTime: .mock,
      gameMode: .unlimited,
      gameStartTime: .mock,
      moves: [
        .init(
          playedAt: .mock,
          playerIndex: 0,
          reactions: nil,
          score: 42,
          type: .playedWord([.init(index: .zero, side: .left)])
        )
      ]
    )
    XCTAssert(!game.isYourTurn)
  }

  func testGameStateInProgressGameRoundtrip() {
    for _ in 1...500 {
      let game = Gen.gameState.run()
      let roundTrippedGame = GameState(
        inProgressGame: InProgressGame(gameState: game)
      )
      XCTAssertEqual(
        game,
        roundTrippedGame
      )
    }
  }
}
