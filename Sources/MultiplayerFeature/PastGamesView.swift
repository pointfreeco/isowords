import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Styleguide
import SwiftUI

public struct PastGames: Reducer {
  public struct State: Equatable {
    public var pastGames: IdentifiedArrayOf<PastGame.State> = []
  }

  public enum Action: Equatable {
    case matchesResponse(TaskResult<[PastGame.State]>)
    case pastGame(TurnBasedMatch.Id, PastGame.Action)
    case task
  }

  @Dependency(\.gameCenter) var gameCenter

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .matchesResponse(.success(matches)):
        state.pastGames = IdentifiedArray(uniqueElements: matches)
        return .none

      case .matchesResponse(.failure):
        return .none

      case .pastGame:
        return .none

      case .task:
        return .run { send in
          await send(
            .matchesResponse(
              TaskResult {
                try await self.gameCenter.turnBasedMatch
                  .loadMatches()
                  .compactMap { match in
                    PastGame.State(
                      turnBasedMatch: match,
                      localPlayerId: self.gameCenter.localPlayer.localPlayer().gamePlayerId
                    )
                  }
                  .sorted { $0.endDate > $1.endDate }
              }
            )
          )
        }
      }
    }
    .forEach(\.pastGames, action: /Action.pastGame) {
      PastGame()
    }
  }
}

struct PastGamesView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<PastGames>
  @ObservedObject var viewStore: ViewStoreOf<PastGames>

  init(store: StoreOf<PastGames>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
  }

  var body: some View {
    ScrollView {
      ForEachStore(
        self.store.scope(
          state: \.pastGames,
          action: PastGames.Action.pastGame
        ),
        content: { store in
          Group {
            PastGameRow(store: store)

            Divider()
              .frame(height: 2)
              .background(self.colorScheme == .light ? Color.isowordsBlack : .multiplayer)
              .padding([.top, .bottom], .grid(8))
          }
        }
      )
      .padding()
    }
    .task { await viewStore.send(.task).finish() }
    .navigationStyle(
      backgroundColor: self.colorScheme == .dark ? .isowordsBlack : .multiplayer,
      foregroundColor: self.colorScheme == .dark ? .multiplayer : .isowordsBlack,
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

  let pastGames: IdentifiedArrayOf<PastGame.State> = [
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
