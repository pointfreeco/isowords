import ClientModels
import Combine
import ComposableArchitecture
import ComposableGameCenter
import Styleguide
import SwiftUI

public struct PastGamesState: Equatable {
  public var pastGames: IdentifiedArrayOf<PastGameState> = []
}

public enum PastGamesAction {
  case matchesResponse(Result<[PastGameState], Error>)
  case onAppear
  case pastGame(TurnBasedMatch.Id, PastGameAction)
}

public struct PastGamesEnvironment {
  public var backgroundQueue: AnySchedulerOf<DispatchQueue>
  public var gameCenter: GameCenterClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>
}

let pastGamesReducer = Reducer<PastGamesState, PastGamesAction, PastGamesEnvironment>.combine(
  pastGameReducer.forEach(
    state: \.pastGames,
    action: /PastGamesAction.pastGame,
    environment: {
      PastGameEnvironment(
        gameCenter: $0.gameCenter,
        mainQueue: $0.mainQueue
      )
    }
  ),

  .init { state, action, environment in
    switch action {
    case let .matchesResponse(.success(matches)):
      state.pastGames = IdentifiedArray(uniqueElements: matches)
      return .none

    case .matchesResponse(.failure):
      return .none

    case .onAppear:
      return environment.gameCenter.turnBasedMatch.loadMatches()
        .receive(on: environment.backgroundQueue)
        .map { matches in
          matches.compactMap { match in
            PastGameState(
              turnBasedMatch: match,
              localPlayerId: environment.gameCenter.localPlayer.localPlayer().gamePlayerId
            )
          }
          .sorted { $0.endDate > $1.endDate }
        }
        .receive(on: environment.mainQueue)
        .catchToEffect(PastGamesAction.matchesResponse)

    case .pastGame:
      return .none
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
    .onAppear {
      viewStore.send(.onAppear)
    }
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
              environment: .init(
                backgroundQueue: DispatchQueue.global(qos: .userInitiated).eraseToAnyScheduler(),
                gameCenter: .noop,
                mainQueue: .main
              )
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
