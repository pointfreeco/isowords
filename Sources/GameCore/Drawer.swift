import ActiveGamesFeature
import ComposableArchitecture

struct ActiveGamesTray: ReducerProtocol {
//  @Dependency(\.fileClient) var fileClient
  @Dependency(\.persistenceClient) var persistenceClient
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop.now.date) var now

  func reduce(into state: inout Game.State, action: Game.Action) -> Effect<Game.Action, Never> {
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
        for: self.gameCenter.localPlayer.localPlayer(),
        at: self.now
      )
      return .none

    case .task:
      return self.activeGameEffects

    case let .savedGamesLoaded(.success(savedGames)):
      state.activeGames.savedGames = savedGames
      return .none

    case .trayButtonTapped:
      guard state.isTrayAvailable else { return .none }
      state.isTrayVisible.toggle()
      return state.isTrayVisible ? self.activeGameEffects : .none
    }
  }

  var activeGameEffects: Effect<Game.Action, Never> {
    .run { send in
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .matchesLoaded(
              TaskResult { try await self.gameCenter.turnBasedMatch.loadMatches() }
            ),
            animation: .default
          )
        }

        group.addTask {
          await send(
            .savedGamesLoaded(
//              TaskResult { try await self.fileClient.loadSavedGames() }
              TaskResult { try await self.persistenceClient.loadSavedGames() }
            ),
            animation: .default
          )
        }
      }
    }
  }
}
