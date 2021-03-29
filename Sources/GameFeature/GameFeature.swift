import CasePaths
import ComposableArchitecture
@_exported import GameCore
import SettingsFeature

public struct GameFeatureState: Equatable {
  public var game: GameState?
  public var settings: SettingsState

  public init(
    game: GameState?,
    settings: SettingsState
  ) {
    self.game = game
    self.settings = settings
  }
}

public enum GameFeatureAction: Equatable {
  case game(GameAction)
  case settings(SettingsAction)
  case onDisappear
}

public let gameFeatureReducer = Reducer<GameFeatureState, GameFeatureAction, GameEnvironment>
  .combine(
    settingsReducer
      .pullback(
        state: \GameFeatureState.settings,
        action: /GameFeatureAction.settings,
        environment: {
          SettingsEnvironment(
            apiClient: $0.apiClient,
            applicationClient: $0.applicationClient,
            audioPlayer: $0.audioPlayer,
            backgroundQueue: $0.backgroundQueue,
            build: $0.build,
            database: $0.database,
            feedbackGenerator: $0.feedbackGenerator,
            fileClient: $0.fileClient,
            lowPowerMode: $0.lowPowerMode,
            mainQueue: $0.mainQueue,
            remoteNotifications: $0.remoteNotifications,
            serverConfig: $0.serverConfig,
            setUserInterfaceStyle: $0.setUserInterfaceStyle,
            storeKit: $0.storeKit,
            userDefaults: $0.userDefaults,
            userNotifications: $0.userNotifications
          )
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
      case .onDisappear:
        return Effect.gameTearDownEffects.fireAndForget()

      case .settings(.onDismiss):
        state.game?.isSettingsPresented = false
        return .none

      default:
        return .none
      }
    }
  )
