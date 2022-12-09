import ApiClient
import AudioPlayerClient
import ComposableStoreKit
import ComposableUserNotifications
import RemoteNotificationsClient
import ServerConfigClient
import SettingsFeature
import Styleguide
import SwiftUI
import UserDefaultsClient
import PersistenceClient

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
            initialState: Settings.State(),
            reducer: Settings()
              .dependency(\.apiClient, .noop)
              .dependency(\.audioPlayer, .noop)
              .dependency(\.build, .noop)
              .dependency(\.database, .noop)
              .dependency(\.serverConfig, .live(fetch: { .init() }))
          ),
          navPresentationStyle: .modal
        )
      }
    }
  }
}
