import ComposableArchitecture
import MultiplayerFeature
import SoloFeature
import Styleguide
import SwiftUI

struct StartNewGameView: View {
  @Environment(\.colorScheme) var colorScheme
  @Bindable var store: StoreOf<Home>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Start a game")
        .adaptiveFont(.matterMedium, size: 16)
        .foregroundColor(colorScheme == .dark ? .hex(0xE79072) : .isowordsBlack)
        .padding(.vertical)

      Button {
        store.send(.soloButtonTapped)
      } label: {
        HStack {
          Text("Solo")
          Spacer()
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(
        ActionButtonStyle(
          backgroundColor: colorScheme == .dark ? .hex(0xE5876D) : .isowordsBlack,
          foregroundColor: colorScheme == .dark ? .isowordsBlack : .hex(0xE5876D)
        )
      )

      Button {
        store.send(.multiplayerButtonTapped)
      } label: {
        HStack {
          Text("Multiplayer")
          Spacer()
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(
        ActionButtonStyle(
          backgroundColor: colorScheme == .dark ? .hex(0xE5876D) : .isowordsBlack,
          foregroundColor: colorScheme == .dark ? .isowordsBlack : .hex(0xE5876D)
        )
      )
    }
    .navigationDestination(
      item: $store.scope(\.destination).solo
    ) { store in
      SoloView(store: store)
    }
    .navigationDestination(
      item: $store.scope(\.destination).multiplayer
    ) { store in
      MultiplayerView(store: store)
    }
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct StartNewGameView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        StartNewGameView(
          store: Store(initialState: Home.State()) {
          }
        )
      }
    }
  }
#endif
