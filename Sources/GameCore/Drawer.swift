import ActiveGamesFeature
import ComposableArchitecture

@Reducer
public struct ActiveGamesTray {
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.mainRunLoop.now.date) var now

  public var body: some ReducerOf<Game> {
    Reduce { state, action in
      switch action {
      case .cancelButtonTapped,
        .confirmRemoveCube,
        .doubleTap,
        .destination(.presented(.bottomMenu(.confirmRemoveCube))),
        .destination(.presented(.bottomMenu(.endGameButtonTapped))),
        .destination(.presented(.bottomMenu(.forfeitGameButtonTapped))),
        .menuButtonTapped,
        .pan,
        .submitButtonTapped,
        .tap,
        .wordSubmitButton:

        state.isTrayVisible = false
        return .none

      case .activeGames,
        .delayedShowUpgradeInterstitial,
        .destination(.presented(.bottomMenu(.exitButtonTapped))),
        .destination(.presented(.bottomMenu(.settingsButtonTapped))),
        .destination,
        .gameCenter,
        .gameLoaded,
        .matchesLoaded(.failure),
        .timerTick:

        return .none

      case let .matchesLoaded(.success(matches)):
        state.activeGames.turnBasedMatches = matches.activeMatches(
          for: self.gameCenter.localPlayer.localPlayer(),
          at: self.now
        )
        return .none

      case .task:
        return self.activeGameEffects

      case .trayButtonTapped:
        guard state.isTrayAvailable else { return .none }
        state.isTrayVisible.toggle()
        return state.isTrayVisible ? self.activeGameEffects : .none
      }
    }
  }

  var activeGameEffects: EffectOf<Self> {
    .run { send in
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .matchesLoaded(
              Result { try await self.gameCenter.turnBasedMatch.loadMatches() }
            ),
            animation: .default
          )
        }
      }
    }
  }
}
