import ComposableArchitecture
import GameOverFeature
import SharedModels

struct GameOverLogic: ReducerProtocol {
  @Dependency(\.database) var database

  func reduce(into state: inout GameState, action: GameAction) -> Effect<GameAction, Never> {
    var allCubesRemoved: Bool {
      state.cubes.allSatisfy {
        $0.allSatisfy {
          $0.allSatisfy { !$0.isInPlay }
        }
      }
    }

    var timesUp: Bool { state.gameMode == .timed && state.secondsPlayed >= state.gameMode.seconds }

    guard
      !state.isGameOver
        && action == .alert(.forfeitButtonTapped)
        || action == .endGameButtonTapped
        || timesUp
        || allCubesRemoved
    else { return .none }

    var effects: [Effect<GameAction, Never>] = []

    state.bottomMenu = nil
    state.gameOver = GameOver.State(
      completedGame: CompletedGame(gameState: state),
      isDemo: state.isDemo
    )

    switch state.gameContext {
    case .dailyChallenge, .shared, .solo:
      return .fireAndForget { [state] in
        try await self.database.saveGame(.init(gameState: state))
      }

    case let .turnBased(turnBasedMatch):
      state.gameOver?.turnBasedContext = turnBasedMatch
      return .none
    }
  }
}
