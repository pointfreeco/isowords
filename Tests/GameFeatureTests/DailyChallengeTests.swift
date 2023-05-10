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

    let store = TestStore(
      initialState: GameFeature.State(
        game: update(
          Game.State(
            cubes: .mock,
            gameContext: .dailyChallenge(.init(rawValue: .deadbeef)),
            gameCurrentTime: .mock,
            gameMode: .timed,
            gameStartTime: .mock,
            moves: [move]
          )
        ) {
          $0.destination = .bottomMenu(.gameMenu(state: $0))
        },
        settings: .init()
      ),
      reducer: GameFeature()
    )

    store.dependencies.audioPlayer.stop = { _ in }
    store.dependencies.database.saveGame = { _ in await didSave.setValue(true) }
    store.dependencies.fileClient.load = { @Sendable _ in try await Task.never() }
    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.mainQueue = .immediate

    await store.send(.game(.destination(.presented(.bottomMenu(.endGameButtonTapped))))) {
      try XCTUnwrap(&$0.game) {
        $0.destination = .gameOver(
          GameOver.State(
            completedGame: CompletedGame(gameState: $0),
            isDemo: false
          )
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

    let store = TestStore(
      initialState: GameFeature.State(
        game: update(
          Game.State(
            cubes: .mock,
            gameContext: .dailyChallenge(.init(rawValue: .deadbeef)),
            gameCurrentTime: .mock,
            gameMode: .unlimited,
            gameStartTime: .mock,
            moves: [move]
          )
        ) {
          $0.destination = .bottomMenu(.gameMenu(state: $0))
        },
        settings: .init()
      ),
      reducer: GameFeature()
    )

    store.dependencies.audioPlayer.stop = { _ in }
    store.dependencies.database.saveGame = { _ in await didSave.setValue(true) }
    store.dependencies.fileClient.load = { @Sendable _ in try await Task.never() }
    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.mainQueue = .immediate

    await store.send(.game(.destination(.presented(.bottomMenu(.endGameButtonTapped))))) {
      try XCTUnwrap(&$0.game) {
        $0.destination = .gameOver(
          GameOver.State(
            completedGame: CompletedGame(gameState: $0),
            isDemo: false
          )
        )
      }
    }

    await didSave.withValue { XCTAssert($0) }
  }
}
