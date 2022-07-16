import ClientModels
import ComposableArchitecture
import GameCore
import XCTest

@MainActor
class GameCoreTests: XCTestCase {
  func testForfeitTurnBasedGame() async {
    var didEndMatchInTurn = false

    var environment = GameEnvironment.failing
    environment.audioPlayer.stopAsync = { _ in }
    environment.database.saveGame = { _ in .none }
    environment.gameCenter.localPlayer.localPlayer = { .authenticated }
    environment.gameCenter.turnBasedMatch.endMatchInTurn = { _ in
      didEndMatchInTurn = true
      return .none
    }

    var gameState = GameState(inProgressGame: .mock)
    gameState.gameContext = .turnBased(
      TurnBasedContext(
        localPlayer: .mock,
        match: .inProgress,
        metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
      )
    )

    let store = TestStore(
      initialState: gameState,
      reducer: gameReducer(
        state: \.self,
        action: /.self,
        environment: { $0 },
        isHapticsEnabled: { _ in false }
      ),
      environment: environment
    )

    await store.send(.forfeitGameButtonTapped) {
      $0.alert = .init(
        title: .init("Are you sure?"),
        message: .init(
          """
          Forfeiting will end the game and your opponent will win. Are you sure you want to \
          forfeit?
          """
        ),
        primaryButton: .default(.init("Don’t forfeit"), action: .send(.dontForfeitButtonTapped)),
        secondaryButton: .destructive(.init("Yes, forfeit"), action: .send(.forfeitButtonTapped))
      )
    }

    await store.send(.alert(.forfeitButtonTapped)) {
      $0.alert = nil
      $0.gameOver = .init(
        completedGame: .init(gameState: gameState),
        isDemo: false,
        turnBasedContext: gameState.turnBasedContext
      )
    }

    XCTAssertNoDifference(didEndMatchInTurn, true)

    await store.finish()
  }
}
