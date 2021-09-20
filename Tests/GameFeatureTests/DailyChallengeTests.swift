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

class DailyChallengeTests: XCTestCase {
  func testLeaveTimedDailyChallenge() {
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

    var didSave = false

    let environment = update(GameEnvironment.failing) {
      $0.audioPlayer.play = { _ in .none }
      $0.audioPlayer.stop = { _ in .none }
      $0.database.saveGame = { _ in
        didSave = true
        return .none
      }
      $0.fileClient.load = { _ in .none }
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

    store.send(.game(.endGameButtonTapped)) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: CompletedGame(gameState: $0),
          isDemo: false
        )
      }
    }

    XCTAssertNoDifference(didSave, true)
  }

  func testLeaveUnlimitedDailyChallenge() {
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

    var didSave = false
    let environment = update(GameEnvironment.failing) {
      $0.audioPlayer.play = { _ in .none }
      $0.audioPlayer.stop = { _ in .none }
      $0.database.saveGame = { _ in
        didSave = true
        return .none
      }
      $0.fileClient.load = { _ in .none }
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

    store.send(.game(.endGameButtonTapped)) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: CompletedGame(gameState: $0),
          isDemo: false
        )
      }
    }

    XCTAssertNoDifference(didSave, true)
  }
}
