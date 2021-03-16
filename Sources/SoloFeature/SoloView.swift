import ClientModels
import ComposableArchitecture
import FileClient
import Overture
import SharedModels
import Styleguide
import SwiftUI

public struct SoloState: Equatable {
  var inProgressGame: InProgressGame?

  public init(
    inProgressGame: InProgressGame? = nil
  ) {
    self.inProgressGame = inProgressGame
  }
}

public enum SoloAction: Equatable {
  case gameButtonTapped(GameMode)
  case onAppear
  case savedGamesLoaded(Result<SavedGamesState, NSError>)
}

public struct SoloEnvironment {
  var fileClient: FileClient

  public init(
    fileClient: FileClient
  ) {
    self.fileClient = fileClient
  }
}

public let soloReducer = Reducer<SoloState, SoloAction, SoloEnvironment> {
  state, action, environment in
  switch action {
  case .gameButtonTapped:
    return .none

  case .onAppear:
    return environment.fileClient.loadSavedGames()
      .map(SoloAction.savedGamesLoaded)

  case .savedGamesLoaded(.failure):
    return .none

  case let .savedGamesLoaded(.success(savedGameState)):
    state.inProgressGame = savedGameState.unlimited
    return .none
  }
}

public struct SoloView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  let store: Store<SoloState, SoloAction>

  struct ViewState: Equatable {
    let currentScore: Int?

    init(state: SoloState) {
      self.currentScore = state.inProgressGame?.currentScore
    }
  }

  public init(store: Store<SoloState, SoloAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
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
            resumeText: nil,
            action: { viewStore.send(.gameButtonTapped(.timed), animation: .default) }
          )

          GameButton(
            title: Text("Unlimited"),
            icon: Image(systemName: "infinity"),
            color: .solo,
            inactiveText: nil,
            resumeText: (viewStore.currentScore).flatMap {
              $0 > 0 ? Text("\($0) points") : nil
            },
            action: { viewStore.send(.gameButtonTapped(.unlimited), animation: .default) }
          )
        }
      }
      .adaptivePadding([.vertical])
      .screenEdgePadding(.horizontal)
      .onAppear { viewStore.send(.onAppear) }
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

  extension Store where State == SoloState, Action == SoloAction {
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
      reducer: soloReducer,
      environment: .init(
        fileClient: .noop
      )
    )
  }
#endif
