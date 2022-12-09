import ClientModels
import Combine
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

@MainActor
class GameFeatureTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testRemoveCubeMove() async {
    let store = TestStore(
      initialState: GameFeature.State(
        game: Game.State(
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
        settings: Settings.State()
      ),
      reducer: GameFeature()
    )

    store.dependencies.audioPlayer.play = { _ in }
//    store.dependencies.persistenceClient.load = { @Sendable _ in try await Task.never() }
    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(.game(.doubleTap(index: .zero)))
    await store.receive(.game(.confirmRemoveCube(.zero))) {
      $0.game?.cubes.0.0.0.wasRemoved = true
      $0.game?.moves = [
        .init(
          playedAt: self.mainRunLoop.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 0,
          type: .removedCube(.zero)
        )
      ]
    }
    await store.finish()
  }

  func testDoubleTapRemoveCube_MultipleSelectedFaces() async {
    let store = TestStore(
      initialState: GameFeature.State(
        game: Game.State(
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
        settings: Settings.State()
      ),
      reducer: GameFeature()
    )

//    store.dependencies.persistenceClient.load = { @Sendable _ in try await Task.never() }
    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(.game(.doubleTap(index: .zero)))
  }

  func testIsYourTurn() {
    var game = Game.State(
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
    var game = Game.State(
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
    let game = Game.State(
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
      let roundTrippedGame = Game.State(
        inProgressGame: InProgressGame(gameState: game)
      )
      XCTAssertNoDifference(
        game,
        roundTrippedGame
      )
    }
  }
}
