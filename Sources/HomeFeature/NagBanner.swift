import Combine
import ComposableArchitecture
import ComposableStoreKit
import ServerConfigClient
import SwiftUI
import TcaHelpers
import UpgradeInterstitialFeature

public struct NagBannerState: Equatable {
  var upgradeInterstitial: UpgradeInterstitialState? = nil
}

public enum NagBannerAction: Equatable {
  case tapped
  case upgradeInterstitial(UpgradeInterstitialAction)
}

public enum NagBannerFeatureAction: Equatable {
  case dismissUpgradeInterstitial
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
      case .dismissUpgradeInterstitial:
        state?.upgradeInterstitial = nil
        return .none

      case .nagBanner(.upgradeInterstitial(.delegate(.fullGamePurchased))):
        state = nil
        return .none

      case .nagBanner:
        return .none
      }
    }
  )

private let nagBannerReducer = Reducer<NagBannerState, NagBannerAction, NagBannerEnvironment>
  .combine(
    upgradeInterstitialReducer
      ._pullback(
        state: OptionalPath(\.upgradeInterstitial),
        action: /NagBannerAction.upgradeInterstitial,
        environment: {
          UpgradeInterstitialEnvironment(
            mainRunLoop: $0.mainRunLoop,
            serverConfig: $0.serverConfig,
            storeKit: $0.storeKit
          )
        }
      ),

    .init { state, action, environment in
      switch action {
      case .tapped:
        state.upgradeInterstitial = .init(isDismissable: true)
        return .none

      case .upgradeInterstitial(.delegate(.close)):
        state.upgradeInterstitial = nil
        return .none

      case .upgradeInterstitial(.delegate(.fullGamePurchased)):
        state.upgradeInterstitial = nil
        return .none

      case .upgradeInterstitial:
        return .none
      }
    }
  )

struct NagBannerFeature: View {
  let store: Store<NagBannerState?, NagBannerFeatureAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
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
            isPresented: viewStore.binding(
              get: { $0?.upgradeInterstitial != nil },
              send: NagBannerFeatureAction.dismissUpgradeInterstitial
            )
          ) {
            IfLetStore(
              self.store.scope(
                state: { $0?.upgradeInterstitial },
                action: { .nagBanner(.upgradeInterstitial($0)) }
              ),
              then: UpgradeInterstitialView.init(store:)
            )
          }
      )
    }
  }
}

private struct NagBanner: View {
  let store: Store<NagBannerState, NagBannerAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Button(action: { viewStore.send(.tapped) }) {
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
