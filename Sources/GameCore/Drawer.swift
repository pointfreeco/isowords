import ActiveGamesFeature
import ComposableArchitecture
import Dependencies
import SwiftUI

extension Game {
  func activeGamesTray(state: inout State, action: Action) {
    switch action {
    case .cancelButtonTapped,
      .confirmRemoveCube,
      .doubleTap,
      .destination(.bottomMenu(.confirmRemoveCube)),
      .destination(.bottomMenu(.endGameButtonTapped)),
      .destination(.bottomMenu(.forfeitGameButtonTapped)),
      .menuButtonTapped,
      .pan,
      .submitButtonTapped,
      .tap:

      state.isTrayVisible = false

    case .destination:
      break

    case .trayButtonTapped:
      guard state.isTrayAvailable else { return }
      state.isTrayVisible.toggle()
      if state.isTrayVisible {
        loadActiveGames()
      }
    }
  }

  func loadActiveGames() {
    store.addTask {
      guard let matches = try? await gameCenter.turnBasedMatch.loadMatches()
      else { return }
      let localPlayer = gameCenter.localPlayer.localPlayer()
      try withAnimation {
        _ = try store.modify {
          $0.activeGames.turnBasedMatches = matches.activeMatches(for: localPlayer, at: now)
        }
      }
    }
    store.addTask {
      guard let savedGames = try? await fileClient.loadSavedGames()
      else { return }
      try withAnimation {
        _ = try store.modify { $0.activeGames.savedGames = savedGames }
      }
    }
  }
}
