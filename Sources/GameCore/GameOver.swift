import ComposableArchitecture
import GameOverFeature
import SharedModels

struct GameOverLogic: Reducer {
  @Dependency(\.database.saveGame) var saveGame

  var body: some ReducerOf<Game> {
    Reduce { state, action in
      var allCubesRemoved: Bool {
        state.cubes.allSatisfy {
          $0.allSatisfy {
            $0.allSatisfy { !$0.isInPlay }
          }
        }
      }

      var timesUp: Bool {
        state.gameMode == .timed && state.secondsPlayed >= state.gameMode.seconds
      }

      guard
        !state.isGameOver
          && action == .destination(.presented(.alert(.forfeitButtonTapped)))
          || action == .endGameButtonTapped
          || timesUp
          || allCubesRemoved
      else { return .none }

      state.bottomMenu = nil
      state.destination = .gameOver(
        GameOver.State(
          completedGame: CompletedGame(gameState: state),
          isDemo: state.isDemo
        )
      )

      switch state.gameContext {
      case .dailyChallenge, .shared, .solo:
        return .run { [state] _ in
          try await self.saveGame(.init(gameState: state))
        }

      case let .turnBased(turnBasedMatch):
        state.$destination[case: /Game.Destination.State.gameOver]?.turnBasedContext =
          turnBasedMatch
        return .none
      }
    }
  }
}
