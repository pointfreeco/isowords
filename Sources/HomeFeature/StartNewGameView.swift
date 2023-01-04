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
    WithViewStore(self.store.scope(state: \.destination?.tag)) { viewStore in
      VStack(alignment: .leading) {
        Text("Start a game")
          .adaptiveFont(.matterMedium, size: 16)
          .foregroundColor(self.colorScheme == .dark ? .hex(0xE79072) : .isowordsBlack)
          .padding([.bottom, .top])

        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: (\Home.State.destination).appending(path: /Home.Destinations.State.solo)
                .extract(from:),
              action: { .destination(.solo($0)) }
            ),
            then: SoloView.init(store:)
          ),
          tag: Home.Destinations.State.Tag.solo,
          selection: viewStore.binding(
            send: Home.Action.setNavigation(tag:)
          )
          .animation()
        ) {
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

        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: (\Home.State.destination).appending(path: /Home.Destinations.State.multiplayer)
                .extract(from:),
              action: { .destination(.multiplayer($0)) }
            ),
            then: MultiplayerView.init(store:)
          ),
          tag: Home.Destinations.State.Tag.multiplayer,
          selection:
            viewStore
            .binding(send: Home.Action.setNavigation(tag:))
            .animation()
        ) {
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
