import ComposableArchitecture
import SwiftUI
import UpgradeInterstitialFeature

public struct NagBannerFeature: Reducer {
  public typealias State = NagBanner.State?

  public enum Action: Equatable {
    case dismissUpgradeInterstitial
    case nagBanner(NagBanner.Action)
  }

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
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
    .ifLet(\.self, action: /Action.nagBanner) {
      NagBanner()
    }
  }
}

public struct NagBanner: Reducer {
  public struct State: Equatable {
    var upgradeInterstitial: UpgradeInterstitial.State? = nil
  }

  public enum Action: Equatable {
    case tapped
    case upgradeInterstitial(UpgradeInterstitial.Action)
  }

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
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
    .ifLet(\.upgradeInterstitial, action: /Action.upgradeInterstitial) {
      UpgradeInterstitial()
    }
  }
}

struct NagBannerFeatureView: View {
  let store: StoreOf<NagBannerFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      IfLetStore(
        self.store.scope(state: { $0 }, action: NagBannerFeature.Action.nagBanner),
        then: NagBannerView.init(store:)
      )
      .background(
        // NB: If an .alert/.sheet modifier is used on a child view while the parent view is also
        // using an .alert/.sheet modifier, then the child view’s alert/sheet will never appear:
        // https://gist.github.com/mbrandonw/82ece7c62afb370a875fd1db2f9a236e
        EmptyView()
          .sheet(
            isPresented: viewStore.binding(
              get: { $0?.upgradeInterstitial != nil },
              send: NagBannerFeature.Action.dismissUpgradeInterstitial
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

private struct NagBannerView: View {
  let store: StoreOf<NagBanner>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
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
          NagBannerView(
            store: Store(
              initialState: NagBanner.State()
            ) {
              NagBanner()
            }
          )
        }
      }
    }
  }
#endif
