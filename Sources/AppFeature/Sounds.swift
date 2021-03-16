import AudioPlayerClient
import ComposableArchitecture

extension Reducer where State == AppState, Action == AppAction, Environment == AppEnvironment {
  func sounds() -> Self {
    self.combined(
      with: Self { state, action, environment in
        switch action {
        case .home(.activeGames(.turnBasedGameMenuItemTapped(.deleteMatch))):
          return environment.audioPlayer.play(.uiSfxActionDestructive)
            .fireAndForget()

        case .currentGame(.onDisappear):
          return
            Effect
            .merge(AudioPlayerClient.Sound.allMusic.map(environment.audioPlayer.stop))
            .fireAndForget()

        default:
          return .none
        }
      })
  }
}
