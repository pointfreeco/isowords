import ApiClient
import AudioPlayerClient
import ComposableStoreKit
import ComposableUserNotifications
import RemoteNotificationsClient
import ServerConfigPersistenceKey
import SettingsFeature
import Styleguide
import SwiftUI

@main
struct SettingsPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        SettingsView(
          store: .init(initialState: Settings.State()) {
            Settings()
          } withDependencies: {
            $0.apiClient = .noop
            $0.audioPlayer = .noop
            $0.build = .noop
            $0.database = .noop
            $0.serverConfig = .live(fetch: { .init() })
          },
          navPresentationStyle: .modal
        )
      }
    }
  }
}
