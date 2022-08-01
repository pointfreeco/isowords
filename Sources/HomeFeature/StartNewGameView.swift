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
    WithViewStore(self.store.scope(state: \.route?.tag)) { viewStore in
      VStack(alignment: .leading) {
        Text("Start a game")
          .adaptiveFont(.matterMedium, size: 16)
          .foregroundColor(self.colorScheme == .dark ? .hex(0xE79072) : .isowordsBlack)
          .padding([.bottom, .top])

        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: (\Home.State.route).appending(path: /Home.Route.solo).extract(from:),
              action: Home.Action.solo
            ),
            then: SoloView.init(store:)
          ),
          tag: Home.Route.Tag.solo,
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
              state: (\Home.State.route).appending(path: /Home.Route.multiplayer).extract(from:),
              action: Home.Action.multiplayer
            ),
            then: MultiplayerView.init(store:)
          ),
          tag: Home.Route.Tag.multiplayer,
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
