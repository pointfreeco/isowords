import ComposableArchitecture
import SwiftUI
import TcaHelpers

@Reducer
public struct Multiplayer {
  @Reducer(state: .equatable)
  public enum Destination {
    case pastGames(PastGames)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var hasPastGames: Bool

    public init(
      destination: Destination.State? = nil,
      hasPastGames: Bool
    ) {
      self.destination = destination
      self.hasPastGames = hasPastGames
    }
  }

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case pastGamesButtonTapped
    case startButtonTapped
  }

  @Dependency(\.gameCenter) var gameCenter

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination:
        return .none

      case .startButtonTapped:
        return .run { _ in
          if self.gameCenter.localPlayer.localPlayer().isAuthenticated {
            try await self.gameCenter.turnBasedMatchmakerViewController.present(false)
          } else {
            await self.gameCenter.localPlayer.presentAuthenticationViewController()
          }
        }

      case .pastGamesButtonTapped:
        state.destination = .pastGames(PastGames.State())
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

public struct MultiplayerView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Bindable var store: StoreOf<Multiplayer>

  public init(store: StoreOf<Multiplayer>) {
    self.store = store
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

        Button {
          store.send(.startButtonTapped)
        } label: {
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
        .adaptivePadding(.vertical)
        .adaptivePadding(.bottom, .grid(store.hasPastGames ? 0 : 8))

        if store.hasPastGames {
          Button {
            store.send(.pastGamesButtonTapped)
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
        item: $store.scope(state: \.destination?.pastGames, action: \.destination.pastGames)
      ) { store in
        PastGamesView(store: store)
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

  extension Store where State == Multiplayer.State, Action == Multiplayer.Action {
    static let multiplayer = Store(initialState: .init(hasPastGames: true)) {
      Multiplayer()
    }
  }
#endif
