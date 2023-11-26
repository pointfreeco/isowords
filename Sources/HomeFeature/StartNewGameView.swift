import ComposableArchitecture
import MultiplayerFeature
import SoloFeature
import Styleguide
import SwiftUI

struct StartNewGameView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: StoreOf<Home>

  init(store: StoreOf<Home>) {
    self.store = store
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Start a game")
        .adaptiveFont(.matterMedium, size: 16)
        .foregroundColor(self.colorScheme == .dark ? .hex(0xE79072) : .isowordsBlack)
        .padding(.vertical)

      Button {
        self.store.send(.soloButtonTapped)
      } label: {
        HStack {
          Text("Solo")
          Spacer()
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(
        ActionButtonStyle(
          backgroundColor: self.colorScheme == .dark ? .hex(0xE5876D) : .isowordsBlack,
          foregroundColor: self.colorScheme == .dark ? .isowordsBlack : .hex(0xE5876D)
        )
      )

      Button {
        self.store.send(.multiplayerButtonTapped)
      } label: {
        HStack {
          Text("Multiplayer")
          Spacer()
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(
        ActionButtonStyle(
          backgroundColor: self.colorScheme == .dark ? .hex(0xE5876D) : .isowordsBlack,
          foregroundColor: self.colorScheme == .dark ? .isowordsBlack : .hex(0xE5876D)
        )
      )
    }
    .navigationDestination(
      store: self.store.scope(state: \.$destination.solo, action: \.destination.solo),
      destination: SoloView.init(store:)
    )
    .navigationDestination(
      store: self.store.scope(state: \.$destination.multiplayer, action: \.destination.multiplayer),
      destination: MultiplayerView.init(store:)
    )
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct StartNewGameView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        StartNewGameView(
          store: Store(initialState: .init()) {
          }
        )
      }
    }
  }
#endif
