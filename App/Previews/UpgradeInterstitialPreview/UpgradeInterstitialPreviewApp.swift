import ComposableArchitecture
import Dependencies
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
        store: Store(initialState: UpgradeInterstitial.State()) {
          UpgradeInterstitial()
            .transformDependency(\.self) {
              $0.serverConfig = .noop
            }
        }
      )
    }
  }
}
