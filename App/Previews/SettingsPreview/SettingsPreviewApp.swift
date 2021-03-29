import ApiClient
import AudioPlayerClient
import ComposableStoreKit
import ComposableUserNotifications
import FileClient
import RemoteNotificationsClient
import ServerConfigClient
import SettingsFeature
import Styleguide
import SwiftUI
import UserDefaultsClient

@main
struct SettingsPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        SettingsView(
          store: .init(
            initialState: .init(),
            reducer: settingsReducer,
            environment: .init(
              apiClient: .noop,
              applicationClient: .live,
              audioPlayer: .live(bundles: []),
              backgroundQueue: DispatchQueue(label: "background-queue").eraseToAnyScheduler(),
              build: .noop,
              database: .noop,
              feedbackGenerator: .live,
              fileClient: .live,
              lowPowerMode: .live,
              mainQueue: .main,
              remoteNotifications: .live,
              serverConfig: ServerConfigClient.live(fetch: { .init(value: .init()) }),
              setUserInterfaceStyle: { userInterfaceStyle in
                .fireAndForget {
                  UIApplication.shared.windows.first?.overrideUserInterfaceStyle =
                    userInterfaceStyle
                }
              },
              storeKit: .live(),
              userDefaults: .live(),
              userNotifications: .live
            )
          ),
          navPresentationStyle: .modal
        )
      }
    }
  }
}
