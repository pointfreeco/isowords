import ComposableArchitecture

extension Reducer where State == GameState, Action == GameAction, Environment == GameEnvironment {
  func filterActionsForYourTurn() -> Self {
    self.filter { state, action in
      switch action {
      case .pan,
        .submitButtonTapped,
        .tap,
        .wordSubmitButton(.delegate(.confirmSubmit)):
        return state.isYourTurn

      case .activeGames,
        .alert,
        .bottomMenu(.confirmRemoveCube),
        .bottomMenu(.dismiss),
        .bottomMenu(.endGameButtonTapped),
        .bottomMenu(.exitButtonTapped),
        .bottomMenu(.forfeitGameButtonTapped),
        .bottomMenu(.settingsButtonTapped),
        .cancelButtonTapped,
        .delayedShowUpgradeInterstitial,
        .doubleTap,
        .gameCenter,
        .gameLoaded,
        .gameOver,
        .lowPowerModeChanged,
        .matchesLoaded,
        .menuButtonTapped,
        .onAppear,
        .savedGamesLoaded,
        .timerTick,
        .trayButtonTapped,
        .upgradeInterstitial,
        .wordSubmitButton:
        return true
      }
    }
  }
}
