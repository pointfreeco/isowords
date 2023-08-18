import ComposableArchitecture
import SwiftUI

struct GameNavView: View {
  let store: StoreOf<Game>
  @ObservedObject var viewStore: ViewStore<ViewState, Game.Action>

  struct ViewState: Equatable {
    let isTrayAvailable: Bool
    let isTrayVisible: Bool
    let trayTitle: String

    init(state: Game.State) {
      self.isTrayAvailable = state.isTrayAvailable
      self.isTrayVisible = state.isTrayVisible
      self.trayTitle = state.displayTitle
    }
  }

  public init(
    store: StoreOf<Game>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: ViewState.init)
  }

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Button(action: { self.viewStore.send(.trayButtonTapped, animation: .default) }) {
        HStack {
          Text(self.viewStore.trayTitle)
            .lineLimit(1)

          Spacer()

          Image(systemName: "chevron.down")
            .rotationEffect(.degrees(self.viewStore.isTrayVisible ? 180 : 0))
            .opacity(self.viewStore.isTrayAvailable ? 1 : 0)
        }
        .adaptiveFont(.matterMedium, size: 14)
        .foregroundColor(.adaptiveBlack)
        .adaptivePadding()
      }
      .background(
        Color.adaptiveBlack
          .opacity(0.05)
      )
      .cornerRadius(12)
      .disabled(!self.viewStore.isTrayAvailable)

      Button(action: { self.viewStore.send(.menuButtonTapped, animation: .default) }) {
        Image(systemName: "ellipsis")
          .foregroundColor(.adaptiveBlack)
          .adaptivePadding()
          .rotationEffect(.degrees(90))
      }
      .frame(maxHeight: .infinity)
      .background(
        Color.adaptiveBlack
          .opacity(0.05)
      )
      .cornerRadius(12)
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal)
    .adaptivePadding(.vertical, 8)
  }
}

#if DEBUG
  import Overture

  struct GameNavView_Previews: PreviewProvider {
    static var previews: some View {
      VStack {
        GameNavView(
          store: Store(
            initialState: .init(inProgressGame: .mock)
          ) {
          }
        )
        Spacer()
      }
    }
  }
#endif
