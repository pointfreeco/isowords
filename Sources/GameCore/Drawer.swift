import ActiveGamesFeature
import ComposableArchitecture

extension Reducer where State == GameState, Action == GameAction, Environment == GameEnvironment {
  static let activeGamesTray = Self { state, action, environment in
    let activeGameEffects = Effect<GameAction, Never>.run { send in
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .matchesLoaded(
              TaskResult { try await environment.gameCenter.turnBasedMatch.loadMatches() }
            ),
            animation: .default
          )
        }

        group.addTask {
          await send(
            .savedGamesLoaded(
              TaskResult { try await environment.fileClient.loadSavedGamesAsync() }
            ),
            animation: .default
          )
        }
      }
    }

    switch action {
    case .cancelButtonTapped,
      .confirmRemoveCube,
      .doubleTap,
      .endGameButtonTapped,
      .forfeitGameButtonTapped,
      .menuButtonTapped,
      .pan,
      .submitButtonTapped,
      .tap,
      .wordSubmitButton:
      state.isTrayVisible = false
      return .none

    case .activeGames,
      .alert,
      .delayedShowUpgradeInterstitial,
      .exitButtonTapped,
      .dismissBottomMenu,
      .gameCenter,
      .gameLoaded,
      .gameOver,
      .lowPowerModeChanged,
      .matchesLoaded(.failure),
      .savedGamesLoaded(.failure),
      .settingsButtonTapped,
      .timerTick,
      .upgradeInterstitial:
      return .none

    case let .matchesLoaded(.success(matches)):
      state.activeGames.turnBasedMatches = matches.activeMatches(
        for: environment.gameCenter.localPlayer.localPlayer(),
        at: environment.mainRunLoop.now.date
      )
      return .none

    case .task:
      return activeGameEffects

    case let .savedGamesLoaded(.success(savedGames)):
      state.activeGames.savedGames = savedGames
      return .none

    case .trayButtonTapped:
      guard state.isTrayAvailable else { return .none }
      state.isTrayVisible.toggle()
      return state.isTrayVisible ? activeGameEffects : .none
    }
  }
}
