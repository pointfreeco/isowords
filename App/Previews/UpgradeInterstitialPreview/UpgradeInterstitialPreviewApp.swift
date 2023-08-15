import ComposableArchitecture
import Styleguide
import SwiftUI

@testable import UpgradeInterstitialFeature

@main
struct UpgradeInterstitialPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      UpgradeInterstitialView(
        store: Store(
          initialState: UpgradeInterstitial.State()
        ) {
          UpgradeInterstitial()
            .dependency(\.serverConfig, .noop)
        }
      )
    }
  }
}
