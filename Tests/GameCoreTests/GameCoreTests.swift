import ClientModels
import ComposableArchitecture
import GameCore
import GameOverFeature
import XCTest

class GameCoreTests: XCTestCase {
  @MainActor
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

    let store = TestStore(initialState: gameState) {
      Game()
    } withDependencies: {
      $0.audioPlayer.stop = { _ in }
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.endMatchInTurn = { _ in
        await didEndMatchInTurn.setValue(true)
      }
    }

    await store.send(.menuButtonTapped) {
      $0.destination = .bottomMenu(.gameMenu(state: $0))
    }
    await store.send(.destination(.presented(.bottomMenu(.forfeitGameButtonTapped)))) {
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
          turnBasedContext: gameState.gameContext.turnBased
        )
      )
    }

    await didEndMatchInTurn.withValue { expectNoDifference($0, true) }
    await store.finish()
  }
}
