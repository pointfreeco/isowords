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
              serverConfig: ServerConfigClient.live(fetch: { .init() }),
              setUserInterfaceStyle: { userInterfaceStyle in
                await MainActor.run {
                  guard
                    let scene = UIApplication.shared.connectedScenes.first(where: {
                      $0 is UIWindowScene
                    })
                      as? UIWindowScene
                  else { return }
                  scene.keyWindow?.overrideUserInterfaceStyle = userInterfaceStyle
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
