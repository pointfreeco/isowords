import Combine
import ComposableArchitecture
import GameOverFeature
import Overture
import Prelude
import ServerRouter
import SharedModels
import TestHelpers
import XCTest

@testable import GameFeature

@MainActor
class DailyChallengeTests: XCTestCase {
  func testLeaveTimedDailyChallenge() async {
    let move = Move(
      playedAt: .mock,
      playerIndex: nil,
      reactions: nil,
      score: 10,
      type: .playedWord([
        .init(index: .zero, side: .left),
        .init(index: .zero, side: .right),
        .init(index: .zero, side: .top),
      ])
    )

    let didSave = ActorIsolated(false)

    let environment = update(GameEnvironment.unimplemented) {
      $0.audioPlayer.stop = { _ in }
      $0.database.saveGame = { _ in await didSave.setValue(true) }
      $0.fileClient.load = { @Sendable _ in try await Task.never() }
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.mainQueue = .immediate
    }

    let store = TestStore(
      initialState: GameFeatureState(
        game: GameState(
          cubes: .mock,
          gameContext: .dailyChallenge(.init(rawValue: .deadbeef)),
          gameCurrentTime: .mock,
          gameMode: .timed,
          gameStartTime: .mock,
          moves: [move]
        ),
        settings: .init()
      ),
      reducer: gameFeatureReducer,
      environment: environment
    )

    await store.send(.game(.endGameButtonTapped)) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: CompletedGame(gameState: $0),
          isDemo: false
        )
      }
    }

    await didSave.withValue { XCTAssert($0) }
  }

  func testLeaveUnlimitedDailyChallenge() async {
    let move = Move(
      playedAt: .mock,
      playerIndex: nil,
      reactions: nil,
      score: 10,
      type: .playedWord([
        .init(index: .zero, side: .left),
        .init(index: .zero, side: .right),
        .init(index: .zero, side: .top),
      ])
    )

    let didSave = ActorIsolated(false)

    let environment = update(GameEnvironment.unimplemented) {
      $0.audioPlayer.stop = { _ in }
      $0.database.saveGame = { _ in await didSave.setValue(true) }
      $0.fileClient.load = { @Sendable _ in try await Task.never() }
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.mainQueue = .immediate
    }

    let store = TestStore(
      initialState: GameFeatureState(
        game: GameState(
          cubes: .mock,
          gameContext: .dailyChallenge(.init(rawValue: .deadbeef)),
          gameCurrentTime: .mock,
          gameMode: .unlimited,
          gameStartTime: .mock,
          moves: [move]
        ),
        settings: .init()
      ),
      reducer: gameFeatureReducer,
      environment: environment
    )

    await store.send(.game(.endGameButtonTapped)) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: CompletedGame(gameState: $0),
          isDemo: false
        )
      }
    }
    .finish()

    await didSave.withValue { XCTAssert($0) }
  }
}
