import ComposableArchitecture
import Styleguide
import SwiftUI

@testable import HomeFeature

@main
struct HomeFeaturePreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        HomeView(
          store: Store(
            initialState: .init(),
            reducer: homeReducer,
            environment: HomeEnvironment(
              apiClient: .noop,
              applicationClient: .noop,
              audioPlayer: .noop,
              backgroundQueue: DispatchQueue.global(qos: .background).eraseToAnyScheduler(),
              build: .noop,
              database: .live(path: URL(string: ":memory:")!),
              deviceId: .noop,
              fileClient: .live,
              gameCenter: .noop,
              mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
              mainRunLoop: RunLoop.main.eraseToAnyScheduler(),
              remoteNotifications: .noop,
              serverConfig: .noop,
              setUserInterfaceStyle: { _ in .none },
              storeKit: .noop,
              timeZone: { TimeZone.current },
              userDefaults: .noop,
              userNotifications: .noop
            )
          )
        )
      }
    }
  }
}
