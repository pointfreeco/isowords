import ClientModels
import ComposableArchitecture
import Dependencies
import FileClient
import Overture
import SharedModels
import Styleguide
import SwiftUI

@Feature
public struct Solo {
  public struct State {
    @DebugSnapshotTracked var inProgressGame: InProgressGame?

    public init(inProgressGame: InProgressGame? = nil) {
      self.inProgressGame = inProgressGame
    }
  }

  public enum Action {
    case gameButtonTapped(GameMode)
  }

  public enum StartGame: FeatureEventKey {
    public typealias Value = GameMode
  }

  @Dependency(\.fileClient) var fileClient

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case let .gameButtonTapped(gameMode):
        store.addTask {
          try withAnimation {
            _ = try store.post(key: StartGame.self, value: gameMode)
          }
        }
      }
    }
    .onMount { _ in
      store.addTask {
        guard let savedGames = try? await fileClient.loadSavedGames()
        else { return }
        try store.modify { $0.inProgressGame = savedGames.unlimited }
      }
    }
  }
}

public struct SoloView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Solo>

  public init(store: StoreOf<Solo>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      Spacer()
        .frame(maxHeight: .grid(16))

      VStack(spacing: -8) {
        Text("Kill time")
        Text("and refine")
        Text("your skills")
      }
      .font(.custom(.matter, size: adaptiveSize.pad(48, by: 2)))
      .multilineTextAlignment(.center)

      Spacer()

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: .grid(4)),
          GridItem(.flexible()),
        ]
      ) {
        GameButton(
          title: Text("Timed"),
          icon: Image(systemName: "clock.fill"),
          color: .solo,
          inactiveText: nil,
          isLoading: false,
          resumeText: nil,
          action: { withAnimation { _ = store.send(.gameButtonTapped(.timed)) } }
        )

        GameButton(
          title: Text("Unlimited"),
          icon: Image(systemName: "infinity"),
          color: .solo,
          inactiveText: nil,
          isLoading: false,
          resumeText: (store.inProgressGame?.currentScore).flatMap {
            $0 > 0 ? Text("\($0) points") : nil
          },
          action: { withAnimation { _ = store.send(.gameButtonTapped(.unlimited)) } }
        )
      }
    }
    .adaptivePadding(.vertical)
    .screenEdgePadding(.horizontal)
    .navigationStyle(
      backgroundColor: colorScheme == .dark ? .isowordsBlack : .solo,
      foregroundColor: colorScheme == .dark ? .solo : .isowordsBlack,
      title: Text("Solo")
    )
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct SoloView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          SoloView(store: .solo)
        }
      }
    }
  }

  extension Store where State == Solo.State, Action == Solo.Action {
    static let solo = Store(
      initialState: Solo.State(
        inProgressGame: .some(
          update(.mock) {
            $0.moves = [
              .init(
                playedAt: Date(),
                playerIndex: nil,
                reactions: nil,
                score: 1_000,
                type: .playedWord([
                  .init(
                    index: .init(x: .two, y: .two, z: .two),
                    side: .left
                  ),
                  .init(
                    index: .init(x: .two, y: .two, z: .two),
                    side: .right
                  ),
                  .init(
                    index: .init(x: .two, y: .two, z: .two),
                    side: .top
                  ),
                ])
              )
            ]
          })
      )
    ) {
      Solo()
    }
  }
#endif
