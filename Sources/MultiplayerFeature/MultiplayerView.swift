import ComposableArchitecture
import ComposableGameCenter
import Styleguide
import SwiftUI
import TcaHelpers

public struct MultiplayerState: Equatable {
  public var hasPastGames: Bool
  public var route: Route?

  public enum Route: Equatable {
    case pastGames(PastGamesState)

    public enum Tag: Int {
      case pastGames
    }

    var tag: Tag {
      switch self {
      case .pastGames:
        return .pastGames
      }
    }
  }

  public init(
    hasPastGames: Bool,
    route: Route? = nil
  ) {
    self.hasPastGames = hasPastGames
    self.route = route
  }
}

public enum MultiplayerAction {
  case pastGames(PastGamesAction)
  case setNavigation(tag: MultiplayerState.Route.Tag?)
  case startButtonTapped
}

public struct MultiplayerEnvironment {
  public var backgroundQueue: AnySchedulerOf<DispatchQueue>
  public var gameCenter: GameCenterClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    gameCenter: GameCenterClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.backgroundQueue = backgroundQueue
    self.gameCenter = gameCenter
    self.mainQueue = mainQueue
  }
}

public let multiplayerReducer = Reducer<
  MultiplayerState,
  MultiplayerAction,
  MultiplayerEnvironment
>.combine(
  pastGamesReducer
    ._pullback(
      state: (\MultiplayerState.route).appending(path: /MultiplayerState.Route.pastGames),
      action: /MultiplayerAction.pastGames,
      environment: {
        PastGamesEnvironment(
          backgroundQueue: $0.backgroundQueue,
          gameCenter: $0.gameCenter,
          mainQueue: $0.mainQueue
        )
      }
    ),

  .init { state, action, environment in
    switch action {
    case .pastGames:
      return .none

    case .startButtonTapped:
      if environment.gameCenter.localPlayer.localPlayer().isAuthenticated {
        return environment.gameCenter.turnBasedMatchmakerViewController
          .present(showExistingMatches: false)
          .fireAndForget()

      } else {
        return environment.gameCenter.localPlayer.presentAuthenticationViewController
          .fireAndForget()
      }

    case .setNavigation(tag: .pastGames):
      state.route = .pastGames(.init())
      return .none

    case .setNavigation(tag: .none):
      state.route = nil
      return .none
    }
  }
)

public struct MultiplayerView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  let store: Store<MultiplayerState, MultiplayerAction>
  @ObservedObject var viewStore: ViewStore<ViewState, MultiplayerAction>

  public init(store: Store<MultiplayerState, MultiplayerAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init))
  }

  struct ViewState: Equatable {
    let hasPastGames: Bool
    let routeTag: MultiplayerState.Route.Tag?

    init(state: MultiplayerState) {
      self.hasPastGames = state.hasPastGames
      self.routeTag = state.route?.tag
    }
  }

  public var body: some View {
    GeometryReader { proxy in
      VStack {
        Spacer()
          .frame(maxHeight: .grid(16))

        VStack(spacing: 20 + self.adaptiveSize.padding) {
          VStack(spacing: -8) {
            Text("Play")
            Text("against a")
            Text("friend")
          }
          .multilineTextAlignment(.center)
          .font(.custom(.matter, size: self.adaptiveSize.pad(48, by: 2)))

          Text("(it’s fun, trust us)")
            .adaptiveFont(.matter, size: 20)
        }

        Spacer()

        Button(action: { self.viewStore.send(.startButtonTapped) }) {
          VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
              .font(.system(size: self.adaptiveSize.pad(40)))
            Text("Start a game!")
              .adaptiveFont(.matterMedium, size: 16)
          }
          .adaptivePadding(.all, .grid(7))
          .background(self.colorScheme == .dark ? Color.multiplayer : .isowordsBlack)
          .foregroundColor(self.colorScheme == .dark ? .isowordsBlack : .multiplayer)
          .continuousCornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .adaptivePadding([.top, .bottom])
        .adaptivePadding(.bottom, .grid(self.viewStore.hasPastGames ? 0 : 8))

        if self.viewStore.hasPastGames {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: (\MultiplayerState.route)
                  .appending(path: /MultiplayerState.Route.pastGames)
                  .extract(from:),
                action: MultiplayerAction.pastGames
              ),
              then: { PastGamesView(store: $0) }
            ),
            tag: MultiplayerState.Route.Tag.pastGames,
            selection: viewStore.binding(
              get: \.routeTag,
              send: MultiplayerAction.setNavigation
            )
          ) {
            HStack {
              Text("View past games")
                .adaptiveFont(.matterMedium, size: 16)
              Spacer()
              Image(systemName: "arrow.right")
                .font(.system(size: self.adaptiveSize.pad(16)))
            }
            .adaptivePadding(.horizontal, .grid(5))
            .adaptivePadding(.vertical, .grid(9))
            .padding(.bottom, proxy.safeAreaInsets.bottom / 2)
          }
          .frame(maxWidth: .infinity)
          .foregroundColor((self.colorScheme == .dark ? .isowordsBlack : .multiplayer))
          .background(self.colorScheme == .dark ? Color.multiplayer : .isowordsBlack)
        }
      }
      .navigationStyle(
        backgroundColor: self.colorScheme == .dark ? .isowordsBlack : .multiplayer,
        foregroundColor: self.colorScheme == .dark ? .multiplayer : .isowordsBlack,
        title: Text("Multiplayer")
      )
      .edgesIgnoringSafeArea(.bottom)
    }
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct MultiplayerView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          MultiplayerView(store: .multiplayer)
        }
      }
    }
  }

  extension Store where State == MultiplayerState, Action == MultiplayerAction {
    static let multiplayer = Store(
      initialState: .init(hasPastGames: true),
      reducer: multiplayerReducer,
      environment: MultiplayerEnvironment(
        backgroundQueue: DispatchQueue(label: "background").eraseToAnyScheduler(),
        gameCenter: .noop,
        mainQueue: .main
      )
    )
  }
#endif
