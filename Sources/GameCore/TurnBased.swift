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
        .cancelButtonTapped,
        .confirmRemoveCube,
        .delayedShowUpgradeInterstitial,
        .dismissBottomMenu,
        .doubleTap,
        .endGameButtonTapped,
        .exitButtonTapped,
        .forfeitGameButtonTapped,
        .gameCenter,
        .gameLoaded,
        .gameOver,
        .lowPowerModeChanged,
        .matchesLoaded,
        .menuButtonTapped,
        .onAppear,
        .replay,
        .savedGamesLoaded,
        .settingsButtonTapped,
        .timerTick,
        .trayButtonTapped,
        .upgradeInterstitial,
        .wordSubmitButton:
        return true
      }
    }
  }
}
