import ClientModels
import ComposableArchitecture
import FileClient
import Overture
import SharedModels
import Styleguide
import SwiftUI

public struct Solo: ReducerProtocol {
  public struct State: Equatable {
    var inProgressGame: InProgressGame?

    public init(inProgressGame: InProgressGame? = nil) {
      self.inProgressGame = inProgressGame
    }
  }

  public enum Action: Equatable {
    case gameButtonTapped(GameMode)
    case savedGamesLoaded(TaskResult<SavedGamesState>)
    case task
  }

  @Dependency(\.fileClient) var fileClient

  public init() {}

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .gameButtonTapped:
      return .none

    case .savedGamesLoaded(.failure):
      return .none

    case let .savedGamesLoaded(.success(savedGameState)):
      state.inProgressGame = savedGameState.unlimited
      return .none

    case .task:
      return .task {
        await .savedGamesLoaded(TaskResult { try await self.fileClient.loadSavedGames() })
      }
    }
  }
}

public struct SoloView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Solo>

  struct ViewState: Equatable {
    let currentScore: Int?

    init(state: Solo.State) {
      self.currentScore = state.inProgressGame?.currentScore
    }
  }

  public init(store: StoreOf<Solo>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init, action: { $0 })) { viewStore in
      VStack {
        Spacer()
          .frame(maxHeight: .grid(16))

        VStack(spacing: -8) {
          Text("Kill time")
          Text("and refine")
          Text("your skills")
        }
        .font(.custom(.matter, size: self.adaptiveSize.pad(48, by: 2)))
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
            action: { viewStore.send(.gameButtonTapped(.timed), animation: .default) }
          )

          GameButton(
            title: Text("Unlimited"),
            icon: Image(systemName: "infinity"),
            color: .solo,
            inactiveText: nil,
            isLoading: false,
            resumeText: (viewStore.currentScore).flatMap {
              $0 > 0 ? Text("\($0) points") : nil
            },
            action: { viewStore.send(.gameButtonTapped(.unlimited), animation: .default) }
          )
        }
      }
      .adaptivePadding([.vertical])
      .screenEdgePadding(.horizontal)
      .task { await viewStore.send(.task).finish() }
    }
    .navigationStyle(
      backgroundColor: self.colorScheme == .dark ? .isowordsBlack : .solo,
      foregroundColor: self.colorScheme == .dark ? .solo : .isowordsBlack,
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
      initialState: .init(
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
      ),
      reducer: Solo()
    )
  }
#endif
