import ClientModels
import Combine
import ComposableArchitecture
import ComposableGameCenter
import Styleguide
import SwiftUI

public struct PastGamesState: Equatable {
  public var pastGames: IdentifiedArrayOf<PastGameState> = []
}

public enum PastGamesAction: Equatable {
  case matchesResponse(TaskResult<[PastGameState]>)
  case pastGame(TurnBasedMatch.Id, PastGameAction)
  case task
}

public struct PastGamesEnvironment {
  public var gameCenter: GameCenterClient
}

let pastGamesReducer = Reducer<PastGamesState, PastGamesAction, PastGamesEnvironment>.combine(
  pastGameReducer.forEach(
    state: \.pastGames,
    action: /PastGamesAction.pastGame,
    environment: { PastGameEnvironment(gameCenter: $0.gameCenter) }
  ),

  .init { state, action, environment in
    switch action {
    case let .matchesResponse(.success(matches)):
      state.pastGames = IdentifiedArray(uniqueElements: matches)
      return .none

    case .matchesResponse(.failure):
      return .none

    case .pastGame:
      return .none

    case .task:
      return .task {
        await .matchesResponse(
          TaskResult {
            try await environment.gameCenter.turnBasedMatch
              .loadMatches()
              .compactMap { match in
                PastGameState(
                  turnBasedMatch: match,
                  localPlayerId: environment.gameCenter.localPlayer.localPlayer().gamePlayerId
                )
              }
              .sorted { $0.endDate > $1.endDate }
          }
        )
      }
    }
  }
)

struct PastGamesView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<PastGamesState, PastGamesAction>
  @ObservedObject var viewStore: ViewStore<PastGamesState, PastGamesAction>

  init(store: Store<PastGamesState, PastGamesAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    ScrollView {
      ForEachStore(
        self.store.scope(
          state: \.pastGames,
          action: PastGamesAction.pastGame
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
              initialState: .init(pastGames: pastGames),
              reducer: pastGamesReducer,
              environment: .init(gameCenter: .noop)
            )
          )
        }
      }
    }
  }

  let pastGames: IdentifiedArrayOf<PastGameState> = [
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
