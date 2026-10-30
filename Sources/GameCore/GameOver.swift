import ComposableArchitecture
import Dependencies
import GameOverFeature
import SharedModels

extension Game {
  func endGame(state: inout State) {
    guard !state.isGameOver else { return }

    state.destination = .gameOver(
      GameOver.State(
        completedGame: CompletedGame(gameState: state),
        isDemo: state.isDemo,
        turnBasedContext: state.gameContext.turnBased
      )
    )

    switch state.gameContext {
    case .dailyChallenge, .shared, .solo:
      let completedGame = CompletedGame(gameState: state)
      store.addTask {
        try await saveGame(completedGame)
      }

    case .turnBased:
      break
    }
  }
}
