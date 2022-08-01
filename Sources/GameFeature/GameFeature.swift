import AudioPlayerClient
import CasePaths
import ComposableArchitecture
@_exported import GameCore
import SettingsFeature
import TcaHelpers

public struct GameFeatureState: Equatable {
  public var game: GameState?
  public var settings: Settings.State

  public init(
    game: GameState?,
    settings: Settings.State
  ) {
    self.game = game
    self.settings = settings
  }
}

public enum GameFeatureAction: Equatable {
  case dismissSettings
  case game(GameAction)
  case settings(Settings.Action)
}

public let gameFeatureReducer = Reducer<GameFeatureState, GameFeatureAction, GameEnvironment>
  .combine(
    Reducer(
      Scope(state: \.settings, action: /GameFeatureAction.settings) {
        Settings()
      }
    ),

    gameReducer(
      state: OptionalPath(\.game),
      action: /GameFeatureAction.game,
      environment: { $0 },
      isHapticsEnabled: \.settings.userSettings.enableHaptics
    ),

    .init { state, action, environment in
      switch action {
      case .dismissSettings:
        state.game?.isSettingsPresented = false
        return .none

      default:
        return .none
      }
    }
  )
