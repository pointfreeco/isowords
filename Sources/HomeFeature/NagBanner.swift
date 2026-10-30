import ComposableArchitecture
import Dependencies
import SwiftUI
import UpgradeInterstitialFeature

@Feature
public struct NagBanner {
  public struct State {
    @DebugSnapshotTracked var upgradeInterstitial: UpgradeInterstitial.State? = nil

    public init(upgradeInterstitial: UpgradeInterstitial.State? = nil) {
      self.upgradeInterstitial = upgradeInterstitial
    }
  }

  public enum Action {
    case tapped
    case upgradeInterstitial(UpgradeInterstitial.Action)
  }

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .tapped:
        state.upgradeInterstitial = .init(isDismissable: true)

      case .upgradeInterstitial:
        break
      }
    }
    .ifLet(\.upgradeInterstitial) {
      UpgradeInterstitial()
    }
    .onEvent(UpgradeInterstitial.FullGamePurchased.self) { _, _ in
      store.addTask {
        try store.dismiss()
      }
    }
  }
}

public struct NagBannerView: View {
  @Bindable var store: StoreOf<NagBanner>

  public init(store: StoreOf<NagBanner>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.tapped)
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
    .sheet(
      item: $store.scope(\.upgradeInterstitial)
    ) { store in
      UpgradeInterstitialView(store: store)
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
            store: Store(initialState: NagBanner.State()) {
              NagBanner()
            }
          )
        }
      }
    }
  }
#endif
