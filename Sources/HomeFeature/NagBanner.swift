import Combine
import ComposableArchitecture
import ComposableStoreKit
import ServerConfigClient
import SwiftUI
import UpgradeInterstitialFeature

public struct NagBannerState: Equatable {
  var upgradeInterstitial: UpgradeInterstitialState? = nil
}

public enum NagBannerAction: Equatable {
  case upgradeInterstitial(PresentationAction<UpgradeInterstitialAction>)
}

public enum NagBannerFeatureAction: Equatable {
  case nagBanner(NagBannerAction)
}

public struct NagBannerEnvironment {
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var serverConfig: ServerConfigClient
  var storeKit: StoreKitClient
}

let nagBannerFeatureReducer = Reducer<NagBannerState?, NagBannerFeatureAction, NagBannerEnvironment>
  .combine(
    nagBannerReducer
      ._pullback(
        state: OptionalPath(\.self),
        action: /NagBannerFeatureAction.nagBanner,
        environment: { $0 }
      ),

    .init { state, action, environment in
      struct TimerId: Hashable {}

      switch action {
      case .nagBanner(.upgradeInterstitial(.isPresented(.delegate(.fullGamePurchased)))):
        state = nil
        return .none

      case .nagBanner:
        return .none
      }
    }
  )

private let nagBannerReducer = Reducer<NagBannerState, NagBannerAction, NagBannerEnvironment>
{ state, action, environment in
  switch action {
  case .upgradeInterstitial(.present):
    state.upgradeInterstitial = .init(isDismissable: true)
    return .none

  case .upgradeInterstitial(.isPresented(.delegate(.close))):
    state.upgradeInterstitial = nil
    return .none

  case .upgradeInterstitial(.isPresented(.delegate(.fullGamePurchased))):
    state.upgradeInterstitial = nil
    return .none

  case .upgradeInterstitial:
    return .none
  }
}
.presents(
  upgradeInterstitialReducer,
  state: \.upgradeInterstitial,
  action: /NagBannerAction.upgradeInterstitial,
  environment: {
    UpgradeInterstitialEnvironment(
      mainRunLoop: $0.mainRunLoop,
      serverConfig: $0.serverConfig,
      storeKit: $0.storeKit
    )
  }
)

struct NagBannerFeature: View {
  let store: Store<NagBannerState?, NagBannerFeatureAction>

  var body: some View {
    IfLetStore(
      self.store.scope(state: { $0 }, action: NagBannerFeatureAction.nagBanner),
      then: NagBanner.init(store:)
    )
    .background(
      // NB: If an .alert/.sheet modifier is used on a child view while the parent view is also
      // using an .alert/.sheet modifier, then the child view’s alert/sheet will never appear:
      // https://gist.github.com/mbrandonw/82ece7c62afb370a875fd1db2f9a236e
      EmptyView()
        .sheet(
          ifLet: self.store.scope(
            state: \.?.upgradeInterstitial, action: { .nagBanner(.upgradeInterstitial($0)) }
          ),
          then: UpgradeInterstitialView.init(store:)
        )
    )
  }
}

private struct NagBanner: View {
  let store: Store<NagBannerState, NagBannerAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Button(action: { viewStore.send(.upgradeInterstitial(.present)) }) {
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
      NavigationView {
        ZStack(alignment: .bottomLeading) {
          NagBanner(
            store: .init(
              initialState: NagBannerState(),
              reducer: nagBannerReducer,
              environment: NagBannerEnvironment(
                mainRunLoop: .main,
                serverConfig: .noop,
                storeKit: .noop
              )
            )
          )
        }
      }
    }
  }
#endif
