import ComposableArchitecture
import SwiftUI
import TcaHelpers

public struct Multiplayer: ReducerProtocol {
  public struct State: Equatable {
    public var hasPastGames: Bool
    @PresentationStateOf<PastGames> public var pastGames

    public init(
      hasPastGames: Bool,
      pastGames: PastGames.State? = nil
    ) {
      self.hasPastGames = hasPastGames
      self.pastGames = pastGames
    }
  }

  public enum Action: Equatable {
    case pastGames(PresentationActionOf<PastGames>)
    case startButtonTapped
  }

  @Dependency(\.gameCenter) var gameCenter

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .pastGames:
        return .none

      case .startButtonTapped:
        return .fireAndForget {
          if self.gameCenter.localPlayer.localPlayer().isAuthenticated {
            try await self.gameCenter.turnBasedMatchmakerViewController.present(false)
          } else {
            await self.gameCenter.localPlayer.presentAuthenticationViewController()
          }
        }
      }
    }
    .presentationDestination(state: \State.$pastGames, action: /Action.pastGames) {
      PastGames()
    }
  }
}

public struct MultiplayerView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Multiplayer>
  @ObservedObject var viewStore: ViewStore<ViewState, Multiplayer.Action>

  public init(store: StoreOf<Multiplayer>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init))
  }

  struct ViewState: Equatable {
    let hasPastGames: Bool

    init(state: Multiplayer.State) {
      self.hasPastGames = state.hasPastGames
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
          Button {
            viewStore.send(.pastGames(.present(PastGames.State())))
          } label: {
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
      .navigationDestination(
        store: self.store.scope(state: \.$pastGames, action: Multiplayer.Action.pastGames),
        destination: PastGamesView.init(store:)
      )
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
        NavigationStack {
          MultiplayerView(store: .multiplayer)
        }
      }
    }
  }

  extension Store where State == Multiplayer.State, Action == Multiplayer.Action {
    static let multiplayer = Store(
      initialState: .init(hasPastGames: true),
      reducer: Multiplayer()
    )
  }
#endif
