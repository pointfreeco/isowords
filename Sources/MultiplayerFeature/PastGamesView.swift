import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Dependencies
import Styleguide
import SwiftUI

@Feature
public struct PastGames {
  public struct State {
    public var pastGames: [PastGame.State] = []
  }

  public enum Action {
    case pastGames(PastGame.State.ID, PastGame.Action)
  }

  @Dependency(\.gameCenter) var gameCenter

  public var body: some Feature {
    Update { _, _ in }
      .forEach(\.pastGames) {
        PastGame()
      }
      .onMount { _ in
        store.addTask {
          guard
            let matches = try? await gameCenter.turnBasedMatch.loadMatches()
          else { return }
          let localPlayerId = gameCenter.localPlayer.localPlayer().gamePlayerId
          let pastGames =
            matches
            .compactMap { PastGame.State(turnBasedMatch: $0, localPlayerId: localPlayerId) }
            .sorted { $0.endDate > $1.endDate }
          try store.modify { $0.pastGames = pastGames }
        }
      }
  }
}

struct PastGamesView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<PastGames>

  var body: some View {
    ScrollView {
      ForEach(store.scope(\.pastGames)) { store in
        Group {
          PastGameRow(store: store)

          Divider()
            .frame(height: 2)
            .background(colorScheme == .light ? Color.isowordsBlack : .multiplayer)
            .padding(.vertical, .grid(8))
        }
      }
      .padding()
    }
    .navigationStyle(
      backgroundColor: colorScheme == .dark ? .isowordsBlack : .multiplayer,
      foregroundColor: colorScheme == .dark ? .multiplayer : .isowordsBlack,
      title: Text("Past games")
    )
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          PastGamesView(
            store: .init(
              initialState: PastGames.State(pastGames: pastGames)
            ) {
              PastGames()
            }
          )
        }
      }
    }
  }

  let pastGames: [PastGame.State] = [
    .init(
      challengeeDisplayName: "Blob",
      challengerDisplayName: "Blob Jr",
      challengeeScore: 1000,
      challengerScore: 2000,
      endDate: Date(),
      matchId: .init(rawValue: "1"),
      opponentDisplayName: "Blob"
    ),
    .init(
      challengeeDisplayName: "Blob",
      challengerDisplayName: "Blob Jr",
      challengeeScore: 2000,
      challengerScore: 2000,
      endDate: Date().addingTimeInterval(-300_000),
      matchId: .init(rawValue: "2"),
      opponentDisplayName: "Blob Jr"
    ),
    .init(
      challengeeDisplayName: "Blob",
      challengerDisplayName: "Blob Jr",
      challengeeScore: 4000,
      challengerScore: 2000,
      endDate: Date().addingTimeInterval(-1_000_000),
      matchId: .init(rawValue: "3"),
      opponentDisplayName: "Blob Jr"
    ),
  ]
#endif
