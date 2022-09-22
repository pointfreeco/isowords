import ComposableArchitecture
import GameOverFeature
import SharedModels

struct GameOverLogic: ReducerProtocol {
  @Dependency(\.database.saveGame) var saveGame

  func reduce(into state: inout Game.State, action: Game.Action) -> Effect<Game.Action, Never> {
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

    state.bottomMenu = nil
    state.gameOver = GameOver.State(
      completedGame: CompletedGame(gameState: state),
      isDemo: state.isDemo
    )

    switch state.gameContext {
    case .dailyChallenge, .shared, .solo:
      return .fireAndForget { [state] in
        try await self.saveGame(.init(gameState: state))
      }

    case let .turnBased(turnBasedMatch):
      state.gameOver?.turnBasedContext = turnBasedMatch
      return .none
    }
  }
}
