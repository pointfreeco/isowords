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
    WithViewStore(self.store.stateless) { viewStore in
      VStack(alignment: .leading) {
        Text("Start a game")
          .adaptiveFont(.matterMedium, size: 16)
          .foregroundColor(self.colorScheme == .dark ? .hex(0xE79072) : .isowordsBlack)
          .padding(.vertical)

        Button {
          viewStore.send(.destination(.present(id: Home.Destinations.ID.solo)))
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
          viewStore.send(.destination(.present(id: Home.Destinations.ID.multiplayer)))
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
    }
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.solo,
      action: Home.Destinations.Action.solo,
      destination: SoloView.init(store:)
    )
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Home.Action.destination),
      state: /Home.Destinations.State.multiplayer,
      action: Home.Destinations.Action.multiplayer,
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
          store: .init(
            initialState: .init(),
            reducer: .empty,
            environment: ()
          )
        )
      }
    }
  }
#endif
