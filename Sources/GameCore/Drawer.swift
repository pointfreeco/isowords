import ActiveGamesFeature
import ComposableArchitecture

extension Reducer where State == GameState, Action == GameAction, Environment == GameEnvironment {
  static let activeGamesTray = Self { state, action, environment in
    let activeGameEffects = Effect<GameAction, Never>.merge(
      environment.gameCenter.turnBasedMatch.loadMatches()
        .receive(on: environment.mainQueue.animation())
        .mapError { $0 as NSError }
        .catchToEffect(GameAction.matchesLoaded),
      environment.fileClient.loadSavedGames()
        .subscribe(on: environment.backgroundQueue)
        .receive(on: environment.mainQueue.animation())
        .eraseToEffect()
        .map(GameAction.savedGamesLoaded)
    )

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

    case .onAppear:
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
