import ComposableArchitecture
import MultiplayerFeature
import SoloFeature
import Styleguide
import SwiftUI

struct StartNewGameView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<HomeState, HomeAction>

  init(store: Store<HomeState, HomeAction>) {
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
              state: (\HomeState.route).appending(path: /HomeRoute.solo).extract(from:),
              action: HomeAction.solo
            ),
            then: SoloView.init(store:)
          ),
          tag: HomeRoute.Tag.solo,
          selection: viewStore.binding(
            send: HomeAction.setNavigation(tag:)
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

        NavigationLinkStore(
          destination: MultiplayerView.init(store:),
          tag: /HomeRoute.multiplayer,
          selection: self.store.scope(state: \.route, action: HomeAction.multiplayer)
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
