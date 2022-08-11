import ComposableArchitecture
import SwiftUI
import UpgradeInterstitialFeature

public struct NagBanner: ReducerProtocol {
  public struct State: Equatable {
    @PresentationStateOf<UpgradeInterstitial> var upgradeInterstitial
  }

  public enum Action: Equatable {
    case upgradeInterstitial(PresentationActionOf<UpgradeInterstitial>)
  }

  public var body: some ReducerProtocol<State, Action> {
    EmptyReducer()
      .presentationDestination(state: \.$upgradeInterstitial, action: /Action.upgradeInterstitial) {
        UpgradeInterstitial()
      }
  }
}

struct NagBannerView: View {
  let store: StoreOf<NagBanner>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Button {
        viewStore.send(
          .upgradeInterstitial(.present(UpgradeInterstitial.State(isDismissable: true)))
        )
      } label: {
        Marquee(duration: TimeInterval(messages.count) * 9) {
          ForEach(messages, id: \.self) { message in
            Text(message)
              .adaptiveFont(.matterMedium, size: 14)
              .foregroundColor(.isowordsRed)
          }
        }
      }
      .buttonStyle(PlainButtonStyle())
      .frame(maxWidth: .infinity, alignment: .center)
      .frame(height: 56)
      .background(Color.white.edgesIgnoringSafeArea(.bottom))
    }
    .sheet(
      store: self.store.scope(
        state: \.$upgradeInterstitial,
        action: NagBanner.Action.upgradeInterstitial
      ),
      content: UpgradeInterstitialView.init(store:)
    )
  }
}

let messages = [
  "Remove this annoying banner.",
  "Please, we don’t like it either.",
  "We could put an ad here, but ads suck.",
  "Seriously, we are sorry about this.",
]

#if DEBUG
  struct NagBanner_Previews: PreviewProvider {
    static var previews: some View {
      NavigationStack {
        ZStack(alignment: .bottomLeading) {
          NagBannerView(
            store: Store(
              initialState: NagBanner.State(),
              reducer: NagBanner()
            )
          )
        }
      }
    }
  }
#endif
