import ClientModels
import ComposableArchitecture
import GameCore
import GameOverFeature
import XCTest

@MainActor
class GameCoreTests: XCTestCase {
  func testForfeitTurnBasedGame() async {
    let didEndMatchInTurn = ActorIsolated(false)

    var gameState = Game.State(inProgressGame: .mock)
    gameState.gameContext = .turnBased(
      TurnBasedContext(
        localPlayer: .mock,
        match: .inProgress,
        metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
      )
    )

    let store = TestStore(
      initialState: gameState
    ) {
      Game()
    }

    store.dependencies.audioPlayer.stop = { _ in }
    store.dependencies.gameCenter.localPlayer.localPlayer = { .authenticated }
    store.dependencies.gameCenter.turnBasedMatch.endMatchInTurn = { _ in
      await didEndMatchInTurn.setValue(true)
    }

    await store.send(.forfeitGameButtonTapped) {
      $0.destination = .alert(
        AlertState {
          TextState("Are you sure?")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("Don't forfeit")
          }
          ButtonState(role: .destructive, action: .forfeitButtonTapped) {
            TextState("Yes, forfeit")
          }
        } message: {
          TextState(
            """
            Forfeiting will end the game and your opponent will win. Are you sure you want to \
            forfeit?
            """
          )
        }
      )
    }

    await store.send(.destination(.presented(.alert(.forfeitButtonTapped)))) {
      $0.destination = .gameOver(
        GameOver.State(
          completedGame: .init(gameState: gameState),
          isDemo: false,
          turnBasedContext: gameState.turnBasedContext
        )
      )
    }

    await didEndMatchInTurn.withValue { XCTAssertNoDifference($0, true) }
    await store.finish()
  }
}
