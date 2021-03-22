import ComposableArchitecture
import GameCore
import XCTest

class GameCoreTests: XCTestCase {
  func testForfeitTurnBasedGame() {
    var environment = GameEnvironment.failing
    environment.audioPlayer.stop = { _ in .none }
    environment.database.saveGame = { _ in .none }

    let gameState = GameState(inProgressGame: .mock)

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


    store.send(.forfeitGameButtonTapped) {
      $0.alert = .init(
        title: .init("Are you sure?"),
        message: .init(
          """
          Forfeiting will end the game and your opponent will win. Are you sure you want to \
          forfeit?
          """
        ),
        primaryButton: .default(.init("Don't forfeit"), send: .dontForfeitButtonTapped),
        secondaryButton: .destructive(.init("Yes, forfeit"), send: .forfeitButtonTapped),
        onDismiss: .dismiss
      )
    }

    store.send(.alert(.forfeitButtonTapped)) {
      $0.alert = nil
      $0.gameOver = .init(completedGame: .init(gameState: gameState), isDemo: false)
    }
  }
}
