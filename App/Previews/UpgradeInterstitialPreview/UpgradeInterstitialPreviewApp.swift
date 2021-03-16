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
        store: .init(
          initialState: .init(),
          reducer: upgradeInterstitialReducer,
          environment: .init(
            mainRunLoop: RunLoop.main.eraseToAnyScheduler(),
            serverConfig: .noop,
            storeKit: .live()
          )
        )
      )
    }
  }
}
