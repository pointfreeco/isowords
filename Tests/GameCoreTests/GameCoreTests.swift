import ClientModels
import ComposableArchitecture
import ConcurrencyExtras
import CustomDump
import Dependencies
import GameCore
import GameOverFeature
import XCTest

class GameCoreTests: XCTestCase {
  @MainActor
  func testForfeitTurnBasedGame() async throws {
    let didEndMatchInTurn = ActorIsolated(false)

    var gameState = Game.State(inProgressGame: .mock)
    gameState.gameContext = .turnBased(
      TurnBasedContext(
        localPlayer: .mock,
        match: .inProgress,
        metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
      )
    )

    let store = withDependencies {
      $0.audioPlayer.stop = { _ in }
      $0.gameCenter.localPlayer.localPlayer = { .authenticated }
      $0.gameCenter.turnBasedMatch.endMatchInTurn = { _ in
        await didEndMatchInTurn.setValue(true)
      }
    } operation: {
      TestStore(initialState: gameState) {
        Game(startsOnMount: false)
      }
    }

    store.send(.menuButtonTapped) {
      $0.destination = snap(Game.Destination.State.bottomMenu(.gameMenu(state: gameState)))
    }
    store.send(.destination(.bottomMenu(.forfeitGameButtonTapped))) {
      $0.destination = snap(Game.Destination.State.alert(Game.Destination.Alert.State()))
    }

    let task = store.send(.destination(.alert(.forfeitButtonTapped))) {
      $0.destination = snap(
        Game.Destination.State.gameOver(
          GameOver.State(
            completedGame: .init(gameState: gameState),
            isDemo: false,
            turnBasedContext: gameState.gameContext.turnBased
          )
        )
      )
    }
    await task?.value

    await didEndMatchInTurn.withValue { expectNoDifference($0, true) }
    await store.dismount()
  }
}
