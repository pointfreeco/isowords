import ComposableArchitecture
@_exported import GameCore
import SettingsFeature
import TcaHelpers

public struct GameFeature: Reducer {
  public struct State: Equatable {
    public var game: Game.State?
    public var settings: Settings.State

    public init(
      game: Game.State?,
      settings: Settings.State
    ) {
      self.game = game
      self.settings = settings
    }
  }

  public enum Action: Equatable {
    case dismissSettings
    case game(Game.Action)
    case settings(Settings.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.settings, action: /Action.settings) {
      Settings()
    }
    IntegratedGame(
      state: OptionalPath(\.game),
      action: /Action.game,
      isHapticsEnabled: \.settings.userSettings.enableHaptics
    )
    Reduce { state, action in
      switch action {
      case .dismissSettings:
        state.game?.isSettingsPresented = false
        return .none

      default:
        return .none
      }
    }
  }
}
