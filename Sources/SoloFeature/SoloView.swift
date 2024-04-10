import ClientModels
import ComposableArchitecture
import Overture
import SharedModels
import Styleguide
import SwiftUI

@Reducer
public struct Solo {
  @ObservableState
  public struct State: Equatable {
    var inProgressGame: InProgressGame?

    public init(inProgressGame: InProgressGame? = nil) {
      self.inProgressGame = inProgressGame
    }
  }

  public enum Action {
    case gameButtonTapped(GameMode)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .gameButtonTapped:
        return .none
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
          action: { store.send(.gameButtonTapped(.timed), animation: .default) }
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
          action: { store.send(.gameButtonTapped(.unlimited), animation: .default) }
        )
      }
    }
    .adaptivePadding(.vertical)
    .screenEdgePadding(.horizontal)
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
