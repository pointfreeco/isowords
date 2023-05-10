import ComposableArchitecture
import GameOverFeature
import SharedModels

struct GameOverLogic: ReducerProtocol {
  @Dependency(\.database.saveGame) var saveGame

  func reduce(into state: inout Game.State, action: Game.Action) -> EffectTask<Game.Action> {
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
        && action == .destination(.presented(.alert(.forfeitButtonTapped)))
        || action == .destination(.presented(.bottomMenu(.endGameButtonTapped)))
        || timesUp
        || allCubesRemoved
    else { return .none }

    state.destination = .gameOver(
      GameOver.State(
        completedGame: CompletedGame(gameState: state),
        isDemo: state.isDemo
      )
    )

    switch state.gameContext {
    case .dailyChallenge, .shared, .solo:
      return .fireAndForget { [state] in
        try await self.saveGame(.init(gameState: state))
      }

    case let .turnBased(turnBasedMatch):
      XCTModify(&state.destination, case: /Game.Destination.State.gameOver) {
        $0.turnBasedContext = turnBasedMatch
      }
      return .none
    }
  }
}
